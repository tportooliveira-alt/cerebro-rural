# Plano de Ação — o que falta implantar em todo o projeto

> Documento vivo. Atualizar status (▢/◐/✓) toda vez que avançar.
> Cada item é executável: nome do arquivo, biblioteca, critério de "feito".
> Última revisão: 2026-04-23

---

## Sumário do estado atual

| Camada | Status | Obs |
|---|---|---|
| Adaptador universal Go (gRPC plugin host) | ✓ pronto | `cerebro-host run/mcp/agent/orq` |
| Pipeline integridade (5 etapas) | ✓ pronto | sink ainda em stdout/file |
| Plugin `hello` (referência) | ✓ pronto | binário em `plugins/bin/hello.exe` |
| Plugin `docs` (xlsx/csv/pdf/json) | ✓ pronto | testado com `livro.xlsx` 13 abas |
| 6 MCPs ativos (filesystem/memory/fetch/time/think/everything) | ✓ pronto | 4 esperando credencial |
| 5 agentes LLM + orquestrador | ✓ pronto | só CLI |
| Protótipos de UI (v2 desktop / v3 universal / mobile) | ✓ pronto | HTML estático |
| Schema Supabase (`lancamentos`, `fazendas`, `users`, `auditoria`) | ▢ não existe | bloqueador #1 |
| Frontend React real (qualquer app) | ▢ não existe | bloqueador #2 |
| HTTP API do host | ▢ não existe | bloqueador #3 |
| 10 apps em `apps/` | ▢ só specs | nenhum código |

**Bloqueio crítico:** sem Supabase + sem HTTP do host + sem template Vite, nenhum app pode começar.

---

## FASE 0 — Fundação (5-7 dias úteis)

Tudo que destrava o resto. **Não pular.**

### 0.1 Supabase
- [ ] Criar projeto Supabase (free tier)
- [ ] Criar arquivo `supabase/migrations/0001_init.sql` com:
  - `fazendas` (id, nome, dono_user_id, criado_em)
  - `users` (Supabase Auth, perfil em `profiles`)
  - `lancamentos` (todos os campos do `SCHEMA.md`)
  - `auditoria` (request_id, tenant_id, module, action, event, payload_resumido, ts)
- [ ] Ativar RLS em **todas** as tabelas (filtro por `auth.uid()` → `dono_user_id`)
- [ ] Criar usuário de teste (você mesmo)
- [ ] Importar 50 lançamentos manuais de teste pra ter o que mostrar
- **Feito quando:** consegue rodar `select * from lancamentos` no painel Supabase com seu usuário.

### 0.2 Sink Supabase no host
- [ ] Adicionar `SupabaseAudit` em [plugins/host/integrity/audit.go](plugins/host/integrity/audit.go) (mesma interface de `StdoutAudit`)
- [ ] Aceitar URL `supabase://...` no flag `--audit` em [plugins/host/cmd/cerebro-host/main.go](plugins/host/cmd/cerebro-host/main.go)
- [ ] Conectar via `pgx` (lib oficial Postgres Go)
- **Feito quando:** `cerebro-host run ... --audit supabase://...` grava 1 linha em `auditoria` no Supabase.

### 0.3 HTTP wrapper do host
- [ ] Criar [plugins/host/cmd/cerebro-host/serve.go](plugins/host/cmd/cerebro-host/serve.go) com `cerebro-host serve --port 7373`
- [ ] Rotas mínimas:
  - `POST /api/run` → executa plugin binário (corpo: plugin/module/action/payload)
  - `POST /api/import` → recebe arquivo multipart, chama plugin `docs.read`, devolve linhas
  - `POST /api/agent/chat` → encaminha pra `agentChat`
  - `POST /api/orq/run` → encaminha pra `orqCmd`
  - `GET /api/health` → status engine + MCPs ativos
- [ ] CORS pra `localhost:5173` (Vite dev)
- [ ] Auth header `Authorization: Bearer <jwt-supabase>` validado contra Supabase Auth
- **Feito quando:** `curl -X POST localhost:7373/api/import -F file=@livro.xlsx` devolve as 13 abas.

### 0.4 Template de app web
- [ ] Criar [apps/_template/](apps/_template/) com:
  - Vite + React + TypeScript + Tailwind + shadcn/ui
  - Cliente Supabase (`@supabase/supabase-js`) com tipos auto-gerados
  - Cliente HTTP do host (`apiClient.ts`)
  - Hook `useAuth`, `useTenant`, `useLancamentos`
  - Service worker (vite-plugin-pwa) com offline IndexedDB
  - Tema dark/verde do protótipo v2
