package integrity

import (
	"context"
	"fmt"
)

// PermissionProvider resolve a allowlist de (module, action) para um tenant.
// Fase 2: allowlist estática em memória. Produção: ler de tabela tenant_capabilities.
type PermissionProvider interface {
	Allowed(ctx context.Context, tenantID, module, action string) (bool, error)
}

// StaticAllowlist implementa PermissionProvider com mapa estático.
// Chave formato: "tenant|module|action". Tenant "*" = qualquer tenant.
type StaticAllowlist struct {
	set map[string]struct{}
}

func NewStaticAllowlist(triples ...string) *StaticAllowlist {
	s := &StaticAllowlist{set: make(map[string]struct{}, len(triples))}
	for _, t := range triples {
		s.set[t] = struct{}{}
	}
	return s
}

func (a *StaticAllowlist) Allow(tenant, module, action string) {
	a.set[tenant+"|"+module+"|"+action] = struct{}{}
}

func (a *StaticAllowlist) Allowed(_ context.Context, tenantID, module, action string) (bool, error) {
	if _, ok := a.set["*|"+module+"|"+action]; ok {
		return true, nil
	}
	_, ok := a.set[tenantID+"|"+module+"|"+action]
	return ok, nil
}

// PermissionsStep bloqueia se o tenant não tem a capability liberada.
type PermissionsStep struct {
	Provider PermissionProvider
}

func (PermissionsStep) Name() string { return "permissions" }

func (s PermissionsStep) Check(ctx context.Context, pc *Context) error {
	if s.Provider == nil {
		return fmt.Errorf("permission provider não configurado")
	}
	ok, err := s.Provider.Allowed(ctx, pc.Cmd.TenantId, pc.Cmd.Module, pc.Cmd.Action)
	if err != nil {
		return err
	}
	if !ok {
		return fmt.Errorf("tenant %q não autorizado para %s/%s",
			pc.Cmd.TenantId, pc.Cmd.Module, pc.Cmd.Action)
	}
	return nil
}
