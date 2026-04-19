# Arquitetura — Cérebro Rural

## Visão geral

Arquitetura de **micro-apps satélites** conectados a um **Cérebro Central** via conector universal.

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Pastagem   │  │ Almoxarifado│  │    Obras    │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
                  (conector universal)
                        │
                ┌───────▼────────┐
                │    CÉREBRO     │
                │  IA + Fluxo    │
                └────────────────┘
```

---

## Stack técnica

| Camada     | Tecnologia                          |
|------------|-------------------------------------|
| Frontend   | React 18 + TypeScript + Vite        |
| UI         | Tailwind CSS + shadcn/ui            |
| Estado     | Zustand (local) + React Query (remoto) |
| Banco      | Supabase (Postgres + Auth + Realtime) |
| IA         | Groq (Llama 3.1) + Claude Haiku (orquestrador) |
| Deploy     | Vercel (cada app = projeto Vercel)  |
| Offline    | IndexedDB + Service Worker (PWA)    |
| Mobile     | PWA instalável (sem React Native na v1) |

### Por que essa stack
- **Supabase** centraliza banco + auth + realtime em um só lugar (menos infra pra gerir)
- **Vercel** é o deploy que o Thiago já domina (FrigoGest, Calculadora de Boi)
- **Groq** é gratuito/barato para os agentes de campo (classificação, parse)
- **Claude Haiku** só no orquestrador central (onde precisa de decisão real)

---

## Conector universal

Toda transação de qualquer micro-app grava em **uma única tabela** no Supabase: `lancamentos`.

### Campos obrigatórios

```sql
id              uuid PK
fazenda_id      uuid FK
app_origem      text   -- 'almoxarifado' | 'pastagem' | 'obras' | ...
categoria       text   -- 'Custo Produção' | 'Receita' | 'Custo Fixo' | 'Capital' | 'Pessoal'
subcategoria    text   -- livre, controlada por app
tipo            text   -- 'ENTRADA' | 'SAIDA' | 'TRANSFERENCIA'
valor           numeric(12,2)
data            timestamp
descricao       text
responsavel     uuid FK (users)
status          text   -- 'confirmado' | 'pendente' | 'cancelado'
referencia_id   uuid   -- id do registro no app de origem
referencia_tipo text   -- tipo do registro no app de origem
criado_em       timestamp
atualizado_em   timestamp
```

### Regra de ouro
**Nenhum micro-app exibe fluxo de caixa próprio.** Todos mostram apenas a visão do seu domínio (ex: almoxarifado mostra saldo de itens). O financeiro consolidado é responsabilidade exclusiva do Cérebro.

---

## Isolamento entre apps

- Cada micro-app tem seu **próprio projeto Vercel** e **URL própria** (ex: `almox.cerebrorural.com.br`)
- Cada app tem suas **próprias tabelas** no Supabase (ex: `almox_itens`, `almox_movimentos`)
- A **única tabela compartilhada** é `lancamentos` (o conector)
- Autenticação compartilhada via Supabase Auth (mesmo login funciona em todos os apps)

---

## Formas de entrada de dados

Cada app deve suportar as três:

### 1. Digitação manual
- Formulário simples, um campo por vez
- Funciona offline (IndexedDB)
- Sincroniza quando houver conexão

### 2. Importação de arquivo
- **Excel (.xlsx)** via SheetJS
- **CSV** nativo
- **Google Sheets** via exportação CSV
- **PDF** de notas fiscais via Claude Haiku (extração estruturada)

Fluxo: usuário faz upload → IA mapeia colunas pro schema do app → mostra preview → usuário confirma → lança.

### 3. OCR por câmera
- Foto de nota fiscal / cupom / boleto
- Claude Haiku com visão extrai: fornecedor, valor, data, itens
- Lança automaticamente após confirmação

---

## Inteligência do Cérebro

### Agente Orquestrador (Claude Haiku)
- Recebe pergunta do produtor (voz ou texto)
- Decide qual agente especialista consultar
- Consolida resposta

### Agentes especialistas (Groq Llama)
- **Financeiro** — leitura da tabela `lancamentos`, DRE, projeções
- **Produção** — dados de pastagem + gado + almoxarifado
- **Patrimônio** — imóveis, obras, ativos
- **Relatório Contador** — geração de PDF/Excel mensal

### Exemplos de perguntas que o Cérebro responde
- "Quanto gastei com ração esse mês?"
- "Qual foi o lucro da última venda de gado?"
- "Meu caixa fecha em agosto?"
- "Tem algum pasto superlotado?"
- "Qual funcionário está com adiantamento pendente?"

---

## Segurança

- **RLS (Row Level Security) no Supabase** — cada produtor só vê os dados da sua fazenda
- **fazenda_id** obrigatório em toda tabela
- **JWT** do Supabase Auth em toda requisição
- **Nunca** armazenar tokens, senhas ou dados financeiros sensíveis em localStorage sem criptografia

---

## Escalabilidade por módulo

A vantagem da arquitetura de micro-apps: cada módulo pode evoluir no seu próprio ritmo sem afetar os outros. Se o módulo de Obras precisa de uma reescrita, os outros 8 continuam funcionando normalmente.
