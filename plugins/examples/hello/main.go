// hello — plugin de referência. Ação "ping" devolve {"pong": "<name>"}.
package main

import (
	"context"
	"encoding/json"
	"fmt"

	sdk "github.com/tportooliveira-alt/cerebro-rural/plugins/sdk/go"
	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

type hello struct{}

func (hello) PluginID() string      { return "hello" }
func (hello) PluginVersion() string { return "0.1.0" }

func (hello) Capabilities(_ context.Context) ([]*extv1.Capability, error) {
	return []*extv1.Capability{{
		Module:        "hello",
		Action:        "ping",
		SchemaPayload: `{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}`,
	}}, nil
}

type pingPayload struct {
	Name string `json:"name"`
}

func (hello) Validate(_ context.Context, cmd *extv1.Command) (*extv1.ValidateResponse, error) {
	if cmd.Module != "hello" || cmd.Action != "ping" {
		return &extv1.ValidateResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "unknown_action",
			Message: fmt.Sprintf("ação desconhecida %s/%s", cmd.Module, cmd.Action),
		}}}, nil
	}
	var p pingPayload
	if err := json.Unmarshal([]byte(cmd.PayloadJson), &p); err != nil || p.Name == "" {
		return &extv1.ValidateResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "invalid_payload",
			Message: "name é obrigatório", Path: "name",
		}}}, nil
	}
	return &extv1.ValidateResponse{Ok: true}, nil
}

func (h hello) Execute(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	v, err := h.Validate(ctx, cmd)
	if err != nil || !v.Ok {
		return &extv1.ExecuteResponse{Ok: false, Issues: v.GetIssues()}, err
	}
	var p pingPayload
	_ = json.Unmarshal([]byte(cmd.PayloadJson), &p)
	result, _ := json.Marshal(map[string]string{"pong": p.Name, "tenant": cmd.TenantId})
	return &extv1.ExecuteResponse{Ok: true, ResultJson: string(result)}, nil
}

func main() { sdk.Serve(hello{}) }
