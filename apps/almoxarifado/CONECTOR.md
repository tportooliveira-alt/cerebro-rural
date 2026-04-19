# Almoxarifado — Conector com o Cérebro

Documenta como cada movimentação do Almoxarifado vira lançamento no fluxo de caixa central (tabela `lancamentos`).

> **Importante:** o conector só é ativado na **Fase 3** do roadmap. Enquanto o app está em desenvolvimento, ele funciona 100% sozinho sem gerar nada no Cérebro.

---

## Entrada de mercadoria → `lancamentos`

Quando uma entrada é confirmada (status = 'confirmado'):

| Campo em `lancamentos` | Valor vindo do Almoxarifado           |
|------------------------|----------------------------------------|
| `fazenda_id`           | `almox_entradas.fazenda_id`            |
| `app_origem`           | `'almoxarifado'`                       |
| `categoria`            | `'Custo de Produção'`                  |
| `subcategoria`         | Categoria predominante dos itens (ex: 'Ração', 'Insumo') |
| `tipo`                 | `'SAIDA'` se pago à vista; senão 'PENDENTE' |
| `valor`                | `almox_entradas.valor_total`           |
| `data`                 | `almox_entradas.data`                  |
| `descricao`            | `'Compra de ' + <itens> + ' — ' + <fornecedor>` |
| `responsavel`          | `almox_entradas.recebido_por`          |
| `referencia_id`        | `almox_entradas.id`                    |
| `referencia_tipo`      | `'almox_entradas'`                     |

### Compra a prazo
Se `forma_pagamento = 'prazo'` e `parcelas > 1`:
- Cria N lançamentos futuros com `status = 'pendente'`
- Data de cada parcela: data da compra + 30d × número da parcela
- Categoria: `'Conta a Pagar'`

---

## Saída de mercadoria → `lancamentos`

Cada saída vira um lançamento de custo atribuído ao setor:

| Campo em `lancamentos` | Valor vindo do Almoxarifado           |
|------------------------|----------------------------------------|
| `fazenda_id`           | `almox_saidas.fazenda_id`              |
| `app_origem`           | `'almoxarifado'`                       |
| `categoria`            | Mapeada pelo setor (ver tabela abaixo) |
| `subcategoria`         | Categoria do item (ração, vacina, etc.)|
| `tipo`                 | `'SAIDA'` (movimentação interna de estoque para uso) |
| `valor`                | `almox_saidas.custo_total`             |
| `data`                 | `almox_saidas.data`                    |
| `descricao`            | `<item> × <qtd> para <setor> — <motivo>` |
| `responsavel`          | `almox_saidas.retirado_por`            |
| `referencia_id`        | `almox_saidas.id`                      |
| `referencia_tipo`      | `'almox_saidas'`                       |

### Mapeamento de setor → categoria financeira

| Tipo de setor     | Categoria em `lancamentos`     |
|-------------------|--------------------------------|
| Pasto / Curral    | `'Custo de Produção'`          |
| Obra              | `'Investimento / Capital'`     |
| Casa sede         | `'Despesa Administrativa'`     |
| Casa funcionário  | `'Benefício'`                  |
| Manutenção        | `'Manutenção'`                 |
| Consumo próprio   | `'Retirada do Sócio'`          |
| Uso geral         | `'Despesa Geral'`              |

**Por que isso importa:** o produtor pergunta ao Cérebro *"quanto investi em obras esse ano?"* e a IA soma só os lançamentos com categoria 'Investimento / Capital'. Se não houver esse mapeamento, fica tudo misturado.

---

## Ajuste de inventário → `lancamentos`

Quando há diferença no inventário:

- Se `diferenca < 0` (faltou): lançamento de SAIDA, categoria `'Perda'`
- Se `diferenca > 0` (sobrou): lançamento de ENTRADA, categoria `'Ajuste'`
- Valor: `ABS(diferenca) × custo_medio`

---

## Transferência entre setores → `lancamentos`

Gera DOIS lançamentos espelhados:
1. SAIDA do setor origem (valor negativo na categoria original)
2. ENTRADA no setor destino (valor positivo na nova categoria)

Resultado líquido no fluxo de caixa: **zero**. Mas a análise por centro de custo fica correta.

---

## O que NÃO vai para o Cérebro

- Saldo de itens (informação operacional do app)
- Cadastro de fornecedores (fica no app)
- Localização física dos itens (fica no app)
- Validade (fica no app, com alertas próprios)

**Regra:** só vai pro Cérebro o que tem **impacto financeiro**.

---

## Sincronização

### Modo online
Trigger no Supabase cria o lançamento imediatamente após confirmar a movimentação.

### Modo offline
1. App grava localmente (IndexedDB)
2. Marca como `sincronizado = false`
3. Quando conecta, envia em lote pro Supabase
4. Trigger gera os lançamentos no Cérebro
5. App recebe confirmação e marca `sincronizado = true`

### Edição / exclusão
- Editar valor → atualiza o lançamento correspondente
- Excluir movimentação → marca lançamento como `status = 'cancelado'` (não deleta, mantém histórico)
