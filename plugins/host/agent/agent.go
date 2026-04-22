// Package agent — agentes de IA expostos como Extension. Cada agente tem:
//   - um provider LLM (OpenAI-compatible)
//   - um toolset (Extensions — tipicamente MCPs) que ele pode chamar
//   - um system prompt e um módulo+action únicos
//
// O Execute roda um loop de tool-calling: pede ao LLM, executa tools MCP,
// devolve resultados ao LLM, até FinishReason="stop" ou limite.
package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/adapter"
	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/llm"
	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

// Spec — configuração declarativa de um agente.
type Spec struct {
	Name         string   `json:"name"`
	Module       string   `json:"module"`       // ex: "agent"
	Action       string   `json:"action"`       // ex: "run" | "plan" | "diagnose"
	Provider     string   `json:"provider"`     // nome do provider LLM
	Model        string   `json:"model,omitempty"`
	SystemPrompt string   `json:"system_prompt"`
	Tools        []string `json:"tools"`        // módulos MCP permitidos (ex: "fs","git","think")
	MaxIters     int      `json:"max_iters,omitempty"`
	Temperature  *float64 `json:"temperature,omitempty"`
}

// Agent implementa adapter.Extension.
type Agent struct {
	spec    Spec
	client  *llm.Client
	mcps    []adapter.Extension // MCPs disponíveis (filtrados por spec.Tools)
	toolMap map[string]toolRef  // tool_name -> (ext, originalName)
	tools   []llm.Tool          // declarações para o LLM
}

type toolRef struct {
	ext    adapter.Extension
	module string
	action string
}

// New monta um agente a partir da spec, do client LLM e da lista de MCPs
// disponíveis. Apenas MCPs cujo módulo esteja em spec.Tools são conectados.
func New(spec Spec, client *llm.Client, allMCPs []adapter.Extension) (*Agent, error) {
	if spec.MaxIters <= 0 {
		spec.MaxIters = 8
	}
	allowed := map[string]struct{}{}
	for _, m := range spec.Tools {
		allowed[m] = struct{}{}
	}
	a := &Agent{spec: spec, client: client, toolMap: map[string]toolRef{}}
	for _, m := range allMCPs {
		caps, err := m.Capabilities(context.Background())
		if err != nil {
			continue
		}
		for _, c := range caps.Capabilities {
			if _, ok := allowed[c.Module]; !ok && len(allowed) > 0 {
				continue
			}
			// nome sanitizado para o LLM: <module>__<action>
			toolName := sanitize(c.Module + "__" + c.Action)
			a.toolMap[toolName] = toolRef{ext: m, module: c.Module, action: c.Action}
			params := json.RawMessage(c.SchemaPayload)
			if len(params) == 0 || string(params) == "null" {
				params = json.RawMessage(`{"type":"object"}`)
			}
			a.tools = append(a.tools, llm.Tool{
				Type: "function",
				Function: llm.FunctionDecl{
					Name:        toolName,
					Description: fmt.Sprintf("MCP %s.%s", c.Module, c.Action),
					Parameters:  params,
				},
			})
			a.mcps = append(a.mcps, m)
		}
	}
	return a, nil
}

func sanitize(s string) string {
	r := strings.NewReplacer("-", "_", "/", "_", ".", "_", " ", "_")
	return r.Replace(s)
}

// ---------- Extension impl ----------

func (a *Agent) ID() string   { return "agent/" + a.spec.Name }
func (a *Agent) Close() error { return nil }

