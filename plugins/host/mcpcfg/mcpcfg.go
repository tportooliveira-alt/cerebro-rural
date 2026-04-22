// Package mcpcfg carrega a lista de servidores MCP a partir de JSON, expandindo
// variáveis ${VAR} com os.Getenv. Servidores cujo env expandido fica vazio
// podem ser pulados pelo chamador.
package mcpcfg

import (
	"encoding/json"
	"os"
	"regexp"

	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/adapter"
)

type File struct {
	Servers []adapter.MCPServerSpec `json:"servers"`
}

var reVar = regexp.MustCompile(`\$\{([A-Z0-9_]+)\}`)

func expand(s string) string {
	return reVar.ReplaceAllStringFunc(s, func(m string) string {
		name := m[2 : len(m)-1]
		return os.Getenv(name)
	})
}

// Load lê o arquivo e expande ${VAR} em command/args/env.
func Load(path string) (*File, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var f File
	if err := json.Unmarshal(raw, &f); err != nil {
		return nil, err
	}
	for i := range f.Servers {
		s := &f.Servers[i]
		s.Command = expand(s.Command)
		for j, a := range s.Args {
			s.Args[j] = expand(a)
		}
		if s.Env != nil {
			for k, v := range s.Env {
				s.Env[k] = expand(v)
			}
		}
	}
	return &f, nil
}
