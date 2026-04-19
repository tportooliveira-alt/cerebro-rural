# Aluguel — Cérebro Rural

> App independente de gestão de imóveis alugados, contratos e recebimentos.

---

## Escopo resumido

### Cadastros
- Imóveis (nome, endereço, tipo, valor referência)
- Contratos (inquilino, valor, vigência, dia de vencimento)
- Inquilinos (nome, CPF/CNPJ, contato)

### Movimentações
- Recebimento mensal (valor previsto vs recebido, data)
- Reajuste de contrato
- Fim de contrato / renovação
- Atraso de pagamento → alerta

### Formas de entrada
- Manual
- Captura por WhatsApp: "o Pedro do apartamento 3 pagou hoje"
- Lembretes automáticos de vencimento

---

## Integrações quando conectado

- **Cérebro** → recebimento vira ENTRADA categoria `'Receita Patrimônio'`
- Se atrasado: entra como `'Conta a Receber'` com status `'atrasado'`

---

## Status

Em especificação.
