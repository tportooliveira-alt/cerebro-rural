// Package adapter — MCPAdapter expõe servidores MCP (Model Context Protocol)
// como Extensions. A comunicação usa JSON-RPC 2.0 sobre stdio, seguindo o
// protocolo oficial (initialize, tools/list, tools/call). Cada "tool" do
// servidor MCP vira uma Capability com action=<tool_name>.
package adapter

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

// MCPServerSpec descreve como iniciar um servidor MCP.
// Ex.: {Name:"filesystem", Command:"npx", Args:[]string{"-y","@modelcontextprotocol/server-filesystem","C:/tmp"}}
type MCPServerSpec struct {
	Name    string            `json:"name"`
	Command string            `json:"command"`
	Args    []string          `json:"args,omitempty"`
	Env     map[string]string `json:"env,omitempty"`
	Module  string            `json:"module,omitempty"` // default = Name
}

// MCPAdapter implementa Adapter para Kind="mcp". A Source.Location é ignorada;
// use Source.Config com "spec" contendo JSON de MCPServerSpec, OU registre a
// spec diretamente via NewMCPAdapterWithSpec.
type MCPAdapter struct{}

// NewMCPAdapter cria um adapter genérico; o Source.Config["spec"] deve trazer
// o JSON da MCPServerSpec.
func NewMCPAdapter() *MCPAdapter { return &MCPAdapter{} }

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

// StartMCP spawna o servidor MCP e faz o handshake initialize + tools/list.
func StartMCP(ctx context.Context, id string, spec MCPServerSpec) (*MCPExtension, error) {
	if spec.Command == "" {
		return nil, fmt.Errorf("mcp[%s]: command vazio", spec.Name)
	}
	if spec.Module == "" {
		spec.Module = spec.Name
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
	cmd.Stderr = io.Discard // silencia ruído; produção: redirecionar para logger

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("mcp[%s]: start: %w", spec.Name, err)
	}

	ext := &MCPExtension{
		id:      id,
		spec:    spec,
		cmd:     cmd,
		stdin:   stdin,
		stdout:  bufio.NewReaderSize(stdout, 1<<16),
		pending: map[int64]chan rpcResponse{},
	}
	go ext.readLoop()

	// handshake: initialize
	initCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	initRes, err := ext.call(initCtx, "initialize", map[string]any{
		"protocolVersion": "2024-11-05",
		"capabilities":    map[string]any{},
		"clientInfo":      map[string]any{"name": "cerebro-host", "version": "0.3.0"},
	})
	if err != nil {
		_ = ext.Close()
		return nil, fmt.Errorf("mcp[%s]: initialize: %w", spec.Name, err)
	}
	_ = initRes
	// notifica initialized (notificação, sem resposta)
	if err := ext.notify("notifications/initialized", nil); err != nil {
		_ = ext.Close()
		return nil, err
	}

	// tools/list
	toolsRes, err := ext.call(initCtx, "tools/list", map[string]any{})
	if err != nil {
		_ = ext.Close()
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
		_ = ext.Close()
		return nil, fmt.Errorf("mcp[%s]: parse tools: %w", spec.Name, err)
	}
	caps := make([]*extv1.Capability, 0, len(tl.Tools))
	for _, t := range tl.Tools {
		schema := string(t.InputSchema)
		if schema == "" || schema == "null" {
			schema = `{"type":"object"}`
		}
		desc := t.Description
		if desc != "" {
			// embute a descrição no schema_payload como $comment (schema continua válido)
			var obj map[string]any
			if json.Unmarshal([]byte(schema), &obj) == nil {
				if _, has := obj["$comment"]; !has {
					obj["$comment"] = desc
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

// ---------- MCPExtension ----------

type MCPExtension struct {
	id   string
	spec MCPServerSpec
	cmd  *exec.Cmd

	stdin  io.WriteCloser
	stdout *bufio.Reader
	writeM sync.Mutex

	nextID atomic.Int64

	mu      sync.Mutex
	pending map[int64]chan rpcResponse
	closed  bool

	capabilities []*extv1.Capability
}

func (e *MCPExtension) ID() string { return e.id }

func (e *MCPExtension) Close() error {
	e.mu.Lock()
	if e.closed {
		e.mu.Unlock()
		return nil
	}
	e.closed = true
	e.mu.Unlock()
	_ = e.stdin.Close()
	_ = e.cmd.Process.Kill()
	return nil
}

func (e *MCPExtension) Health(ctx context.Context) (*extv1.HealthResponse, error) {
	return &extv1.HealthResponse{Ok: true, Message: "mcp:" + e.spec.Name}, nil
}

func (e *MCPExtension) Version(ctx context.Context) (*extv1.VersionResponse, error) {
	return &extv1.VersionResponse{
		PluginId:      "mcp/" + e.spec.Name,
		PluginVersion: "mcp-1.0",
		ProtocolMajor: 1,
		ProtocolMinor: 0,
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
	res, err := e.call(ctx, "tools/call", map[string]any{
		"name":      cmd.Action,
		"arguments": args,
	})
	if err != nil {
		return &extv1.ExecuteResponse{Ok: false, Issues: []*extv1.Issue{{
			Severity: extv1.Issue_ERROR, Code: "MCP_ERROR", Message: err.Error(),
		}}}, nil
	}
	return &extv1.ExecuteResponse{Ok: true, ResultJson: string(res)}, nil
}

// ---------- JSON-RPC 2.0 stdio ----------

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

func (e *MCPExtension) call(ctx context.Context, method string, params any) (json.RawMessage, error) {
	id := e.nextID.Add(1)
	req := rpcRequest{JSONRPC: "2.0", ID: id, Method: method, Params: params}
	ch := make(chan rpcResponse, 1)
	e.mu.Lock()
	e.pending[id] = ch
	e.mu.Unlock()
	defer func() {
		e.mu.Lock()
		delete(e.pending, id)
		e.mu.Unlock()
	}()
	if err := e.writeJSON(req); err != nil {
		return nil, err
	}
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case resp := <-ch:
		if resp.Error != nil {
			return nil, fmt.Errorf("rpc error %d: %s", resp.Error.Code, resp.Error.Message)
		}
		return resp.Result, nil
	}
}

func (e *MCPExtension) notify(method string, params any) error {
	return e.writeJSON(rpcNotification{JSONRPC: "2.0", Method: method, Params: params})
}

func (e *MCPExtension) writeJSON(v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	b = append(b, '\n')
	e.writeM.Lock()
	defer e.writeM.Unlock()
	_, err = e.stdin.Write(b)
	return err
}

func (e *MCPExtension) readLoop() {
	for {
		line, err := e.stdout.ReadBytes('\n')
		if len(line) > 0 {
			line = []byte(strings.TrimRight(string(line), "\r\n"))
			if len(line) > 0 {
				var resp rpcResponse
				if jerr := json.Unmarshal(line, &resp); jerr == nil && resp.ID != nil {
					e.mu.Lock()
					ch, ok := e.pending[*resp.ID]
					e.mu.Unlock()
					if ok {
						select {
						case ch <- resp:
						default:
						}
					}
				}
				// notificações do servidor são ignoradas no MVP
			}
		}
		if err != nil {
			e.mu.Lock()
			for _, ch := range e.pending {
				close(ch)
			}
			e.pending = map[int64]chan rpcResponse{}
			e.mu.Unlock()
			return
		}
	}
}