- [ ] Documentar `apps/_template/README.md` com `npm run new app-x`
- **Feito quando:** `cd apps/_template && npm run dev` abre tela de login Supabase.

### 0.5 Design system compartilhado
- [ ] Criar [apps/_shared/](apps/_shared/) (workspace npm) com:
  - Design tokens (cores do v2: `bg`, `panel`, `accent`, etc)
  - Componentes base: `<KPI>`, `<DataTable>`, `<ImportZone>`, `<Chat>`, `<AlertCard>`, `<Sidebar>`
  - Hooks compartilhados (`useDocsImport`, `useAgentChat`)
- **Feito quando:** outro app importa `<KPI>` do `_shared` sem copiar código.

---

## FASE 1 — Cérebro Central (1ª semana após Fase 0)

Hub que une tudo. Sem ele, os apps são ilhas.

### apps/cerebro/ — implementar telas reais

- [ ] **Tela 1 — Visão geral** (referência: [prototipo-v2.html](apps/cerebro/prototipo-v2.html))
  - 4 KPIs (saldo, entradas, saídas, margem) lendo `lancamentos`
  - Gráfico fluxo 90 dias (Recharts)
  - Breakdown por categoria (barras)
  - Bloco engine: pipeline + plugins + MCPs (consome `/api/health`)
  - Bloco auditoria: últimos 10 eventos (consome `auditoria` table)
  - Alertas (3 mocks no início)
- [ ] **Tela 2 — Caixa detalhado**
  - Tabela `<DataTable>` filtrada (período, app origem, categoria, status)
  - Edição inline + delete (passa por `/api/run` no módulo correspondente)
  - Exportar CSV (papaparse) + PDF (jspdf)
- [ ] **Tela 3 — DRE mensal**
  - Agrupa `lancamentos` por categoria contábil (regras hardcoded na v1)
  - Botão "exportar pro contador" → PDF formatado
- [ ] **Tela 4 — Conversar com IA**
  - Chat persistido em `chats` table
  - Chama `/api/agent/chat` com agente `dba` por padrão
  - Fallback para orquestrador se pergunta complexa
- [ ] **Tela 5 — Importar planilha/PDF**
  - `<ImportZone>` (drag-drop) → `/api/import`
  - Pré-classificação editável antes de confirmar (referência v2)
  - Bulk insert em `lancamentos` ao confirmar
- **Feito quando:** você usa o painel pra fechar 1 mês completo sem mexer em planilha externa.

---

## FASE 2 — Apps de domínio (5-6 meses, em ondas)

Cada app segue o mesmo critério: CRUD + 3 entradas (manual/import/foto) + conector que escreve em `lancamentos` + offline + 4 testes mínimos do `TESTES.md`.

### Onda 1 — Mês 2 (você usa de verdade)

#### apps/almoxarifado/ ▢
- [ ] Schema: `itens` (id, nome, unidade, custo_medio, saldo, setor)
- [ ] Schema: `movimentacoes` (id, item_id, tipo[entrada/saida/ajuste], qty, valor_unit, data, responsavel)
- [ ] Telas: Itens (lista + form), Movimentações (lista + form), Saldo por setor
- [ ] Conector: SAÍDA em `movimentacoes` → `lancamentos.SAIDA` categoria "Custo Produção"
- [ ] Importação Excel (planilha de inventário)
- [ ] Foto de nota → plugin `docs.ocr` (na onda 4)
- [ ] **Test:** lança saída de 5 sacos sal → vê em `lancamentos` no Cérebro

#### apps/aluguel/ ▢
- [ ] Schema: `imoveis` (id, endereco, tipo, valor_aluguel)
- [ ] Schema: `contratos` (id, imovel_id, inquilino, dia_venc, ativo)
- [ ] Schema: `recebimentos` (id, contrato_id, mes_ref, valor, data_pago, status)
- [ ] Telas: Imóveis, Contratos, Recebimentos, Alertas vencimento
- [ ] Conector: recebimento confirmado → `lancamentos.ENTRADA` categoria "Receita Patrimônio"
- [ ] Cron diário gerando recebimento "pendente" 5 dias antes do vencimento
- [ ] **Test:** vencimento amanhã → notificação push + alerta no Cérebro

### Onda 2 — Mês 3

