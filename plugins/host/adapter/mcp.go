// Package adapter — MCP (Model Context Protocol) como Extension.
// Suporta múltiplos transportes e autenticação:
//   - stdio: spawna processo local (MCP oficial: filesystem, git, sqlite, ...)
//   - http / sse: POST JSON-RPC em URL remota (MCP Streamable HTTP) com
//     headers arbitrários — Authorization Bearer, x-api-key, OAuth, etc.
package adapter

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os/exec"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

// MCPServerSpec descreve um servidor MCP.
type MCPServerSpec struct {
	Name      string `json:"name"`
	Module    string `json:"module,omitempty"`
	Transport string `json:"transport,omitempty"` // "stdio"|"http"|"sse"

	// stdio
	Command string            `json:"command,omitempty"`
	Args    []string          `json:"args,omitempty"`
	Env     map[string]string `json:"env,omitempty"`

	// http/sse
	URL     string            `json:"url,omitempty"`
	Headers map[string]string `json:"headers,omitempty"`
}

type MCPAdapter struct{}

func NewMCPAdapter() *MCPAdapter   { return &MCPAdapter{} }
func (a *MCPAdapter) Kind() string { return "mcp" }

func (a *MCPAdapter) Load(ctx context.Context, src Source) (Extension, error) {
	raw, ok := src.Config["spec"]
	if !ok {
		return nil, fmt.Errorf("mcp: Source.Config[\"spec\"] ausente")
	}
	var spec MCPServerSpec
	if err := json.Unmarshal([]byte(raw), &spec); err != nil {
		return nil, fmt.Errorf("mcp: spec inválida: %w", err)
	}
	return StartMCP(ctx, src.ID, spec)
}

type mcpTransport interface {
	call(ctx context.Context, method string, params any) (json.RawMessage, error)
	notify(method string, params any) error
	close() error
}

func StartMCP(ctx context.Context, id string, spec MCPServerSpec) (*MCPExtension, error) {
	if spec.Module == "" {
		spec.Module = spec.Name
	}
	if spec.Transport == "" {
		spec.Transport = "stdio"
	}
	var tr mcpTransport
	var err error
	switch spec.Transport {
	case "stdio":
		tr, err = newStdioTransport(ctx, spec)
	case "http", "sse":
		tr, err = newHTTPTransport(spec)
	default:
		return nil, fmt.Errorf("mcp[%s]: transport %q desconhecido", spec.Name, spec.Transport)
	}
	if err != nil {
		return nil, err
	}

	ext := &MCPExtension{id: id, spec: spec, tr: tr}

	initCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	if _, err := tr.call(initCtx, "initialize", map[string]any{
		"protocolVersion": "2024-11-05",
		"capabilities":    map[string]any{},
		"clientInfo":      map[string]any{"name": "cerebro-host", "version": "0.4.0"},
	}); err != nil {
		_ = tr.close()
		return nil, fmt.Errorf("mcp[%s]: initialize: %w", spec.Name, err)
	}
	_ = tr.notify("notifications/initialized", nil)

	toolsRes, err := tr.call(initCtx, "tools/list", map[string]any{})
	if err != nil {
		_ = tr.close()
		return nil, fmt.Errorf("mcp[%s]: tools/list: %w", spec.Name, err)
	}
	var tl struct {
		Tools []struct {
			Name        string          `json:"name"`
			Description string          `json:"description"`
			InputSchema json.RawMessage `json:"inputSchema"`
		} `json:"tools"`
	}
	if err := json.Unmarshal(toolsRes, &tl); err != nil {
		_ = tr.close()
		return nil, fmt.Errorf("mcp[%s]: parse tools: %w", spec.Name, err)
	}
	caps := make([]*extv1.Capability, 0, len(tl.Tools))
	for _, t := range tl.Tools {
		schema := string(t.InputSchema)
		if schema == "" || schema == "null" {
			schema = `{"type":"object"}`
		}
		if t.Description != "" {
			var obj map[string]any
			if json.Unmarshal([]byte(schema), &obj) == nil {
				if _, has := obj["$comment"]; !has {
					obj["$comment"] = t.Description
					if b, err := json.Marshal(obj); err == nil {
						schema = string(b)
					}
				}
			}
		}
		caps = append(caps, &extv1.Capability{
			Module:        spec.Module,
			Action:        t.Name,
			SchemaPayload: schema,
		})
	}
	ext.capabilities = caps
	return ext, nil
}

