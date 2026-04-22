// Package agent — Orchestrator roteia um Command para o sub-agente certo e,
// opcionalmente, encadeia múltiplos em pipeline. Também é uma Extension:
// module=spec.Module, actions=nomes dos sub-agentes registrados.
package agent

import (
	"context"
	"encoding/json"
	"fmt"

	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

type Orchestrator struct {
	module string
	subs   map[string]*Agent // action -> sub-agente
	order  []string
}

func NewOrchestrator(module string) *Orchestrator {
	return &Orchestrator{module: module, subs: map[string]*Agent{}}
}

// Register adiciona um sub-agente. A action do orquestrador = nome do agente.
func (o *Orchestrator) Register(sub *Agent) {
	o.subs[sub.spec.Name] = sub
	o.order = append(o.order, sub.spec.Name)
}

func (o *Orchestrator) ID() string   { return "orchestrator/" + o.module }
func (o *Orchestrator) Close() error { return nil }

func (o *Orchestrator) Health(ctx context.Context) (*extv1.HealthResponse, error) {
	return &extv1.HealthResponse{Ok: true, Message: fmt.Sprintf("orchestrator: %d agentes", len(o.subs))}, nil
}
func (o *Orchestrator) Version(ctx context.Context) (*extv1.VersionResponse, error) {
	return &extv1.VersionResponse{PluginId: o.ID(), PluginVersion: "1.0", ProtocolMajor: 1}, nil
}
func (o *Orchestrator) Capabilities(ctx context.Context) (*extv1.CapabilitiesResponse, error) {
	caps := []*extv1.Capability{{
		Module: o.module, Action: "pipeline",
		SchemaPayload: `{"type":"object","required":["steps","task"],"properties":{"task":{"type":"string"},"steps":{"type":"array","items":{"type":"string"}}}}`,
	}}
	for _, name := range o.order {
		caps = append(caps, &extv1.Capability{
			Module: o.module, Action: name,
			SchemaPayload: `{"type":"object","required":["task"],"properties":{"task":{"type":"string"}}}`,
		})
	}
	return &extv1.CapabilitiesResponse{Capabilities: caps}, nil
}

func (o *Orchestrator) Validate(ctx context.Context, cmd *extv1.Command) (*extv1.ValidateResponse, error) {
	if cmd.Module != o.module {
		return &extv1.ValidateResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "ROUTE", Message: "módulo inválido",
		}}}, nil
	}
	if cmd.Action == "pipeline" {
		return &extv1.ValidateResponse{Ok: true}, nil
	}
	if _, ok := o.subs[cmd.Action]; !ok {
		return &extv1.ValidateResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "NO_AGENT", Message: "agente não registrado: " + cmd.Action,
		}}}, nil
	}
	return &extv1.ValidateResponse{Ok: true}, nil
}

func (o *Orchestrator) Execute(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	if cmd.Action == "pipeline" {
		return o.runPipeline(ctx, cmd)
	}
	sub, ok := o.subs[cmd.Action]
	if !ok {
		return &extv1.ExecuteResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "NO_AGENT", Message: cmd.Action,
		}}}, nil
	}
	// repassa cmd mudando module/action para os do sub-agente
	sc := *cmd
	sc.Module = sub.spec.Module
	sc.Action = sub.spec.Action
	return sub.Execute(ctx, &sc)
}

func (o *Orchestrator) runPipeline(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	var in struct {
		Task  string   `json:"task"`
		Steps []string `json:"steps"`
	}
	_ = json.Unmarshal([]byte(cmd.PayloadJson), &in)
	if in.Task == "" || len(in.Steps) == 0 {
		return &extv1.ExecuteResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "PIPELINE_EMPTY", Message: "task e steps obrigatórios",
		}}}, nil
	}
	task := in.Task
	results := []map[string]any{}
	for i, name := range in.Steps {
		sub, ok := o.subs[name]
		if !ok {
			return &extv1.ExecuteResponse{Ok: false, Issues: []*extv1.Issue{{
				Severity: extv1.Issue_ERROR, Code: "NO_AGENT", Message: name,
			}}}, nil
		}
		payload, _ := json.Marshal(map[string]string{"task": task})
		sc := &extv1.Command{
			RequestId: fmt.Sprintf("%s/step-%d-%s", cmd.RequestId, i, name),
			TenantId:  cmd.TenantId,
			Module:    sub.spec.Module, Action: sub.spec.Action,
			PayloadJson: string(payload),
			Meta:        map[string]string{"pipeline": cmd.RequestId},
		}
		res, err := sub.Execute(ctx, sc)
		if err != nil {
			return nil, err
		}
		var out struct{ Answer string `json:"answer"` }
		_ = json.Unmarshal([]byte(res.ResultJson), &out)
		results = append(results, map[string]any{"agent": name, "answer": out.Answer})
		// o output vira contexto para o próximo step
		task = fmt.Sprintf("Contexto do passo anterior (%s):\n%s\n\nTarefa original: %s",
			name, out.Answer, in.Task)
	}
	b, _ := json.Marshal(map[string]any{"steps": results, "final": results[len(results)-1]["answer"]})
	return &extv1.ExecuteResponse{Ok: true, ResultJson: string(b)}, nil
}
