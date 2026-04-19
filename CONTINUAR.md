# CONTINUAR — Ponto de partida para novas sessões

> **Leia este arquivo primeiro sempre que abrir uma nova conversa.**
> Ele contém o estado atual do projeto e o próximo passo claro.

---

## O que é o Cérebro Rural (resumo de 30 segundos)

Plataforma SaaS de micro-apps independentes (Almoxarifado, Pastagem, Obras, Manejo de Gado, Calculadora de Boi, Funcionários, Aluguel, Vida Pessoal, Bolsa/FII) todos conectados a um **Cérebro Central** que consolida fluxo de caixa unificado e entrega relatório pronto pro contador. Cada app funciona sozinho offline e só depois sincroniza com o Cérebro através de um conector universal (tabela `lancamentos` no Supabase).

**Público alvo:** produtor rural brasileiro que tem múltiplos negócios (fazenda + imóvel + loja + investimentos).

**Autor:** Thiago Oliveira — Vitória da Conquista, Bahia.

---

## Princípios não-negociáveis

1. **Cada app nasce autônomo.** Nunca dependente de outro. Só conecta no Cérebro depois de passar nos 4 testes mínimos.
2. **Offline-first.** Fazenda não tem Wi-Fi — tudo funciona sem internet e sincroniza quando houver.
3. **Três formas de entrada de dados** em todo app: manual, importação (Excel/CSV/PDF), câmera/OCR.
4. **Camada de Integridade obrigatória.** Todo dado atravessa 5 checkpoints antes de gravar. Ver `INTEGRIDADE.md`.
5. **Conector universal.** Toda transação vira um registro em `lancamentos` com os mesmos campos obrigatórios.
6. **IA pergunta, nunca assume.** Se tem ambiguidade, pergunta. Se tem anomalia, alerta.
7. **Permissões por papel.** Peão vê o que precisa, não vê preços, não deleta.
8. **UI zerada.** Não reaproveitar nenhum componente visual de outros projetos do Thiago.

---

## Stack técnica confirmada

| Camada    | Tecnologia                           |
|-----------|--------------------------------------|
| Frontend  | React 18 + TypeScript + Vite         |
| UI        | Tailwind CSS + shadcn/ui             |
| Estado    | Zustand + React Query                |
| Banco     | Supabase (Postgres + Auth + Realtime)|
| IA        | Groq (Llama) + Claude Haiku          |
| Deploy    | Vercel (um projeto por micro-app)    |
| Offline   | IndexedDB + Service Worker (PWA)     |

---

## Estado atual do projeto

**Fase:** especificação e arquitetura.
**Código:** zero linhas escritas ainda (intencionalmente — só após toda a documentação fechar).
**Documentação:** completa pra Almoxarifado. Placeholders para os demais apps.

### O que já está documentado e no GitHub

```
cerebro-rural/
├── CONTINUAR.md              ← VOCÊ ESTÁ AQUI
├── README.md                 ← índice geral
├── IDEIA.md                  ← visão do produto e modelo SaaS
├── ARQUITETURA.md            ← stack, conector universal, IA
├── INTEGRIDADE.md            ← 5 checkpoints (pilar fundamental)
├── SCHEMA.md                 ← banco Supabase completo
├── ROADMAP.md                ← fases de construção
├── TESTES.md                 ← 8 testes mínimos por módulo
├── CAPTURA.md                ← WhatsApp, email, share sheet
├── DECISOES.md               ← log de decisões arquiteturais
├── IDEIAS_FUTURAS.md         ← parking lot de ideias novas
└── apps/
    ├── almoxarifado/         ← DETALHADO (escopo, schema, UI, conector)
    ├── calculadora-boi/      ← 3 modos documentados (compra, venda, conferência)
    ├── obras/                ← placeholder
    ├── manejo-gado/          ← placeholder
    ├── pastagem/             ← placeholder
    ├── funcionarios/         ← placeholder
    ├── aluguel/              ← placeholder
    ├── vida-pessoal/         ← placeholder
    ├── bolsa-fii/            ← placeholder
    └── cerebro/              ← o hub central — placeholder
```

---

## Plano por sessões — o que fazer em cada próxima conversa

### Sessão A — Fechamento da especificação (ainda sem código)
- [ ] Thiago revisa a documentação do Almoxarifado
- [ ] Ajusta escopo se necessário
- [ ] Aprova ou revisa a Camada de Integridade
- [ ] Decide o primeiro módulo a codar (recomendado: Almoxarifado)
- [ ] Define o nome comercial do produto (Cérebro Rural é codinome)

