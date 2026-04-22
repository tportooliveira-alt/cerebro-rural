package adapter

import (
	"context"
	"fmt"
	"os/exec"

	"github.com/hashicorp/go-plugin"

	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/transport"
)

// BinaryAdapter carrega plugins como subprocessos locais via hashicorp/go-plugin.
// Isolamento por processo, comunicação gRPC sobre stdio.
type BinaryAdapter struct{}

func NewBinaryAdapter() *BinaryAdapter { return &BinaryAdapter{} }

func (a *BinaryAdapter) Kind() string { return "binary" }

func (a *BinaryAdapter) Load(_ context.Context, src Source) (Extension, error) {
	if src.Location == "" {
		return nil, fmt.Errorf("binary adapter: location vazio para %q", src.ID)
	}

	client := plugin.NewClient(&plugin.ClientConfig{
		HandshakeConfig:  transport.Handshake,
		Plugins:          transport.PluginMap(nil),
		Cmd:              exec.Command(src.Location),
		AllowedProtocols: []plugin.Protocol{plugin.ProtocolGRPC},
	})
	rpc, err := client.Client()
	if err != nil {
		client.Kill()
		return nil, fmt.Errorf("binary adapter: conectar %s: %w", src.ID, err)
	}
	raw, err := rpc.Dispense(transport.PluginName)
	if err != nil {
		client.Kill()
		return nil, fmt.Errorf("binary adapter: dispense %s: %w", src.ID, err)
	}
	grpcClient, ok := raw.(extv1.ExtensionServiceClient)
	if !ok {
		client.Kill()
		return nil, fmt.Errorf("binary adapter: tipo inesperado %T", raw)
	}

	return &binaryExtension{id: src.ID, client: client, grpc: grpcClient}, nil
}

type binaryExtension struct {
	id     string
	client *plugin.Client
	grpc   extv1.ExtensionServiceClient
}

func (e *binaryExtension) ID() string    { return e.id }
func (e *binaryExtension) Close() error  { e.client.Kill(); return nil }

func (e *binaryExtension) Health(ctx context.Context) (*extv1.HealthResponse, error) {
	return e.grpc.Health(ctx, &extv1.HealthRequest{})
}
func (e *binaryExtension) Version(ctx context.Context) (*extv1.VersionResponse, error) {
	return e.grpc.Version(ctx, &extv1.VersionRequest{})
}
func (e *binaryExtension) Capabilities(ctx context.Context) (*extv1.CapabilitiesResponse, error) {
	return e.grpc.Capabilities(ctx, &extv1.CapabilitiesRequest{})
}
func (e *binaryExtension) Validate(ctx context.Context, cmd *extv1.Command) (*extv1.ValidateResponse, error) {
	return e.grpc.Validate(ctx, cmd)
}
func (e *binaryExtension) Execute(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	return e.grpc.Execute(ctx, cmd)
}
