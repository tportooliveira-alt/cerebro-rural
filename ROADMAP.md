# Roadmap — Cérebro Rural

## Filosofia

**Cada app nasce completo e autônomo antes de conectar.**
Funciona offline, passa em todos os testes, está em produção — só depois entra o conector pro Cérebro.

---

## Fase 0 — Fundação (antes de qualquer app)

- [ ] Repo GitHub criado (`cerebro-rural`) ✅
- [ ] Projeto Supabase criado
- [ ] Schema universal aplicado (tabela `lancamentos`, `fazendas`, `users`)
- [ ] RLS ativado em todas as tabelas base
- [ ] Design system compartilhado (Tailwind config + shadcn/ui)
- [ ] Template de micro-app (boilerplate Vite + TS + Supabase)

---

## Fase 1 — Apps autônomos (em paralelo, sem conector ainda)

### 1.1 Almoxarifado (primeiro — mais simples)
- [ ] CRUD de itens
- [ ] Movimentação (entrada/saída/ajuste)
- [ ] Saldo em tempo real
- [ ] Três formas de entrada: manual, Excel, foto de nota
- [ ] Offline + sync
- [ ] Passa nos 4 testes mínimos

### 1.2 Pastagem
- [ ] CRUD de pastos
- [ ] Mapa Google com desenho de polígono
- [ ] Cálculo de UA e lotação
- [ ] Movimentação de lotes
- [ ] Histórico de pastejo
- [ ] Offline + sync

### 1.3 Calculadora de Boi (já existe — consolidar)
- [ ] Revisar código atual
- [ ] Garantir que passa nos 4 testes
- [ ] Alinhar com design system novo

### 1.4 Obras
- [ ] CRUD de obras
- [ ] Etapas e medições
- [ ] Controle de fornecedores
- [ ] Galeria de fotos de progresso

### 1.5 Funcionários
- [ ] CRUD de funcionários
- [ ] Folha mensal
- [ ] Adiantamentos
- [ ] Ponto simples

### 1.6 Aluguel
- [ ] CRUD de imóveis
- [ ] Contratos
- [ ] Controle de recebimentos
- [ ] Alerta de vencimento

---

## Fase 2 — Cérebro Central

- [ ] Dashboard de fluxo de caixa (lê tabela `lancamentos`)
- [ ] Filtros por período, categoria, app origem
- [ ] DRE mensal automático
- [ ] Exportação PDF para contador
- [ ] Agente orquestrador (Claude Haiku)
- [ ] Agentes especialistas (Groq Llama)
- [ ] Interface por voz (PWA com Web Speech API)

---

## Fase 3 — Conectores automáticos

Para cada app, implementar trigger que gera lançamento em `lancamentos` automaticamente:

- [ ] Almoxarifado → saída vira SAIDA categoria "Custo Produção"
- [ ] Obras → medição vira SAIDA categoria "Capital"
- [ ] Funcionários → folha vira SAIDA categoria "Custo Fixo"
- [ ] Aluguel → recebimento vira ENTRADA categoria "Receita Patrimônio"
- [ ] Calculadora de Boi → venda vira ENTRADA categoria "Receita Produção"

---

## Fase 4 — Módulos complementares

- [ ] Vida pessoal (Uber, boletos, compras)
- [ ] Bolsa / FII
- [ ] Loja / Comércio
- [ ] FrigoGest (integração com sistema existente)

---

## Fase 5 — Produto SaaS

- [ ] Onboarding com importação de Excel histórico
- [ ] Sistema de billing
- [ ] Planos (base + módulos adicionais)
- [ ] Landing page
- [ ] Primeiros clientes pagantes

---

## Critérios de "pronto" por app

Um app só está pronto quando:

1. ✅ CRUD completo funciona online
2. ✅ Funciona offline e sincroniza corretamente
3. ✅ Tem pelo menos 2 formas de entrada de dados (manual + importação)
4. ✅ Passa nos 4 testes mínimos (ver `TESTES.md`)
5. ✅ Está em produção na Vercel
6. ✅ Tem ao menos 1 usuário real testando por 1 semana