#### apps/calculadora-boi/ ◐ (PWA já existe)
- [ ] Migrar PWA atual pro template `apps/_template`
- [ ] Adicionar conector que escreve venda em `lancamentos.ENTRADA` categoria "Receita Produção"
- [ ] Sincronizar histórico de pesagens com Supabase
- [ ] **Test:** registra venda 40 cabeças → entra como ENTRADA correta

#### apps/manejo-gado/ ▢
- [ ] Schema: `lotes`, `animais`, `movimentacoes_lote`, `vacinacoes`, `pesagens`
- [ ] Telas: Lotes, Animais, Movimentação, Calendário sanitário
- [ ] Conector: vacina aplicada → `lancamentos.SAIDA` categoria "Custo Produção · Sanidade"
- [ ] Export ficha do animal (PDF) pro veterinário
- [ ] **Test:** registra vacinação lote inteiro → 1 lançamento com qty correta

### Onda 3 — Mês 4

#### apps/obras/ ▢
- [ ] Schema: `obras`, `etapas`, `medicoes`, `fornecedores`, `fotos`
- [ ] Telas: Obras, Etapas (timeline), Medições, Galeria
- [ ] Upload de fotos → Supabase Storage
- [ ] Conector: medição aprovada → `lancamentos.SAIDA` categoria "Capital"
- [ ] **Test:** aprova medição R$ 5k → vira lançamento + foto fica acessível

#### apps/funcionarios/ ▢
- [ ] Schema: `funcionarios`, `folha_mensal`, `adiantamentos`, `ponto`
- [ ] Telas: Cadastro, Folha (mês corrente), Adiantamento rápido
- [ ] Conector: folha fechada → 1 lançamento por funcionário em "Custo Fixo"
- [ ] Cálculo simples de encargos (INSS rural / FGTS opcional)
- [ ] **Test:** fecha folha 5 funcionários → 5 lançamentos somam corretamente

### Onda 4 — Mês 5

#### apps/pastagem/ ▢
- [ ] Schema: `pastos` (id, nome, hectares, capacidade_ua), `pastejos` (lote_id, pasto_id, entrada, saida)
- [ ] Telas: Pastos, Mapa Google (desenho de polígono — leaflet ou Google Maps), Cálculo UA, Movimentação
- [ ] **Sem conector financeiro** (pastagem não gera lançamento direto, só relatório)
- [ ] **Test:** desenha polígono → calcula hectares → mostra UA atual

