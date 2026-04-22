package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"

	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/adapter"
	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/integrity"
	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/mcpcfg"
	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/registry"
	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	var err error
	switch os.Args[1] {
	case "run":
		err = runCmd(os.Args[2:])
	case "mcp":
		err = mcpCmd(os.Args[2:])
	case "version":
		fmt.Println("cerebro-host v0.3.0 protocol 1.0")
		return
	default:
		usage()
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "erro:", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `uso:
  cerebro-host run --plugin PATH --tenant T --module M --action A [--payload JSON]
  cerebro-host mcp list [--config config/mcp.json]
  cerebro-host mcp call --server NAME --tool T --args JSON [--tenant T] [--config config/mcp.json]`)
}

func runCmd(args []string) error {
	fs := flag.NewFlagSet("run", flag.ExitOnError)
	pluginPath := fs.String("plugin", "", "caminho do plugin binário")
	tenant := fs.String("tenant", "", "tenant_id")
	module := fs.String("module", "", "módulo")
	action := fs.String("action", "", "ação")
	payload := fs.String("payload", "{}", "payload JSON")
	requestID := fs.String("request-id", "", "request_id fixo")
	auditPath := fs.String("audit", "", "arquivo de auditoria")
	timeout := fs.Duration("timeout", 5*time.Second, "timeout total")
	_ = fs.Parse(args)

	if *pluginPath == "" || *tenant == "" || *module == "" || *action == "" {
		fs.Usage()
		return fmt.Errorf("flags obrigatórias ausentes")
	}
	if !json.Valid([]byte(*payload)) {
		return fmt.Errorf("payload inválido")
	}

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	reg := registry.New(adapter.NewBinaryAdapter())
	defer reg.CloseAll()

	ext, err := reg.Load(ctx, adapter.Source{ID: "cli-plugin", Kind: "binary", Location: *pluginPath})
	if err != nil {
		return err
	}

	ver, _ := ext.Version(ctx)
	fmt.Printf("plugin: %s v%s  protocolo v%d.%d\n", ver.PluginId, ver.PluginVersion, ver.ProtocolMajor, ver.ProtocolMinor)

	var sink integrity.AuditSink = integrity.NewStdoutAudit()
	if *auditPath != "" {
		fsink, ferr := integrity.NewFileAudit(*auditPath)
		if ferr != nil {
			return fmt.Errorf("audit: %w", ferr)
		}
		sink = fsink
	}

	allow := integrity.NewStaticAllowlist()
	allow.Allow(*tenant, *module, *action)

	pipe := integrity.NewPipeline(
		[]integrity.Step{
			integrity.SchemaStep{},
			integrity.IdempotencyStep{Store: integrity.NewMemoryStore(), TTL: 24 * time.Hour},
			integrity.PermissionsStep{Provider: allow},
			integrity.NewCoherenceStep(),
		},
		integrity.WithAudit(sink),
	)

	reqID := *requestID
	if reqID == "" {
		reqID = uuid.NewString()
	}
	cmd := &extv1.Command{
		RequestId:   reqID,
		TenantId:    *tenant,
		Module:      *module,
		Action:      *action,
		PayloadJson: *payload,
		Meta:        map[string]string{"source": "cli", "ts": time.Now().UTC().Format(time.RFC3339)},
	}

	if err := pipe.Run(ctx, ext, cmd); err != nil {
		pipe.Commit(ctx, cmd, nil, err)
		return err
	}
	resp, err := ext.Execute(ctx, cmd)
	pipe.Commit(ctx, cmd, resp, err)
	if err != nil {
		return err
	}
	out, _ := json.MarshalIndent(resp, "", "  ")
	fmt.Println(string(out))
	return nil
}

// ---------- MCP ----------

func mcpCmd(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("uso: cerebro-host mcp <list|call> ...")
	}
	switch args[0] {
	case "list":
		return mcpList(args[1:])
	case "call":
		return mcpCall(args[1:])
	default:
		return fmt.Errorf("subcomando mcp desconhecido: %s", args[0])
	}
}

