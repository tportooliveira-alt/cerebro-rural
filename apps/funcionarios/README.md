# Funcionários — Cérebro Rural

> App independente de gestão de folha de pagamento, ponto e adiantamentos.

---

## Escopo resumido

### Cadastros
- Funcionário (nome, CPF, cargo, salário base, data de admissão)
- Tipos de descontos e acréscimos

### Movimentações
- Folha mensal (competência, valor líquido, encargos, data de pagamento)
- Adiantamento (valor, data, desconta na folha do mês)
- Ponto simples (entrada, saída, falta)
- Ajuste de horas extras

### Formas de entrada
- Manual
- Importação de Excel (folha já calculada por contador)
- Captura por voz: "paguei R$ 1.500 pro José dia 5"

---

## Integrações quando conectado

- **Almoxarifado** → registra quem retirou item
- **Obras** → registra quem trabalhou na obra
- **Cérebro** → folha vira SAIDA categoria `'Custo Fixo'` / subcategoria `'Folha'`

---

## Status

Em especificação.