#### Plugin docs OCR — adicionar ação `docs.ocr`
- [ ] Estender [plugins/examples/docs/main.go](plugins/examples/docs/main.go) com `ocr` para imagens
- [ ] Usar Tesseract via [otiai10/gosseract](https://github.com/otiai10/gosseract) OU API gratuita (Google Vision free tier)
- [ ] Schema retorno: `{text, fields:{valor, data, fornecedor, cnpj}}` quando detectar nota fiscal
- [ ] **Test:** foto de cupom Outback → extrai R$ 142 + Outback + 23/04

### Onda 5 — Mês 6

#### apps/vida-pessoal/ ▢
- [ ] Schema: `gastos_pessoais` (categoria_padrao: Uber/Mercado/Lazer/...)
- [ ] Telas: Lançamento rápido (1-tap), Resumo mensal, Comparativo
- [ ] Conector: SAIDA pessoal → `lancamentos` com categoria "Pessoal"
- [ ] **Test:** lança 5 Uber em 1 dia → some no DRE como categoria isolada

#### apps/bolsa-fii/ ▢
- [ ] Schema: `posicoes` (ticker, qty, custo_medio), `proventos` (ticker, data, valor, tipo[dividendo/jcp/aluguel])
- [ ] Telas: Posição, Proventos (calendário), Aportes
- [ ] **V1 manual** (digitar aportes/proventos)
- [ ] **V2 (depois):** integração com B3 ou broker via API
- [ ] Conector: provento → `lancamentos.ENTRADA` categoria "Receita Investimento"
- [ ] **Test:** lança dividendo R$ 200 BBAS3 → entra no caixa do mês

---

## FASE 3 — Mobile (PWA empresário, paralelo Mês 4-6)

Referência: [prototipo-mobile.html](apps/cerebro/prototipo-mobile.html). Reusa MESMO frontend dos apps (PWA mobile-first).

- [ ] Configurar `vite-plugin-pwa` em todos os apps (manifest + service worker)
- [ ] Validar instalação na home iOS + Android
- [ ] Push notifications (Firebase Cloud Messaging ou Web Push API)
- [ ] Câmera nativa via `<input type="file" accept="image/*" capture>` → `/api/import`
- [ ] Voz: `webkitSpeechRecognition` → manda transcrição pro `/api/agent/chat`
- [ ] Modo offline real (CRUD em IndexedDB → fila de sync ao voltar conexão)
- [ ] Bottom nav com FAB grande pra novo lançamento (referência mobile)
- **Feito quando:** instala como app no iPhone, lança 5 despesas em modo avião, conecta no WiFi e sincroniza tudo.

---

## FASE 4 — Endurecimento (Mês 6-7, antes de cobrar)

### Multi-tenant
- [ ] Toda query Supabase com filtro RLS por `tenant_id`
- [ ] Convidar usuário (sócio/funcionário) com papel
- [ ] Permissão por papel: `dono` (tudo), `gerente` (lê tudo, escreve), `peão` (lê e escreve só do app dele)

### Billing (Stripe ou Pagar.me)
- [ ] Tabela `assinaturas` (user_id, plano, status, vencimento)
- [ ] Webhook Stripe atualiza `assinaturas`
- [ ] Middleware no host bloqueia ações se `status != active`
- [ ] Trial 14 dias automático no signup

### Observabilidade
- [ ] Logs estruturados (já existem) → enviar pra Logflare ou Axiom (free tier)
- [ ] Métricas por plugin (latência, erros) → Grafana Cloud free
- [ ] Alerta "engine down" no email do Thiago

### Segurança mínima
- [ ] mTLS para futuro `RemoteAdapter` (esqueletado, ainda não usado)
- [ ] Capability allowlist por tenant (já existe `StaticAllowlist`, ligar no host HTTP)
- [ ] Rate limit por tenant em `/api/*`
- [ ] LGPD: tela de export/delete de dados do usuário

### Landing + onboarding
- [ ] Landing 1 página em `apps/landing/` (Next.js + Vercel)
- [ ] Vídeo 2 min do Thiago usando o produto
- [ ] Calendly pra "demo de 30 min" (gratuita)

---

## FASE 5 — Crescimento (depois de R$ 1k MRR)

Só priorizar QUANDO tiver receita.

- [ ] WhatsApp bot (Z-API ou Twilio) → peão lança despesa por mensagem → IA classifica → `lancamentos`
- [ ] Bot Telegram (segundo canal)
- [ ] Comparador anonimizado de preços entre fazendas (precisa >50 ativas)
- [ ] Marketplace de insumos (precisa >100 ativas)
- [ ] Portal do contador (white-label simples)
- [ ] Integração NF-e XML (valor enorme, custo baixo)
- [ ] Módulos extras: reprodução, sanidade, máquinas, clima, carbono

---

## Dependências críticas (ordem obrigatória)

```
Fase 0.1 Supabase  ─┐
Fase 0.2 Sink      ─┤
Fase 0.3 HTTP host ─┴──→ Fase 0.4 Template ──→ Fase 1 Cérebro ──→ Fase 2 Apps
                                                    │
                                                    └──→ Fase 3 Mobile (paralelo)
                                                              │
                                                              └──→ Fase 4 Endurecimento ──→ Fase 5 Vendas
```

**Não comece nenhum app de domínio antes da Fase 1.** Você vai retrabalhar tudo.

---

## Estimativa rough (1 dev part-time, ~15h/semana)

| Fase | Esforço |
|---|---|
| Fase 0 (fundação) | 2-3 semanas |
| Fase 1 (Cérebro) | 3-4 semanas |
| Onda 1 (almoxarifado + aluguel) | 4 semanas |
| Onda 2 (calc-boi + manejo) | 4 semanas |
| Onda 3 (obras + funcionários) | 4 semanas |
| Onda 4 (pastagem + OCR) | 3 semanas |
| Onda 5 (vida-pessoal + FII) | 2 semanas |
| Mobile (paralelo) | + 3 semanas |
| Fase 4 (endurecimento) | 4 semanas |
| **Total até "pronto pra vender"** | **~7 meses** |

---

## Critério único de "pronto pra cobrar do primeiro cliente"

✅ Você usa 90 dias seguidos sem mexer em planilha externa.
✅ Você fecha seu próprio mês sem corrigir nada manualmente no Supabase.
✅ Pelo menos 1 conhecido testa por 30 dias e relata `>5/10` de satisfação.
✅ Multi-tenant + RLS + billing funcionando.
✅ Landing no ar com vídeo seu.

Quando todos os 5 baterem, abre cobrança nos 5 conhecidos pelo plano cheio (sem desconto).
