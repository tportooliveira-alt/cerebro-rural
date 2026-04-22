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
	"github.com/tportooliveira-alt/cerebro-rural/plugins/host/registry"
	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	switch os.Args[1] {
	case "run":
		if err := runCmd(os.Args[2:]); err != nil {
			fmt.Fprintln(os.Stderr, "erro:", err)
			os.Exit(1)
		}
	case "version":
		fmt.Println("cerebro-host v0.2.0 protocol 1.0")
	default:
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "uso: cerebro-host run --plugin PATH --tenant T --module M --action A [--payload JSON] [--request-id ID] [--audit FILE]")
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
