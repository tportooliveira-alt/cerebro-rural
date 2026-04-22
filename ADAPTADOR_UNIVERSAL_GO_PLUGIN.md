# Adaptador Universal de Extensoes (Opcao 3)

> Estrategia escolhida: arquitetura multi-linguagem com isolamento de plugins usando `go-plugin` + `gRPC`.

---

## Objetivo

Permitir que o Cerebro Rural carregue e execute extensoes de tipos diferentes
(binario local, script, servico remoto) por meio de um contrato unico.

Cada extensao fica isolada do processo principal para reduzir risco de travamento,
conflito de dependencia e acoplamento entre micro-apps.

---

## Resultado esperado

1. Um host central carrega plugins em subprocesso.
2. Cada plugin implementa a mesma API canonica.
3. O host converte qualquer origem de extensao para o mesmo formato.
4. Fluxo de caixa, integridade e auditoria passam por um pipeline unico.

---

## Arquitetura base

### 1) Core Host (Go)

- Responsavel por descobrir, validar, iniciar e parar plugins.
- Nao executa regra de negocio especifica do dominio.
- Exige handshake de versao de protocolo antes de ativar plugin.

### 2) Runtime de Plugin (go-plugin + gRPC)

- Cada plugin roda em processo separado.
- Comunicacao host <-> plugin via gRPC.
- Suporte natural para plugin em outra linguagem desde que implemente o mesmo contrato gRPC.

### 3) Camada de Adaptadores

- `BinaryAdapter`: carrega plugin compilado localmente.
- `ScriptAdapter`: empacota script em processo controlado (com timeout e sandbox de IO).
- `RemoteAdapter`: conecta em endpoint remoto com autenticacao mTLS.

Todos adaptadores convertem para o contrato unico `ExtensionService`.

### 4) Camada de Integridade

Antes de persistir qualquer saida de plugin:

1. validacao de schema
2. validacao de idempotencia
3. validacao de regras de permissao
4. validacao de coerencia de dominio
5. confirmacao/auditoria

---

## Contrato unico (API canonica)

Todo plugin precisa responder ao mesmo conjunto minimo:

1. `Health()`
2. `Capabilities()`
3. `Execute(Command)`
4. `Validate(Command)`
5. `Version()`

### Exemplo de contrato (proto simplificado)

```proto
syntax = "proto3";

package extension.v1;

service ExtensionService {
  rpc Health(HealthRequest) returns (HealthResponse);
  rpc Capabilities(CapabilitiesRequest) returns (CapabilitiesResponse);
  rpc Validate(ValidateRequest) returns (ValidateResponse);
  rpc Execute(ExecuteRequest) returns (ExecuteResponse);
  rpc Version(VersionRequest) returns (VersionResponse);
}

message ExecuteRequest {
  string request_id = 1;
  string tenant_id = 2;
  string module = 3;
  string action = 4;
  bytes payload_json = 5;
}

message ExecuteResponse {
  bool ok = 1;
  bytes output_json = 2;
  repeated string warnings = 3;
  string error_code = 4;
}
```

---

## Regras de compatibilidade

1. Versao de protocolo obrigatoria (`protocol_major`, `protocol_minor`).
2. Host aceita apenas `protocol_major` igual.
3. `minor` maior no plugin pode ser aceito com degrade de recurso.
4. Toda mudanca breaking exige novo `major`.

---

## Seguranca minima (producao)

1. mTLS para plugin remoto.
2. Checksum/assinatura do binario antes de carregar.
3. Timeout por chamada e circuit breaker por plugin.
4. Limite de CPU/memoria por subprocesso.
5. Lista explicita de capacidades permitidas por tenant.

---

## Telemetria e operacao

1. Log estruturado por `request_id`, `tenant_id`, `plugin_id`.
2. Metricas por plugin: latencia p50/p95, erro, timeout, retries.
3. Evento de auditoria para toda execucao com payload resumido.
4. Estado de saude do plugin no painel do Cerebro.

---

## Plano de entrega (pratico)

### Fase 1 - Contrato e host minimo

- Definir proto final e gerar stubs.
- Criar host com discovery local e handshake de versao.
- Subir plugin de exemplo `hello` com `Health` e `Execute`.

### Fase 2 - Integridade e persistencia

- Conectar resposta do plugin ao pipeline de integridade.
- Persistir em tabela de eventos/auditoria.
- Implementar idempotencia por `request_id`.

### Fase 3 - Adaptadores multiplos

- Entregar `BinaryAdapter` e `RemoteAdapter`.
- Entregar `ScriptAdapter` com sandbox minimo.
- Painel de cadastro/ativacao por tenant.

### Fase 4 - Producao controlada

- Limites de recurso e mTLS.
- Canary por tenant.
- SLO e alertas por plugin.

---

## Criterios de aceite

1. Dois plugins de tecnologias diferentes ativos no mesmo host.
2. Queda de um plugin nao derruba o host.
3. Timeouts e retries funcionando com rastreio completo.
4. Toda execucao auditada e rastreavel de ponta a ponta.
5. Zero escrita no caixa sem passar pela integridade.

---

## Decisao arquitetural

Esta estrategia vira padrao para extensibilidade do Cerebro Rural quando houver
necessidade de integrar novas capacidades sem acoplar direto ao codigo do host.
