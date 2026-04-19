# Calculadora de Boi — Cérebro Rural

> App independente de pesagem de gado. Já existe em produção ([repo](https://github.com/tportooliveira-alt/calculadora-de-boi-)), precisa ser consolidado e conectado.

---

## Diferencial: a decisão é feita dentro do app

A Calculadora não é só uma balança que envia peso. Ela tem lógica própria:
**antes de sincronizar**, o usuário escolhe qual foi o propósito da pesagem.

### Três modos de pesagem

#### 1. Compra de gado
- Registra: peso total, preço da @, valor total pago, fornecedor
- **Gera no Cérebro:** SAIDA categoria `'Compra de Gado'` (ou 'Conta a Pagar' se for a prazo)
- **Gera no Manejo de Gado:** novo lote de animais com custo de aquisição

#### 2. Venda de gado
- Registra: peso total, preço da @, valor total recebido, comprador
- **Gera no Cérebro:** ENTRADA categoria `'Receita de Produção'`
- **Gera no Manejo de Gado:** baixa dos animais do lote
- Calcula margem automática (preço venda − custo aquisição)

#### 3. Conferência interna
- Registra apenas o peso pra controle de manejo
- **Não gera lançamento financeiro**
- **Gera no Manejo de Gado:** evento de pesagem no histórico do lote
- Usado pra: controle de ganho de peso, ajuste de lotação, planejamento de abate

---

## Fluxo no app

```
Tela inicial
  │
  ├─ [Nova pesagem]
  │    │
  │    ├─ Bipa/digita peso dos animais
  │    │
  │    ├─ [Finalizar pesagem]
  │    │
  │    └─ Pergunta: qual o propósito?
  │         ├─ 📥 Compra → preenche fornecedor, valor @
  │         ├─ 📤 Venda → preenche comprador, valor @
  │         └─ 🔍 Conferência → só salva o peso
  │
  ├─ [Histórico]
  └─ [Exportar]
```

---

## Integrações quando conectado

### Com o módulo Manejo de Gado
- Compra → cria lote novo
- Venda → baixa animais
- Conferência → atualiza peso médio do lote existente

### Com o Cérebro
- Compra → lançamento de custo
- Venda → lançamento de receita
- Conferência → nada (puramente operacional)

---

## Por que funciona assim

**O produtor sabe o contexto da pesagem melhor que qualquer sistema.**
Em vez de tentar adivinhar (o que gera erro e retrabalho), o app simplesmente pergunta *"pra que é essa pesagem?"* e deixa ele escolher.

Isso mantém a lógica:
- Dentro do app (decisão local)
- Simples pro usuário (três botões claros)
- Correta pro Cérebro (já chega classificado)

---

## Status atual

App já está em produção como PWA. Precisa:
- [ ] Adicionar os três modos de pesagem
- [ ] Passar nos 4 testes mínimos
- [ ] Integrar com schema do Cérebro Rural (hoje usa LocalStorage)
- [ ] Migrar dados existentes para Supabase
