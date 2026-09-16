# Cérebro Rural

> Uma **Tomada** onde qualquer app se pluga. Ela lê o que o app exporta, junta tudo numa **planilha mestre** que é sua, e mostra num **Painel** interativo. Só isso — feito muito bem.

## O que é, em três linhas

- **Tomada** — recebe planilha, extrato, export de qualquer sistema (xlsx, csv, ofx, xml de NF-e), entende o layout, lembra como cada fonte é, e nunca grava duas vezes. Cada número guarda de onde veio: arquivo, aba, linha.
- **Planilha mestre** — tudo que entrou, normalizado, exportável a qualquer momento em xlsx/csv/Google Sheets. O dado é do produtor, não do sistema.
- **Painel** — caixa consolidado por negócio (fazenda, frigorífico, imóveis, comércio, pessoal), por mês, com drill-down até a linha original e uma fila de revisão para o que ficou em dúvida.

## Onde está cada coisa

| Caminho | O que é |
|---|---|
| [`IDEIA.md`](./IDEIA.md) | por que existe e para quem |
| [`TOMADA.md`](./TOMADA.md) | **como a leitura funciona**, etapa por etapa — o documento central |
| [`PAINEL.md`](./PAINEL.md) | o que o painel mostra e como a planilha mestre sai |
| [`DECISOES.md`](./DECISOES.md) | decisões e seus motivos, numeradas |
| [`QUALIDADE.md`](./QUALIDADE.md) | a definição mensurável de "pronto" e os portões de cada fase |
| [`app/`](./app/) | o único produto: Vite + React + TypeScript + Supabase |
| [`historico/`](./historico/) | por que recomeçamos (análise crítica, questionário, decisões da v0) |

## Rodar

```bash
cd app
npm install
npm test          # a biblioteca de leitura contra as fixtures reais
npm run dev       # abre o painel em http://localhost:5173
```

## Regra da casa

**Documento descreve o que existe no código.** Se divergirem, o código vence e o documento é corrigido no mesmo commit. Nenhum arquivo `.md` novo na raiz até a v1 estar em uso real.

---
*Thiago Oliveira — Vitória da Conquista, Bahia. Recomeçado em setembro de 2026.*
