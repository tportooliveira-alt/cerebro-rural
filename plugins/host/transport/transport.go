// Package transport encapsula a integração com hashicorp/go-plugin
// e expõe ao resto do host apenas a interface ExtensionClient do contrato v1.
package transport

import (
	"context"

	"github.com/hashicorp/go-plugin"
	"google.golang.org/grpc"

	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

// Versão do protocolo do host. Plugins declaram a sua em Version().
// Regra: aceitar plugin se ProtocolMajor == host.major && plugin.minor <= host.minor.
const (
	HostProtocolMajor uint32 = 1
	HostProtocolMinor uint32 = 0
)

// Handshake é a assinatura mágica usada por go-plugin para validar que o processo
// filho é mesmo um plugin do Cerebro Rural. Troca isso só em breaking change real.
var Handshake = plugin.HandshakeConfig{
	ProtocolVersion:  1,
	MagicCookieKey:   "CEREBRO_RURAL_PLUGIN",
	MagicCookieValue: "br.cerebro.rural.v1",
}

// PluginName é a chave usada em PluginMap. Todo plugin registra sob esse nome.
const PluginName = "extension"

// ExtensionGRPCPlugin adapta ExtensionService para o modelo de go-plugin.
type ExtensionGRPCPlugin struct {
	plugin.Plugin
	Impl extv1.ExtensionServiceServer // usado apenas no lado do plugin
}

func (p *ExtensionGRPCPlugin) GRPCServer(_ *plugin.GRPCBroker, s *grpc.Server) error {
	extv1.RegisterExtensionServiceServer(s, p.Impl)
	return nil
}

func (p *ExtensionGRPCPlugin) GRPCClient(_ context.Context, _ *plugin.GRPCBroker, c *grpc.ClientConn) (any, error) {
	return extv1.NewExtensionServiceClient(c), nil
}

// PluginMap é compartilhado entre host e plugin.
func PluginMap(impl extv1.ExtensionServiceServer) map[string]plugin.Plugin {
	return map[string]plugin.Plugin{
		PluginName: &ExtensionGRPCPlugin{Impl: impl},
	}
}
