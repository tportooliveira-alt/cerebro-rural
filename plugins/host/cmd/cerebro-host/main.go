// cerebro-host — CLI mínima que carrega um plugin binário e executa um Command.
// Uso:
//   cerebro-host run --plugin ./bin/hello.exe --tenant demo --module hello \
//                    --action ping --payload '{"name":"mundo"}'
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
		fmt.Println("cerebro-host v0.1.0 protocol 1.0")
	default:
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "uso: cerebro-host run --plugin PATH --tenant T --module M --action A [--payload JSON]")
}

func runCmd(args []string) error {
	fs := flag.NewFlagSet("run", flag.ExitOnError)
	pluginPath := fs.String("plugin", "", "caminho do plugin binário")
	tenant := fs.String("tenant", "", "tenant_id")
	module := fs.String("module", "", "módulo")
	action := fs.String("action", "", "ação")
	payload := fs.String("payload", "{}", "payload JSON")
	timeout := fs.Duration("timeout", 5*time.Second, "timeout total")
	_ = fs.Parse(args)

	if *pluginPath == "" || *tenant == "" || *module == "" || *action == "" {
		fs.Usage()
		return fmt.Errorf("flags obrigatórias ausentes")
	}
	if !json.Valid([]byte(*payload)) {
		return fmt.Errorf("payload inválido, não é JSON")
	}

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	reg := registry.New(adapter.NewBinaryAdapter())
	defer reg.CloseAll()

	src := adapter.Source{
		ID:       "cli-plugin",
		Kind:     "binary",
		Location: *pluginPath,
	}
	ext, err := reg.Load(ctx, src)
	if err != nil {
		return err
	}

	ver, _ := ext.Version(ctx)
	fmt.Printf("plugin: %s v%s  protocolo v%d.%d\n",
		ver.PluginId, ver.PluginVersion, ver.ProtocolMajor, ver.ProtocolMinor)

	cmd := &extv1.Command{
		RequestId:   uuid.NewString(),
		TenantId:    *tenant,
		Module:      *module,
		Action:      *action,
		PayloadJson: *payload,
		Meta:        map[string]string{"source": "cli", "ts": time.Now().UTC().Format(time.RFC3339)},
	}

	pipe := integrity.NewPipeline() // fase 1: pipeline vazio + Validate do plugin
	if err := pipe.Run(ctx, ext, cmd); err != nil {
		return err
	}

	resp, err := ext.Execute(ctx, cmd)
	if err != nil {
		return err
	}
	out, _ := json.MarshalIndent(resp, "", "  ")
	fmt.Println(string(out))
	return nil
}
