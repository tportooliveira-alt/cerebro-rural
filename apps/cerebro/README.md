# Cérebro — Hub Central

> Não é um micro-app como os outros. É o consolidador.
> Lê a tabela `lancamentos` (alimentada por todos os micro-apps) e entrega inteligência.

---

## Responsabilidades

### 1. Fluxo de caixa unificado
- Dashboard único com todas as entradas e saídas de todos os apps
- Filtros por: período, categoria, subcategoria, app origem, setor
- Totalizadores em tempo real
- Gráficos de evolução

### 2. DRE mensal automático
- Receitas por categoria
- Custos por categoria
- Resultado operacional
- Resultado final

### 3. Relatório para o contador
- Exportação PDF com todos os lançamentos do mês
- Exportação Excel estruturada (colunas que o contador pode importar)
- Observações e justificativas de ajustes

### 4. IA conversacional
- Receba pergunta em texto ou voz
- Responda consultando os dados

Exemplos:
- "Quanto gastei com ração esse mês?"
- "Qual foi o lucro da última venda de gado?"
- "Meu caixa fica negativo em algum momento?"
- "Qual pasto teve mais gasto esse ano?"

### 5. Alertas inteligentes
- Saldo negativo previsto
- Estoque crítico
- Conta vencendo
- Aluguel atrasado
- Preço de arroba muito vantajoso pra venda

### 6. Agente Orquestrador
- Usa Claude Haiku (único lugar que gasta Claude pago)
- Decide qual agente especialista consultar
- Consolida a resposta

### 7. Agentes especialistas (Groq Llama — grátis)
- **Financeiro** — leitura de `lancamentos`
- **Produção** — pastagem + almoxarifado + gado
- **Patrimônio** — imóveis + obras + bolsa
- **Contador** — geração de relatórios estruturados

---

## Não é responsabilidade do Cérebro

- ❌ Cadastros (cada app tem o seu)
- ❌ Movimentações operacionais (só consolida, não gera)
- ❌ Lógica de negócio dos apps (cada app é dono)

**O Cérebro é 100% consumidor. Nunca produz.**

---

## Interface

### Dashboard principal
- Cards grandes: saldo atual, entradas do mês, saídas do mês, resultado
- Gráfico de fluxo de caixa (30 dias)
- Top 5 categorias de gasto
- Alertas ativos

### Página de fluxo de caixa
- Tabela paginada com todos os lançamentos
- Filtros laterais (período, categoria, app, setor)
- Exportação

### Página do Agente IA
- Chat simples por texto ou voz
- Histórico de perguntas
- Sugestões de perguntas frequentes

### Página de relatórios
- Botão "Gerar relatório do mês passado"
- Exportação PDF/Excel
- Compartilhar direto com contador (email ou link)

---

## Status

Em especificação. Será construído depois que pelo menos 2 micro-apps estiverem em produção alimentando a tabela `lancamentos`.

---

## Prototipo Interativo (local)

Foi adicionado um prototipo navegavel para validar UX e fluxo do hub central antes da fase de codigo oficial:

- Arquivo: `prototipo-dashboard.html`
- Como abrir: clique duas vezes no arquivo ou abra no navegador
- Objetivo: testar visual, navegacao por modulo, contribuicao no caixa e simulacoes de integracao

Esse prototipo nao substitui a implementacao oficial em React + Supabase. Ele serve para validar estrutura e conversa de produto com rapidez.
