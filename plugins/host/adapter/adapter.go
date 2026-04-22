// Package adapter define a interface única que o host enxerga. Toda fonte de
// extensão (binário local, script sandboxado, serviço remoto) precisa ser
// traduzida para essa interface por um Adapter.
package adapter

import (
	"context"

	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

// Extension é a visão unificada que o registry e o integrity pipeline consomem.
type Extension interface {
	ID() string
	Close() error

	Health(ctx context.Context) (*extv1.HealthResponse, error)
	Version(ctx context.Context) (*extv1.VersionResponse, error)
	Capabilities(ctx context.Context) (*extv1.CapabilitiesResponse, error)
	Validate(ctx context.Context, cmd *extv1.Command) (*extv1.ValidateResponse, error)
	Execute(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error)
}

// Adapter cria uma Extension a partir de algum Source (binário, script, remoto).
type Adapter interface {
	Kind() string
	Load(ctx context.Context, source Source) (Extension, error)
}

// Source descreve de onde vem a extensão. Campos são interpretados por Adapter.
type Source struct {
	ID       string            // identidade lógica (ex: "caixa.ofx-import")
	Kind     string            // "binary" | "script" | "remote"
	Location string            // caminho, URL, etc.
	Checksum string            // sha256 obrigatório em produção
	Config   map[string]string // parâmetros específicos do adapter
}
