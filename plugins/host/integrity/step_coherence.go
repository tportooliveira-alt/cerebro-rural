package integrity

import (
	"context"
	"fmt"
)

// CoherenceRule é uma regra de domínio cruzada, independente do plugin.
// Exemplos: "valor > 0", "data não no futuro", "soma de parcelas == total".
type CoherenceRule func(pc *Context) error

// CoherenceStep executa todas as regras em sequência. Fase 2: stub vazio por padrão,
// com hook para registrar regras globais ou por (module, action).
type CoherenceStep struct {
	Global  []CoherenceRule
	ByRoute map[string][]CoherenceRule // chave: "module/action"
}

func NewCoherenceStep() *CoherenceStep {
	return &CoherenceStep{ByRoute: map[string][]CoherenceRule{}}
}

func (CoherenceStep) Name() string { return "coherence" }

func (s *CoherenceStep) Register(module, action string, rules ...CoherenceRule) {
	k := module + "/" + action
	s.ByRoute[k] = append(s.ByRoute[k], rules...)
}

func (s *CoherenceStep) Check(_ context.Context, pc *Context) error {
	for i, r := range s.Global {
		if err := r(pc); err != nil {
			return fmt.Errorf("regra global #%d: %w", i, err)
		}
	}
	k := pc.Cmd.Module + "/" + pc.Cmd.Action
	for i, r := range s.ByRoute[k] {
		if err := r(pc); err != nil {
			return fmt.Errorf("regra %s #%d: %w", k, i, err)
		}
	}
	return nil
}