func mcpList(args []string) error {
	fs := flag.NewFlagSet("mcp list", flag.ExitOnError)
	cfgPath := fs.String("config", "config/mcp.json", "arquivo de servidores MCP")
	probe := fs.Bool("probe", false, "inicia cada servidor e lista as tools (exige npx/uvx instalados)")
	timeout := fs.Duration("timeout", 20*time.Second, "timeout por servidor no modo probe")
	_ = fs.Parse(args)

	cfg, err := mcpcfg.Load(*cfgPath)
	if err != nil {
		return err
	}
	fmt.Printf("%d servidores MCP configurados em %s:\n", len(cfg.Servers), *cfgPath)
	for _, s := range cfg.Servers {
		fmt.Printf("- %-22s module=%-12s cmd=%s %v\n", s.Name, s.Module, s.Command, s.Args)
		if !*probe {
			continue
		}
		ctx, cancel := context.WithTimeout(context.Background(), *timeout)
		ext, err := adapter.StartMCP(ctx, "probe-"+s.Name, s)
		cancel()
		if err != nil {
			fmt.Printf("    [probe falhou: %v]\n", err)
			continue
		}
		caps, _ := ext.Capabilities(context.Background())
		for _, c := range caps.Capabilities {
			fmt.Printf("    • %s.%s\n", c.Module, c.Action)
		}
		_ = ext.Close()
	}
	return nil
}

func mcpCall(args []string) error {
	fs := flag.NewFlagSet("mcp call", flag.ExitOnError)
	cfgPath := fs.String("config", "config/mcp.json", "arquivo de servidores MCP")
	server := fs.String("server", "", "nome do servidor MCP (do config)")
	tool := fs.String("tool", "", "nome da tool")
	argsJSON := fs.String("args", "{}", "arguments JSON para a tool")
	tenant := fs.String("tenant", "default", "tenant_id para auditoria")
	requestID := fs.String("request-id", "", "request_id fixo")
	auditPath := fs.String("audit", "", "arquivo de auditoria")
	timeout := fs.Duration("timeout", 30*time.Second, "timeout total")
	_ = fs.Parse(args)

	if *server == "" || *tool == "" {
		return fmt.Errorf("flags --server e --tool são obrigatórias")
	}
	if !json.Valid([]byte(*argsJSON)) {
		return fmt.Errorf("--args inválido, não é JSON")
	}

	cfg, err := mcpcfg.Load(*cfgPath)
	if err != nil {
		return err
	}
	var spec *adapter.MCPServerSpec
	for i := range cfg.Servers {
		if cfg.Servers[i].Name == *server {
			spec = &cfg.Servers[i]
			break
		}
	}
	if spec == nil {
		return fmt.Errorf("servidor %q não encontrado no config", *server)
	}
	if spec.Module == "" {
		spec.Module = spec.Name
	}

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	ext, err := adapter.StartMCP(ctx, "mcp-"+spec.Name, *spec)
	if err != nil {
		return err
	}
	defer ext.Close()

	var sink integrity.AuditSink = integrity.NewStdoutAudit()
	if *auditPath != "" {
		fsink, ferr := integrity.NewFileAudit(*auditPath)
		if ferr != nil {
			return fmt.Errorf("audit: %w", ferr)
		}
		sink = fsink
	}
	allow := integrity.NewStaticAllowlist()
	allow.Allow(*tenant, spec.Module, *tool)

	pipe := integrity.NewPipeline(
		[]integrity.Step{
			integrity.SchemaStep{},
			integrity.IdempotencyStep{Store: integrity.NewMemoryStore(), TTL: time.Hour},
			integrity.PermissionsStep{Provider: allow},
			integrity.NewCoherenceStep(),
		},
		integrity.WithAudit(sink),
	)

	reqID := *requestID
	if reqID == "" {
		reqID = uuid.NewString()
	}
	cmd := &extv1.Command{
		RequestId:   reqID,
		TenantId:    *tenant,
		Module:      spec.Module,
		Action:      *tool,
		PayloadJson: *argsJSON,
		Meta:        map[string]string{"source": "cli-mcp", "server": spec.Name},
	}

	if err := pipe.Run(ctx, ext, cmd); err != nil {
		pipe.Commit(ctx, cmd, nil, err)
		return err
	}
	resp, err := ext.Execute(ctx, cmd)
	pipe.Commit(ctx, cmd, resp, err)
	if err != nil {
		return err
	}
	out, _ := json.MarshalIndent(resp, "", "  ")
	fmt.Println(string(out))
	return nil
}
