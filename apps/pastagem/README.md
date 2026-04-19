# Pastagem — Cérebro Rural

> App independente de gestão de pastagens. Pastos, áreas, lotação em UA, rotação, histórico.

---

## Escopo resumido

### Cadastros
- Pastos (nome, área em hectares, forrageira, capacidade UA/ha)
- Polígono geográfico no mapa (Google Maps)
- Status: ativo | descanso | interditado

### Movimentações
- Entrada de lote no pasto
- Saída de lote do pasto
- Mudança de status (pasto vai pra descanso)
- Edição de área (recalcula lotação automaticamente)

### Cálculos centrais
- `capacidade_ua = area_ha × ua_por_ha`
- `ua_lote = (qtd × peso_medio) / 450`
- `lotacao_pct = ua_ocupada / capacidade_ua × 100`
- Dias em pastejo / dias em descanso

### Formas de entrada
- Manual (formulário)
- Desenho no mapa (Google Maps Polygon)
- Edição direta de hectares (qualquer hora)

---

## Integrações quando conectado

- **Calculadora de Boi** → lotes atualizam peso médio via pesagem
- **Manejo de Gado** → movimentação de animais
- **Almoxarifado** → setor "Pasto X" recebe saídas de insumo
- **Cérebro** → custo acumulado por pasto, rendimento do lote

---

## Status

Em especificação. Base existe das conversas anteriores sobre PastoGest.
