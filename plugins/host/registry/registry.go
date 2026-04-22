// Package registry mantém o ciclo de vida das extensões carregadas e aplica
// a regra de compatibilidade de protocolo declarada no blueprint.
package registry

import (
	"context"
	"fmt"
	"sync"

	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/adapter"
	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/transport"
)

type Registry struct {
	mu       sync.RWMutex
	adapters map[string]adapter.Adapter
	loaded   map[string]adapter.Extension
}

func New(adapters ...adapter.Adapter) *Registry {
	r := &Registry{
		adapters: make(map[string]adapter.Adapter, len(adapters)),
		loaded:   make(map[string]adapter.Extension),
	}
	for _, a := range adapters {
		r.adapters[a.Kind()] = a
	}
	return r
}

// Load carrega uma Source usando o adapter adequado e valida o handshake de versão.
func (r *Registry) Load(ctx context.Context, src adapter.Source) (adapter.Extension, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if ext, ok := r.loaded[src.ID]; ok {
		return ext, nil
	}
	a, ok := r.adapters[src.Kind]
	if !ok {
		return nil, fmt.Errorf("registry: adapter desconhecido %q", src.Kind)
	}
	ext, err := a.Load(ctx, src)
	if err != nil {
		return nil, err
	}

	ver, err := ext.Version(ctx)
	if err != nil {
		_ = ext.Close()
		return nil, fmt.Errorf("registry: Version() falhou para %s: %w", src.ID, err)
	}
	if err := checkProtocol(ver.ProtocolMajor, ver.ProtocolMinor); err != nil {
		_ = ext.Close()
		return nil, err
	}
	r.loaded[src.ID] = ext
	return ext, nil
}

// Get devolve extensão já carregada.
func (r *Registry) Get(id string) (adapter.Extension, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	ext, ok := r.loaded[id]
	return ext, ok
}

// CloseAll finaliza todos os plugins.
func (r *Registry) CloseAll() {
	r.mu.Lock()
	defer r.mu.Unlock()
	for id, ext := range r.loaded {
		_ = ext.Close()
		delete(r.loaded, id)
	}
}

func checkProtocol(major, minor uint32) error {
	if major != transport.HostProtocolMajor {
		return fmt.Errorf("protocolo incompatível: plugin v%d.%d, host v%d.%d (major diferente)",
			major, minor, transport.HostProtocolMajor, transport.HostProtocolMinor)
	}
	if minor > transport.HostProtocolMinor {
		return fmt.Errorf("protocolo à frente do host: plugin v%d.%d, host v%d.%d",
			major, minor, transport.HostProtocolMajor, transport.HostProtocolMinor)
	}
	return nil
}