### Sessão B — Setup da fundação (primeiros commits de código)
- [ ] Criar projeto Supabase novo (anotar URL e anon key)
- [ ] Executar SQL do `SCHEMA.md` base (fazendas, users, lancamentos)
- [ ] Ativar RLS em todas as tabelas base
- [ ] Criar template de micro-app (Vite + TS + Tailwind + shadcn/ui + Supabase)
- [ ] Deploy "hello world" na Vercel pra validar pipeline
- [ ] Commitar template no repo como `apps/_template/`

### Sessão C — Almoxarifado: cadastros base
- [ ] Fork do template para `apps/almoxarifado/`
- [ ] Executar SQL do `apps/almoxarifado/SCHEMA.md` (itens, setores, fornecedores)
- [ ] Tela de cadastro de itens (CRUD básico)
- [ ] Tela de cadastro de setores
- [ ] Tela de cadastro de fornecedores
- [ ] Deploy na Vercel

### Sessão D — Almoxarifado: entrada de mercadoria
- [ ] Tela de nova entrada (formulário manual)
- [ ] Lista de entradas com filtro
- [ ] Trigger de atualização de saldo e custo médio
- [ ] Camada de Integridade — checkpoints 1 e 2 (formato e duplicata)
- [ ] Teste 1 da especificação

### Sessão E — Almoxarifado: saída de mercadoria
- [ ] Tela de retirada (formulário manual)
- [ ] Rastreamento por setor, retirante, liberador, motivo
- [ ] Trigger de baixa de saldo
- [ ] Camada de Integridade — checkpoint 5 (confirmação)
- [ ] Testes 2 e 3 da especificação

### Sessão F — Almoxarifado: importação de Excel
- [ ] Upload de arquivo .xlsx
- [ ] Mapeamento de colunas com IA (Claude Haiku)
- [ ] Preview antes de confirmar
- [ ] Lançamento em lote
- [ ] Teste 7 da especificação

### Sessão G — Almoxarifado: foto de nota fiscal
- [ ] Captura de imagem (câmera ou galeria)
- [ ] Extração via Claude Haiku com visão
- [ ] Confirmação do usuário
- [ ] Teste 8 da especificação

### Sessão H — Almoxarifado: offline e PWA
- [ ] Service worker
- [ ] IndexedDB para gravação local
- [ ] Lógica de sincronização
- [ ] Testes 5 e 6 da especificação

### Sessão I — Cérebro Central: dashboard básico
- [ ] Criar projeto `apps/cerebro/`
- [ ] Tela de fluxo de caixa (lê tabela `lancamentos`)
- [ ] Filtros por período, categoria, app origem
- [ ] Totalizadores por categoria

### Sessão J — Conectar Almoxarifado ao Cérebro
- [ ] Trigger no Supabase: entrada de mercadoria gera lançamento
- [ ] Trigger: saída gera lançamento com categoria por setor
- [ ] Teste 4 da especificação (IA responde perguntas)
- [ ] Almoxarifado oficialmente em produção

### Sessões K em diante — próximos apps
Ordem sugerida (reavaliar a cada sprint):
1. Pastagem (integra com Calculadora de Boi)
2. Calculadora de Boi (já existe, adaptar os 3 modos)
3. Manejo de Gado
4. Funcionários
5. Obras
6. Aluguel
7. Vida pessoal
8. Bolsa/FII

---

## Comandos rápidos pra nova sessão

Sempre que abrir conversa nova:

```
Oi Claude, continua o Cérebro Rural.
Lê o CONTINUAR.md do repo https://github.com/tportooliveira-alt/cerebro-rural
Estamos na sessão [X].
O que fazer hoje: [Y]
```

---

## Contatos técnicos do projeto

- **Repo:** `tportooliveira-alt/cerebro-rural`
- **Token do repo (Cérebro Rural — separado do FrigoGest):** está salvo na memória do Claude
- **Supabase:** a criar
- **Vercel team:** `team_Ep4JIAnlbXVQVFLpVjpcrCxb` (mesmo do FrigoGest — só o projeto é separado)

---

## Regras de ouro para qualquer Claude que continuar

1. **Nunca misture Cérebro Rural com FrigoGest.** São dois produtos separados.
2. **Não invente código antes de documentação estar fechada.** Se faltar especificação, pare e pergunte.
3. **Toda tabela nova precisa de RLS.** Sem exceção.
4. **Toda escrita precisa passar pela Camada de Integridade.** Ver `INTEGRIDADE.md`.
5. **Nunca quebre os princípios não-negociáveis** listados no topo deste arquivo.
6. **Consulte os docs antes de assumir algo.** Tudo que for relevante já está escrito.

---

*Última atualização: abril 2026.*
*Quando atualizar, colocar a data aqui em cima.*
