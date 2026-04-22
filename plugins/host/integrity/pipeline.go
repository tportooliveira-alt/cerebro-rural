// Package integrity implementa o pipeline obrigatório antes de qualquer Execute
// que produza efeito persistente. Fase 1: apenas estrutura + validate dry-run.
// Fases seguintes plugam: schema JSON, idempotência, permissões, coerência, audit.
package integrity

import (
	"context"
	"errors"
	"fmt"

	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/adapter"
	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

type Pipeline struct {
	steps []Step
}

type Step interface {
	Name() string
	Check(ctx context.Context, cmd *extv1.Command) error
}

func NewPipeline(steps ...Step) *Pipeline {
	return &Pipeline{steps: steps}
}

// Run aplica todos os passos em ordem e, se todos passam, delega ao Validate do
// plugin como última barreira (dry-run).
func (p *Pipeline) Run(ctx context.Context, ext adapter.Extension, cmd *extv1.Command) error {
	if cmd.RequestId == "" {
		return errors.New("integrity: request_id obrigatório")
	}
	if cmd.TenantId == "" {
		return errors.New("integrity: tenant_id obrigatório")
	}
	for _, s := range p.steps {
		if err := s.Check(ctx, cmd); err != nil {
			return fmt.Errorf("integrity[%s]: %w", s.Name(), err)
		}
	}
	resp, err := ext.Validate(ctx, cmd)
	if err != nil {
		return fmt.Errorf("integrity: plugin Validate: %w", err)
	}
	if !resp.Ok {
		return fmt.Errorf("integrity: plugin rejeitou: %+v", resp.Issues)
	}
	return nil
}
