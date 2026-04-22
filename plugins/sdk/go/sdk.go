// Package sdk ajuda autores de plugin em Go. Basta implementar Handler e chamar Serve.
package sdk

import (
	"context"

	"github.com/hashicorp/go-plugin"

	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/transport"
	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

// Handler é o contrato que o autor do plugin implementa. Mais limpo que mexer em gRPC.
type Handler interface {
	PluginID() string
	PluginVersion() string
	Capabilities(ctx context.Context) ([]*extv1.Capability, error)
	Validate(ctx context.Context, cmd *extv1.Command) (*extv1.ValidateResponse, error)
	Execute(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error)
}

// Serve bloqueia e expõe o Handler como servidor gRPC via go-plugin.
func Serve(h Handler) {
	srv := &server{h: h}
	plugin.Serve(&plugin.ServeConfig{
		HandshakeConfig: transport.Handshake,
		Plugins:         transport.PluginMap(srv),
		GRPCServer:      plugin.DefaultGRPCServer,
	})
}

type server struct {
	extv1.UnimplementedExtensionServiceServer
	h Handler
}

func (s *server) Health(ctx context.Context, _ *extv1.HealthRequest) (*extv1.HealthResponse, error) {
	return &extv1.HealthResponse{Ok: true, Message: "ok"}, nil
}

func (s *server) Version(_ context.Context, _ *extv1.VersionRequest) (*extv1.VersionResponse, error) {
	return &extv1.VersionResponse{
		ProtocolMajor: transport.HostProtocolMajor,
		ProtocolMinor: transport.HostProtocolMinor,
		PluginId:      s.h.PluginID(),
		PluginVersion: s.h.PluginVersion(),
	}, nil
}

func (s *server) Capabilities(ctx context.Context, _ *extv1.CapabilitiesRequest) (*extv1.CapabilitiesResponse, error) {
	caps, err := s.h.Capabilities(ctx)
	if err != nil {
		return nil, err
	}
	return &extv1.CapabilitiesResponse{Capabilities: caps}, nil
}

func (s *server) Validate(ctx context.Context, cmd *extv1.Command) (*extv1.ValidateResponse, error) {
	return s.h.Validate(ctx, cmd)
}

func (s *server) Execute(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	return s.h.Execute(ctx, cmd)
}
