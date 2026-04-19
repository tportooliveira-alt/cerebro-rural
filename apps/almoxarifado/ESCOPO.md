# Almoxarifado — Escopo completo

## Visão

Almoxarifado central da fazenda. Tudo que entra e sai de mercadoria passa aqui. Cada retirada é rastreada por **item, quantidade, setor de destino, quem pegou, quem liberou e pra quê**.

---

## Cadastros base

### Itens
- Nome
- Código interno (opcional — pra bipagem futura)
- Categoria (ver lista abaixo)
- Unidade de medida (kg, L, saco, un, caixa, m, etc.)
- Marca/fabricante
- Saldo atual (calculado)
- Saldo mínimo (alerta de reposição)
- Custo médio (calculado por entrada ponderada)
- Localização física no almoxarifado (prateleira, galpão, cômodo)
- Foto do item
- Data de validade (quando aplicável — vacinas, medicamentos)
- Ativo/inativo

### Categorias padrão
- Ração e suplementos
- Sal mineral
- Vacinas
- Medicamentos
- Vermífugos
- Ferramentas
- Peças e reposição
- Combustível
- Lubrificantes
- Material de construção
- EPI (equipamento de proteção)
- Material de escritório
- Produtos de limpeza
- Outros

### Setores (destinos possíveis de retirada)
- Pasto 1, Pasto 2, Pasto N... (vem do módulo Pastagem quando conectado)
- Curral
- Casa sede
- Casa de funcionário
- Galpão de máquinas
- Obra ativa (quando houver — vem do módulo Obras)
- Uso geral / manutenção
- Consumo próprio

### Fornecedores
- Nome
- CNPJ/CPF
- Telefone
- Endereço
- Observações

### Funcionários (retirantes e liberadores)
- Vem do módulo Funcionários quando conectado
- No modo autônomo: cadastro simples (nome + cargo)

---

## Movimentações

### Entrada de mercadoria (compra/recebimento)

**Campos:**
- Data da entrada
- Fornecedor
- Número da nota fiscal
- Foto da nota (opcional, pra OCR futuro)
- Forma de pagamento (dinheiro, prazo 30d, cartão, boleto, Pix)
- Lista de itens recebidos:
  - Item
  - Quantidade
  - Valor unitário
  - Valor total (calculado)
- Valor total da nota
- Quem recebeu (funcionário)
- Observações

**Regras:**
- Atualiza saldo de cada item automaticamente
- Recalcula custo médio ponderado
- Se pagamento for a prazo, gera parcela em "contas a pagar"

### Saída de mercadoria (retirada)

**Campos:**
- Data da retirada
- Item
- Quantidade
- **Setor de destino** (obrigatório — é o que categoriza o custo)
- **Quem retirou** (funcionário)
- **Quem liberou** (funcionário — pode ser mesmo que retirou)
- **Motivo/descrição** (ex: "tratamento de bezerro doente", "reforma do curral leste")
- Observações

**Regras:**
- Baixa saldo do item imediatamente
- Registra custo baseado no custo médio atual
- Alerta se levar saldo abaixo do mínimo
- Impede retirada se saldo insuficiente (ou permite com confirmação, configurável)

### Ajuste de estoque (inventário)

**Campos:**
- Data
- Item
- Saldo físico conferido
- Diferença (calculada automaticamente)
- Motivo do ajuste (quebra, perda, erro de registro, furto, etc.)
- Responsável pelo ajuste

**Regras:**
- Ajusta saldo para o valor físico conferido
- Gera lançamento de perda/sobra no fluxo de caixa quando conectado

### Transferência entre setores

**Campos:**
- Data
- Item
- Quantidade
- Setor origem
- Setor destino
- Motivo

**Regras:**
- Move o custo de um setor pra outro
- Não baixa saldo total, só muda a atribuição interna

---

## Relatórios (dentro do próprio app)

1. **Saldo atual** — todos os itens com quantidade e valor em estoque
2. **Itens abaixo do mínimo** — lista de reposição urgente
3. **Entradas por período** — filtro por data, fornecedor, categoria
4. **Saídas por setor** — quanto cada setor consumiu no período
5. **Saídas por funcionário** — quem retirou o quê
6. **Itens mais consumidos** — top 10 do mês
7. **Custo por setor** — totalizador pra comparação
8. **Validade próxima** — itens vencendo em 30/60/90 dias

---

## Formas de entrada de dados

### 1. Digitação manual
Formulário simples, passo a passo. Otimizado pra celular.

### 2. Importação de Excel
- Usuário sobe uma planilha
- IA mapeia as colunas (Nome → nome, Qtde → quantidade, etc.)
- Preview antes de confirmar
- Lançamento em lote

### 3. Foto de nota fiscal
- Tira foto do cupom ou nota
- IA extrai: fornecedor, data, itens, valores
- Usuário confirma e ajusta se necessário
- Lançamento automático

### 4. Código de barras (v2)
- Bipar o código do produto
- Sistema reconhece e sugere cadastro ou baixa

---

## Permissões por papel

| Ação                    | Dono | Gerente | Peão  |
|-------------------------|------|---------|-------|
| Ver saldo               | ✅   | ✅      | ✅    |
| Ver valores financeiros | ✅   | ✅      | ❌    |
| Cadastrar item          | ✅   | ✅      | ❌    |
| Registrar entrada       | ✅   | ✅      | ❌    |
| Registrar saída         | ✅   | ✅      | ✅    |
| Ajuste de inventário    | ✅   | ✅      | ❌    |
| Deletar lançamento      | ✅   | ❌      | ❌    |

**Regra de ouro:** o peão vê o que tem, retira o que precisa, mas não vê preços nem pode deletar nada.

---

## O que o app NÃO faz

- ❌ Não gera fluxo de caixa próprio (isso é do Cérebro)
- ❌ Não controla contas a pagar completas (só registra a parcela e envia pro Cérebro)
- ❌ Não faz folha de pagamento (isso é do módulo Funcionários)
- ❌ Não controla obras (isso é do módulo Obras, que pode retirar do almoxarifado)

**Cada app faz uma coisa só, mas faz bem feito.**
