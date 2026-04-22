# Cérebro Rural

> ERP de micro-apps interligados para o produtor rural brasileiro.
> Plataforma SaaS onde cada negócio do produtor (fazenda, obras, aluguéis, funcionários, investimentos) vira um app independente, e todos se conectam a um Cérebro Central com IA e fluxo de caixa unificado.

---

## Se você está abrindo o projeto pela primeira vez: leia [`CONTINUAR.md`](./CONTINUAR.md)

---

## Documentos principais

- [`CONTINUAR.md`](./CONTINUAR.md) — **leia primeiro** — ponto de partida para qualquer nova sessão
- [`IDEIA.md`](./IDEIA.md) — visão do produto, problema, solução, modelo de negócio
- [`ARQUITETURA.md`](./ARQUITETURA.md) — stack, conector universal, IA
- [`INTEGRIDADE.md`](./INTEGRIDADE.md) — **pilar fundamental** — 5 checkpoints obrigatórios
- [`CAPTURA.md`](./CAPTURA.md) — captura multi-plataforma (WhatsApp, email, share sheet)
- [`SCHEMA.md`](./SCHEMA.md) — banco Supabase compartilhado
- [`ROADMAP.md`](./ROADMAP.md) — fases e critérios de pronto
- [`TESTES.md`](./TESTES.md) — 8 testes mínimos por módulo
- [`ADAPTADOR_UNIVERSAL_GO_PLUGIN.md`](./ADAPTADOR_UNIVERSAL_GO_PLUGIN.md) — blueprint do adaptador universal multi-linguagem (go-plugin + gRPC)
- [`DECISOES.md`](./DECISOES.md) — log de decisões arquiteturais
- [`IDEIAS_FUTURAS.md`](./IDEIAS_FUTURAS.md) — parking lot de ideias

---

## Micro-apps documentados

### Pronto para codar
- [`apps/almoxarifado/`](./apps/almoxarifado/) — documentação completa (escopo, schema, conector)

### Especificação parcial
- [`apps/calculadora-boi/`](./apps/calculadora-boi/) — 3 modos definidos (compra, venda, conferência)
- [`apps/pastagem/`](./apps/pastagem/)
- [`apps/manejo-gado/`](./apps/manejo-gado/)
- [`apps/obras/`](./apps/obras/)
- [`apps/funcionarios/`](./apps/funcionarios/)
- [`apps/aluguel/`](./apps/aluguel/)
- [`apps/vida-pessoal/`](./apps/vida-pessoal/)
- [`apps/bolsa-fii/`](./apps/bolsa-fii/)

### Hub central
- [`apps/cerebro/`](./apps/cerebro/) — consolidador (construído por último)

---

## Filosofia em uma frase

**Cada app nasce completo e sozinho. Só depois conecta. E nenhum dado entra no banco sem passar pelos cinco checkpoints da Camada de Integridade.**

---

*Autor: Thiago Oliveira (tportooliveira-alt)*
*Vitória da Conquista, Bahia — Brasil*
*Abril 2026*
