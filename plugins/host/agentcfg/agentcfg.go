// Package agentcfg — carrega providers+agentes+orquestrador de JSON, expande
// ${VAR} e monta instâncias prontas para uso.
package agentcfg

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"regexp"

	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/adapter"
	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/agent"
	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/llm"
)

type File struct {
	Providers    []llm.ProviderSpec `json:"providers"`
	Agents       []agent.Spec       `json:"agents"`
	Orchestrator struct {
		Module string   `json:"module"`
		Agents []string `json:"agents"`
	} `json:"orchestrator"`
}

var reVar = regexp.MustCompile(`\$\{([A-Z0-9_]+)\}`)

func expand(s string) string {
	return reVar.ReplaceAllStringFunc(s, func(m string) string {
		return os.Getenv(m[2 : len(m)-1])
	})
}

func Load(path string) (*File, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var f File
	if err := json.Unmarshal(raw, &f); err != nil {
		return nil, err
	}
	for i := range f.Providers {
		p := &f.Providers[i]
		p.BaseURL = expand(p.BaseURL)
		p.APIKey = expand(p.APIKey)
		p.Model = expand(p.Model)
		for k, v := range p.Headers {
			p.Headers[k] = expand(v)
		}
	}
	return &f, nil
}

// Build instancia providers, agentes e orquestrador. `mcps` são as Extensions
// MCP já conectadas (resultado de StartMCP para cada servidor do agents.json
// que seja referenciado como tool). Falhas em providers sem key são ignoradas
// silenciosamente: o agente correspondente simplesmente não é criado.
func (f *File) Build(ctx context.Context, mcps []adapter.Extension) (map[string]*agent.Agent, *agent.Orchestrator, error) {
	clients := map[string]*llm.Client{}
	for _, p := range f.Providers {
		if p.BaseURL == "" || p.Model == "" {
			continue
		}
		clients[p.Name] = llm.New(p)
	}

	agents := map[string]*agent.Agent{}
	for _, s := range f.Agents {
		c, ok := clients[s.Provider]
		if !ok {
			continue // provider não configurado (env ausente)
		}
		a, err := agent.New(s, c, mcps)
		if err != nil {
			return nil, nil, fmt.Errorf("agent %s: %w", s.Name, err)
		}
		agents[s.Name] = a
	}

	var orq *agent.Orchestrator
	if f.Orchestrator.Module != "" {
		orq = agent.NewOrchestrator(f.Orchestrator.Module)
		for _, name := range f.Orchestrator.Agents {
			if a, ok := agents[name]; ok {
				orq.Register(a)
			}
		}
	}
	return agents, orq, nil
}
