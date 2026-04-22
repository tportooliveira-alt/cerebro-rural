# plugins/ — Adaptador Universal do Cerebro Rural

Implementação do blueprint definido em [`ADAPTADOR_UNIVERSAL_GO_PLUGIN.md`](../ADAPTADOR_UNIVERSAL_GO_PLUGIN.md).

## Estrutura

```
plugins/
├── proto/extension/v1/extension.proto   # contrato único (gRPC)
├── host/                                # core host (Go)
│   ├── cmd/cerebro-host/main.go         # CLI do host
│   ├── adapter/                         # BinaryAdapter, ScriptAdapter, RemoteAdapter
│   ├── registry/                        # descoberta e versionamento
│   ├── integrity/                       # pipeline de integridade (schema→audit)
│   └── transport/                       # go-plugin + gRPC glue
├── sdk/go/                              # helper para autores de plugin em Go
├── examples/hello/                      # plugin de referência
├── scripts/                             # build, proto gen, dev
├── buf.yaml / buf.gen.yaml              # geração dos stubs gRPC
└── go.mod
```

## Fases (do blueprint)

- **Fase 1** (atual): contrato + host mínimo + `hello` com handshake de versão.
- **Fase 2**: integridade + persistência real (Supabase).
- **Fase 3**: ScriptAdapter + RemoteAdapter + mTLS.
- **Fase 4**: produção controlada, telemetria, circuit breaker, capability allowlist por tenant.

## Build (a fazer após instalar Go 1.22+)

```powershell
cd plugins
go mod tidy
# gerar stubs (requer buf ou protoc)
./scripts/gen-proto.ps1
# compilar host e plugin hello
go build -o bin/cerebro-host.exe ./host/cmd/cerebro-host
go build -o bin/hello.exe ./examples/hello
# rodar
./bin/cerebro-host.exe run --plugin ./bin/hello.exe --tenant demo --module hello --action ping
```

## Contrato (resumo)

Todo plugin implementa `ExtensionService`:

- `Health` — probe de vida
- `Version` — devolve `protocol_major.minor` + versão do plugin
- `Capabilities` — lista módulos/ações suportados
- `Validate(Command)` — dry-run contra schema
- `Execute(Command)` — efeito real, sempre com `request_id` e `tenant_id`

Regra de compatibilidade: host aceita plugin se `protocol_major == host.major` e `plugin.minor <= host.minor`.
