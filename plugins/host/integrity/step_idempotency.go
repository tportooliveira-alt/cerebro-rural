package integrity

import (
	"context"
	"errors"
	"sync"
	"time"
)

// IdempotencyStore guarda request_ids já processados. Fase 2: memória com TTL.
// Produção: trocar por tabela Supabase / Redis sem mexer no pipeline.
type IdempotencyStore interface {
	Seen(ctx context.Context, tenantID, requestID string) (bool, error)
	Mark(ctx context.Context, tenantID, requestID string, ttl time.Duration) error
}

// MemoryStore é um IdempotencyStore in-memory com expiração.
type MemoryStore struct {
	mu   sync.Mutex
	data map[string]time.Time
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{data: make(map[string]time.Time)}
}

func key(tenantID, requestID string) string { return tenantID + "|" + requestID }

func (m *MemoryStore) Seen(_ context.Context, tenantID, requestID string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	exp, ok := m.data[key(tenantID, requestID)]
	if !ok {
		return false, nil
	}
	if time.Now().After(exp) {
		delete(m.data, key(tenantID, requestID))
		return false, nil
	}
	return true, nil
}

func (m *MemoryStore) Mark(_ context.Context, tenantID, requestID string, ttl time.Duration) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.data[key(tenantID, requestID)] = time.Now().Add(ttl)
	return nil
}

// IdempotencyStep bloqueia request_id repetido dentro do TTL.
type IdempotencyStep struct {
	Store IdempotencyStore
	TTL   time.Duration
}

func (IdempotencyStep) Name() string { return "idempotency" }

func (s IdempotencyStep) Check(ctx context.Context, pc *Context) error {
	if s.Store == nil {
		return errors.New("idempotency store não configurado")
	}
	seen, err := s.Store.Seen(ctx, pc.Cmd.TenantId, pc.Cmd.RequestId)
	if err != nil {
		return err
	}
	if seen {
		return errors.New("request_id já processado")
	}
	ttl := s.TTL
	if ttl == 0 {
		ttl = 24 * time.Hour
	}
	return s.Store.Mark(ctx, pc.Cmd.TenantId, pc.Cmd.RequestId, ttl)
}