func (a *Agent) Health(ctx context.Context) (*extv1.HealthResponse, error) {
	return &extv1.HealthResponse{Ok: true, Message: "agent:" + a.spec.Name}, nil
}
func (a *Agent) Version(ctx context.Context) (*extv1.VersionResponse, error) {
	return &extv1.VersionResponse{
		PluginId: a.ID(), PluginVersion: "1.0",
		ProtocolMajor: 1, ProtocolMinor: 0,
	}, nil
}
func (a *Agent) Capabilities(ctx context.Context) (*extv1.CapabilitiesResponse, error) {
	schema := `{"type":"object","required":["task"],"properties":{"task":{"type":"string"}}}`
	return &extv1.CapabilitiesResponse{Capabilities: []*extv1.Capability{{
		Module: a.spec.Module, Action: a.spec.Action, SchemaPayload: schema,
	}}}, nil
}
func (a *Agent) Validate(ctx context.Context, cmd *extv1.Command) (*extv1.ValidateResponse, error) {
	if cmd.Module != a.spec.Module || cmd.Action != a.spec.Action {
		return &extv1.ValidateResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "AGENT_ROUTE",
			Message: "rota não corresponde ao agente",
		}}}, nil
	}
	return &extv1.ValidateResponse{Ok: true}, nil
}

func (a *Agent) Execute(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	var in struct {
		Task string `json:"task"`
	}
	if cmd.PayloadJson != "" {
		_ = json.Unmarshal([]byte(cmd.PayloadJson), &in)
	}
	if in.Task == "" {
		return &extv1.ExecuteResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "NO_TASK", Message: "campo task vazio",
		}}}, nil
	}

	msgs := []llm.Message{
		{Role: "system", Content: a.spec.SystemPrompt},
		{Role: "user", Content: in.Task},
	}

	transcript := []map[string]any{}

	for step := 0; step < a.spec.MaxIters; step++ {
		resp, err := a.client.Chat(ctx, llm.ChatRequest{
			Model: a.spec.Model, Messages: msgs, Tools: a.tools,
			Temperature: a.spec.Temperature,
		})
		if err != nil {
			return &extv1.ExecuteResponse{Ok: false, Issues: []*extv1.Issue{{
				Severity: extv1.Issue_ERROR, Code: "LLM_ERROR", Message: err.Error(),
			}}}, nil
		}
		choice := resp.Choices[0]
		msg := choice.Message
		msgs = append(msgs, msg)

		if len(msg.ToolCalls) == 0 {
			out := map[string]any{
				"agent":      a.spec.Name,
				"model":      a.spec.Model,
				"iterations": step + 1,
				"answer":     msg.Content,
				"transcript": transcript,
			}
			b, _ := json.Marshal(out)
			return &extv1.ExecuteResponse{Ok: true, ResultJson: string(b)}, nil
		}

		for _, tc := range msg.ToolCalls {
			ref, ok := a.toolMap[tc.Function.Name]
			if !ok {
				msgs = append(msgs, llm.Message{
					Role: "tool", ToolCallID: tc.ID, Name: tc.Function.Name,
					Content: fmt.Sprintf(`{"error":"tool desconhecida: %s"}`, tc.Function.Name),
				})
				continue
			}
			payload := tc.Function.Arguments
			if payload == "" {
				payload = "{}"
			}
			sub := &extv1.Command{
				RequestId: cmd.RequestId + "/" + tc.ID, TenantId: cmd.TenantId,
				Module: ref.module, Action: ref.action, PayloadJson: payload,
				Meta: map[string]string{"agent": a.spec.Name, "parent": cmd.RequestId},
			}
			execRes, err := ref.ext.Execute(ctx, sub)
			var content string
			if err != nil {
				content = fmt.Sprintf(`{"error":%q}`, err.Error())
			} else if execRes.Ok {
				content = execRes.ResultJson
				if content == "" {
					content = "{}"
				}
			} else {
				b, _ := json.Marshal(execRes.Issues)
				content = fmt.Sprintf(`{"ok":false,"issues":%s}`, string(b))
			}
			transcript = append(transcript, map[string]any{
				"step": step, "tool": tc.Function.Name,
				"args": json.RawMessage(payload), "result": json.RawMessage(content),
			})
			msgs = append(msgs, llm.Message{
				Role: "tool", ToolCallID: tc.ID, Name: tc.Function.Name, Content: content,
			})
		}
	}
	out := map[string]any{
		"agent": a.spec.Name, "answer": "(limite de iterações)",
		"transcript": transcript,
	}
	b, _ := json.Marshal(out)
	return &extv1.ExecuteResponse{Ok: true, ResultJson: string(b)}, nil
}
