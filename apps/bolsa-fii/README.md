# Bolsa / FII — Cérebro Rural

> App independente de acompanhamento de investimentos em renda variável e fundos imobiliários.

---

## Escopo resumido

### Cadastros
- Corretora (XP, Rico, Clear, BTG, etc.)
- Carteira (ações, FIIs, ETFs)

### Movimentações
- Aporte (compra de ativo)
- Venda de ativo
- Recebimento de dividendo / rendimento
- Bonificação / desdobramento

### Integrações externas
- B3 (consulta cotação em tempo real)
- CEI/B3 (importação automática de extrato — via API ou scraping)

### Formas de entrada
- Manual
- Importação de nota de corretagem (PDF)
- Sync automático com API da corretora (quando disponível)

---

## Integrações quando conectado

- **Cérebro** →
  - Aporte: SAIDA categoria `'Investimento'`
  - Dividendo: ENTRADA categoria `'Rendimento'`
  - Venda: ENTRADA categoria `'Realização de Investimento'`
- Dashboard de patrimônio: posição líquida + variação mensal

---

## Status

Em especificação. Prioridade baixa (último app do roadmap).
