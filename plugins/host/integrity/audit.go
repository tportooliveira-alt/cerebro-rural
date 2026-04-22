package integrity

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"

	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

// AuditSink recebe eventos do pipeline. Implementações podem gravar em log, fila,
// tabela Supabase, etc. Fase 2: JSONSink para stdout/arquivo.
type AuditSink interface {
	Attempt(ctx context.Context, cmd *extv1.Command) error
	Rejected(ctx context.Context, cmd *extv1.Command, step string, err error) error
	Accepted(ctx context.Context, cmd *extv1.Command) error
	Completed(ctx context.Context, cmd *extv1.Command, resp *extv1.ExecuteResponse, execErr error) error
}

// NoopAudit descarta tudo. Útil para testes.
type NoopAudit struct{}

func (NoopAudit) Attempt(context.Context, *extv1.Command) error { return nil }
func (NoopAudit) Rejected(context.Context, *extv1.Command, string, error) error {
	return nil
}
func (NoopAudit) Accepted(context.Context, *extv1.Command) error { return nil }
func (NoopAudit) Completed(context.Context, *extv1.Command, *extv1.ExecuteResponse, error) error {
	return nil
}

// JSONSink serializa cada evento como uma linha JSON num *os.File (thread-safe).
type JSONSink struct {
	mu sync.Mutex
	w  *os.File
}

// NewStdoutAudit escreve em os.Stdout.
func NewStdoutAudit() *JSONSink { return &JSONSink{w: os.Stdout} }

// NewFileAudit abre (ou cria) o arquivo em modo append.
func NewFileAudit(path string) (*JSONSink, error) {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, err
	}
	return &JSONSink{w: f}, nil
}

func (s *JSONSink) write(ev map[string]any) error {
	ev["ts"] = time.Now().UTC().Format(time.RFC3339Nano)
	b, err := json.Marshal(ev)
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err = fmt.Fprintln(s.w, string(b))
	return err
}

func base(cmd *extv1.Command) map[string]any {
	return map[string]any{
		"request_id": cmd.RequestId,
		"tenant_id":  cmd.TenantId,
		"module":     cmd.Module,
		"action":     cmd.Action,
	}
}

func (s *JSONSink) Attempt(_ context.Context, cmd *extv1.Command) error {
	ev := base(cmd)
	ev["event"] = "attempt"
	return s.write(ev)
}

func (s *JSONSink) Rejected(_ context.Context, cmd *extv1.Command, step string, err error) error {
	ev := base(cmd)
	ev["event"] = "rejected"
	ev["step"] = step
	ev["error"] = err.Error()
	return s.write(ev)
}

func (s *JSONSink) Accepted(_ context.Context, cmd *extv1.Command) error {
	ev := base(cmd)
	ev["event"] = "accepted"
	return s.write(ev)
}

func (s *JSONSink) Completed(_ context.Context, cmd *extv1.Command, resp *extv1.ExecuteResponse, execErr error) error {
	ev := base(cmd)
	ev["event"] = "completed"
	if execErr != nil {
		ev["error"] = execErr.Error()
	}
	if resp != nil {
		ev["ok"] = resp.Ok
	}
	return s.write(ev)
}