type MCPExtension struct {
	id           string
	spec         MCPServerSpec
	tr           mcpTransport
	capabilities []*extv1.Capability
}

func (e *MCPExtension) ID() string   { return e.id }
func (e *MCPExtension) Close() error { return e.tr.close() }

func (e *MCPExtension) Health(ctx context.Context) (*extv1.HealthResponse, error) {
	return &extv1.HealthResponse{Ok: true, Message: "mcp:" + e.spec.Name}, nil
}
func (e *MCPExtension) Version(ctx context.Context) (*extv1.VersionResponse, error) {
	return &extv1.VersionResponse{
		PluginId: "mcp/" + e.spec.Name, PluginVersion: "mcp-1.0",
		ProtocolMajor: 1, ProtocolMinor: 0,
	}, nil
}
func (e *MCPExtension) Capabilities(ctx context.Context) (*extv1.CapabilitiesResponse, error) {
	return &extv1.CapabilitiesResponse{Capabilities: e.capabilities}, nil
}
func (e *MCPExtension) Validate(ctx context.Context, cmd *extv1.Command) (*extv1.ValidateResponse, error) {
	if cmd.Module != e.spec.Module {
		return &extv1.ValidateResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "MCP_MODULE_MISMATCH",
			Message: "módulo não corresponde ao servidor MCP",
		}}}, nil
	}
	for _, c := range e.capabilities {
		if c.Action == cmd.Action {
			return &extv1.ValidateResponse{Ok: true}, nil
		}
	}
	return &extv1.ValidateResponse{Ok: false, Issues: []*extv1.Issue{{
		Severity: extv1.Issue_ERROR, Code: "MCP_UNKNOWN_TOOL",
		Message: "tool desconhecida: " + cmd.Action,
	}}}, nil
}
func (e *MCPExtension) Execute(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	var args map[string]any
	if cmd.PayloadJson != "" {
		if err := json.Unmarshal([]byte(cmd.PayloadJson), &args); err != nil {
			return &extv1.ExecuteResponse{Ok: false, Issues: []*extv1.Issue{{
				Severity: extv1.Issue_ERROR, Code: "BAD_PAYLOAD", Message: err.Error(),
			}}}, nil
		}
	}
	res, err := e.tr.call(ctx, "tools/call", map[string]any{
		"name": cmd.Action, "arguments": args,
	})
	if err != nil {
		return &extv1.ExecuteResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "MCP_ERROR", Message: err.Error(),
		}}}, nil
	}
	return &extv1.ExecuteResponse{Ok: true, ResultJson: string(res)}, nil
}

// ---------- JSON-RPC ----------

