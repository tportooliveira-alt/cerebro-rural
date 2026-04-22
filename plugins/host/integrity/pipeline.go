// Package integrity implementa o pipeline obrigatório antes de qualquer Execute
// que produza efeito persistente.
//
// Ordem:
//   1. schema       — payload bate com JSON Schema declarado em Capabilities
//   2. idempotency  — request_id ainda não visto (dentro do TTL)
//   3. permissions  — (tenant_id, module, action) está liberado
//   4. coherence    — regras de domínio cruzadas
//   5. plugin.Validate — dry-run final delegado ao plugin
//   + audit         — registra attempt, rejected, accepted e completed
package integrity

import (
	"context"
	"errors"
	"fmt"

	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/adapter"
	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

// Step é um passo do pipeline. Recebe um Context com metadados já resolvidos
// (capability do plugin) para não forçar cada step a chamar o plugin.
type Step interface {
	Name() string
	Check(ctx context.Context, pc *Context) error
}

// Context reúne tudo que os steps precisam para decidir.
type Context struct {
	Ext        adapter.Extension
	Cmd        *extv1.Command
	Capability *extv1.Capability // nil se o plugin não declara essa (module,action)
}

// Pipeline aplica todos os Steps em ordem e, no fim, delega ao Validate do plugin.
type Pipeline struct {
	steps []Step
	audit AuditSink
}

// Option configura o Pipeline.
type Option func(*Pipeline)

// WithAudit registra um sink para tentativas (aceitas e rejeitadas).
func WithAudit(sink AuditSink) Option {
	return func(p *Pipeline) { p.audit = sink }
}

func NewPipeline(steps []Step, opts ...Option) *Pipeline {
	p := &Pipeline{steps: steps, audit: NoopAudit{}}
	for _, o := range opts {
		o(p)
	}
	return p
}

// Run valida o Command contra todos os Steps. Retorna erro indicando o step que falhou.
// O chamador só deve prosseguir para Execute se Run retornar nil.
func (p *Pipeline) Run(ctx context.Context, ext adapter.Extension, cmd *extv1.Command) error {
	if cmd == nil {
		return errors.New("integrity: command nulo")
	}
	if cmd.RequestId == "" {
		return errors.New("integrity: request_id obrigatório")
	}
	if cmd.TenantId == "" {
		return errors.New("integrity: tenant_id obrigatório")
	}

	cap, err := resolveCapability(ctx, ext, cmd)
	if err != nil {
		_ = p.audit.Rejected(ctx, cmd, "capability", err)
		return fmt.Errorf("integrity: capability: %w", err)
	}
	pc := &Context{Ext: ext, Cmd: cmd, Capability: cap}

	_ = p.audit.Attempt(ctx, cmd)

	for _, s := range p.steps {
		if err := s.Check(ctx, pc); err != nil {
			_ = p.audit.Rejected(ctx, cmd, s.Name(), err)
			return fmt.Errorf("integrity[%s]: %w", s.Name(), err)
		}
	}

	resp, err := ext.Validate(ctx, cmd)
	if err != nil {
		_ = p.audit.Rejected(ctx, cmd, "plugin.Validate", err)
		return fmt.Errorf("integrity: plugin.Validate: %w", err)
	}
	if !resp.Ok {
		issueErr := fmt.Errorf("%+v", resp.Issues)
		_ = p.audit.Rejected(ctx, cmd, "plugin.Validate", issueErr)
		return fmt.Errorf("integrity: plugin rejeitou: %+v", resp.Issues)
	}
	_ = p.audit.Accepted(ctx, cmd)
	return nil
}

// Commit registra o resultado final (pós-Execute). Chame sempre, sucesso ou falha.
func (p *Pipeline) Commit(ctx context.Context, cmd *extv1.Command, resp *extv1.ExecuteResponse, execErr error) {
	_ = p.audit.Completed(ctx, cmd, resp, execErr)
}

func resolveCapability(ctx context.Context, ext adapter.Extension, cmd *extv1.Command) (*extv1.Capability, error) {
	caps, err := ext.Capabilities(ctx)
	if err != nil {
		return nil, err
	}
	for _, c := range caps.Capabilities {
		if c.Module == cmd.Module && c.Action == cmd.Action {
			return c, nil
		}
	}
	return nil, fmt.Errorf("plugin não declara %s/%s", cmd.Module, cmd.Action)
}