type rpcRequest struct {
	JSONRPC string `json:"jsonrpc"`
	ID      int64  `json:"id,omitempty"`
	Method  string `json:"method"`
	Params  any    `json:"params,omitempty"`
}
type rpcNotification struct {
	JSONRPC string `json:"jsonrpc"`
	Method  string `json:"method"`
	Params  any    `json:"params,omitempty"`
}
type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      *int64          `json:"id,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}
type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// ---------- stdio transport ----------

type stdioTransport struct {
	cmd     *exec.Cmd
	stdin   io.WriteCloser
	stdout  *bufio.Reader
	writeM  sync.Mutex
	nextID  atomic.Int64
	mu      sync.Mutex
	pending map[int64]chan rpcResponse
	closed  bool
}

func newStdioTransport(ctx context.Context, spec MCPServerSpec) (*stdioTransport, error) {
	if spec.Command == "" {
		return nil, fmt.Errorf("mcp[%s]: command vazio", spec.Name)
	}
	cmd := exec.CommandContext(ctx, spec.Command, spec.Args...)
	for k, v := range spec.Env {
		cmd.Env = append(cmd.Env, k+"="+v)
	}
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	cmd.Stderr = io.Discard
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("mcp[%s]: start: %w", spec.Name, err)
	}
	t := &stdioTransport{
		cmd: cmd, stdin: stdin,
		stdout:  bufio.NewReaderSize(stdout, 1<<16),
		pending: map[int64]chan rpcResponse{},
	}
	go t.readLoop()
	return t, nil
}

func (t *stdioTransport) call(ctx context.Context, method string, params any) (json.RawMessage, error) {
	id := t.nextID.Add(1)
	ch := make(chan rpcResponse, 1)
	t.mu.Lock()
	t.pending[id] = ch
	t.mu.Unlock()
	defer func() { t.mu.Lock(); delete(t.pending, id); t.mu.Unlock() }()
	if err := t.writeJSON(rpcRequest{JSONRPC: "2.0", ID: id, Method: method, Params: params}); err != nil {
		return nil, err
	}
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case resp, ok := <-ch:
		if !ok {
			return nil, fmt.Errorf("mcp: conexão fechada")
		}
		if resp.Error != nil {
			return nil, fmt.Errorf("rpc error %d: %s", resp.Error.Code, resp.Error.Message)
		}
		return resp.Result, nil
	}
}
func (t *stdioTransport) notify(method string, params any) error {
	return t.writeJSON(rpcNotification{JSONRPC: "2.0", Method: method, Params: params})
}
func (t *stdioTransport) writeJSON(v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	b = append(b, '\n')
	t.writeM.Lock()
	defer t.writeM.Unlock()
	_, err = t.stdin.Write(b)
	return err
}
func (t *stdioTransport) readLoop() {
	for {
		line, err := t.stdout.ReadBytes('\n')
		if len(line) > 0 {
			line = []byte(strings.TrimRight(string(line), "\r\n"))
			if len(line) > 0 {
				var resp rpcResponse
				if jerr := json.Unmarshal(line, &resp); jerr == nil && resp.ID != nil {
					t.mu.Lock()
					ch, ok := t.pending[*resp.ID]
					t.mu.Unlock()
					if ok {
						select {
						case ch <- resp:
						default:
						}
					}
				}
			}
		}
		if err != nil {
			t.mu.Lock()
			for _, ch := range t.pending {
				close(ch)
			}
			t.pending = map[int64]chan rpcResponse{}
			t.mu.Unlock()
			return
		}
	}
}
func (t *stdioTransport) close() error {
	t.mu.Lock()
	if t.closed {
		t.mu.Unlock()
		return nil
	}
	t.closed = true
	t.mu.Unlock()
	_ = t.stdin.Close()
	if t.cmd != nil && t.cmd.Process != nil {
		_ = t.cmd.Process.Kill()
	}
	return nil
}

// ---------- HTTP/SSE transport ----------

type httpTransport struct {
	url     string
	headers map[string]string
	client  *http.Client
	nextID  atomic.Int64
}

func newHTTPTransport(spec MCPServerSpec) (*httpTransport, error) {
	if spec.URL == "" {
		return nil, fmt.Errorf("mcp[%s]: url vazia", spec.Name)
	}
	return &httpTransport{
		url: spec.URL, headers: spec.Headers,
		client: &http.Client{Timeout: 60 * time.Second},
	}, nil
}

func (t *httpTransport) call(ctx context.Context, method string, params any) (json.RawMessage, error) {
	id := t.nextID.Add(1)
	body, _ := json.Marshal(rpcRequest{JSONRPC: "2.0", ID: id, Method: method, Params: params})
	req, err := http.NewRequestWithContext(ctx, "POST", t.url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	for k, v := range t.headers {
		req.Header.Set(k, v)
	}
	resp, err := t.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		msg, _ := io.ReadAll(io.LimitReader(resp.Body, 2<<10))
		return nil, fmt.Errorf("http %d: %s", resp.StatusCode, string(msg))
	}
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if strings.HasPrefix(resp.Header.Get("Content-Type"), "text/event-stream") {
		for _, line := range strings.Split(string(raw), "\n") {
			if strings.HasPrefix(line, "data:") {
				raw = []byte(strings.TrimSpace(strings.TrimPrefix(line, "data:")))
				break
			}
		}
	}
	var rr rpcResponse
	if err := json.Unmarshal(raw, &rr); err != nil {
		return nil, fmt.Errorf("parse: %w (body=%s)", err, string(raw))
	}
	if rr.Error != nil {
		return nil, fmt.Errorf("rpc error %d: %s", rr.Error.Code, rr.Error.Message)
	}
	return rr.Result, nil
}
func (t *httpTransport) notify(method string, params any) error {
	body, _ := json.Marshal(rpcNotification{JSONRPC: "2.0", Method: method, Params: params})
	req, _ := http.NewRequest("POST", t.url, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	for k, v := range t.headers {
		req.Header.Set(k, v)
	}
	resp, err := t.client.Do(req)
	if err != nil {
		return err
	}
	_ = resp.Body.Close()
	return nil
}
func (t *httpTransport) close() error { return nil }
