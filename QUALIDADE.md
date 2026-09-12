# Qualidade — o que "perfeito" significa aqui

> Sem pressa não é fase mais longa; é **portão mais alto**. Uma fase só fecha quando todos os itens do portão dela estão verdes. Nenhuma data neste arquivo.

---

## Fase 0 — As planilhas reais de cada área, antes de qualquer código novo

Não há histórico a importar (D15). O que existe hoje, e é o que a Tomada precisa aprender a ler, são as **planilhas atuais** de cada área e os exports dos apps.

**Coletar (anonimizados) e commitar em `app/fixtures/<area>/`:**
- `financas/` — extrato bancário em csv **e** ofx (2 meses seguidos, para a sobreposição), a planilha de caixa da fazenda, uma NF-e em XML e uma nota em PDF;
- `gado/` — a planilha de rebanho (brinco/lote, raça, sexo, nascimento, pasto) e um export da Calculadora de Boi com pesagens;
- `estoque/` e `almoxarifado/` — a planilha de itens e movimentos (o que entrou, o que saiu, saldo);
- `ferramentas/` — a lista de ferramentas com responsável e local;
- `pasto/` — a lista de pastos com área e lotação, se existir.

Cada fixture ganha um `*.esperado.json` escrito à mão com os registros canônicos que a Tomada **deve** produzir (golden file).

**Portão:** todas as 6 áreas com pelo menos 1 arquivo real e golden file; `financas` com ≥ 4. Enquanto os reais não chegam, fixtures sintéticas fiéis, marcadas como sintéticas.

---

## Fase 1 — `tomada/` verde

**Portão:**
- 100% das fixtures, de todas as áreas, produzem exatamente o golden file;
- testes de propriedade (fuzz) para parse de dinheiro pt-BR e de datas: nenhum formato listado em `TOMADA.md` §4 falha;
- reenviar qualquer fixture → 0 linhas novas;
- extrato de 60 dias seguido do extrato do mês seguinte (30 dias sobrepostos) → só os 30 novos entram;
- tabela com totais no rodapé e duas tabelas na mesma aba → lidas corretamente, ignoradas listadas;
- CSV latin-1 com `;` e BOM → lido sem caractere quebrado;
- OFX v1 (SGML) e v2 (XML) → `FITID` vira `referencia_externa`;
- cobertura de testes na biblioteca ≥ 90%;
- arquivo de 10 mil linhas lido em ≤ 3 s no navegador (medido).

---

## Fase 2 — Schema + tela de leitura (a cunha)

**Portão:**
- `0001_cerebro.sql` aplica limpo num projeto Supabase vazio;
- teste automatizado de RLS: usuário da fazenda A não lê fonte, arquivo nem lançamento da fazenda B;
- o autor aponta a planilha Google de cada área, confirma o mapa **uma vez**, e na releitura seguinte **não é perguntado nada**;
- a Calculadora de Boi envia uma pesagem por HTTP e ela aparece no painel de gado em menos de 5 s;
- um usuário com papel só em `estoque` não vê `financas` (teste automatizado de RLS por área);
- a prévia mostra, com número de linha, tudo que foi ignorado e por quê;
- upload pelo celular funciona igual ao PC.

---

## Fase 3 — Painel completo

**Portão:**
- qualquer número do Painel chega à linha original em ≤ 2 cliques;
- a planilha mestre exporta em xlsx com as colunas fixas de `PAINEL.md` e bate, centavo a centavo, com o total do Painel;
- estados das fontes (ok / silenciosa / com erro / layout mudou / nunca leu) corretos em teste;
- fila de revisão resolve cada item com um toque e grava memória;
- usável a 375 px de largura, alvos ≥ 44 px, sem rolagem horizontal;
- Lighthouse acessibilidade ≥ 90.

---

## Fase 4 — Uso real (o único portão que importa)

**Portão:** o autor fecha **três meses seguidos** com todas as áreas da fazenda dentro — finanças, gado, estoque, almoxarifado, ferramentas — sem corrigir nada direto no banco, com a equipe usando os papéis dela. A cada mês, anotar: quantas perguntas a Tomada fez, quantas linhas foram para revisão, quanto tempo levou para fechar.

Só depois deste portão entram: Google Sheets ao vivo, e-mail, WhatsApp, HTTP para o FrigoGest, Livro Caixa/LCDPR, e o primeiro produtor que não é o autor.

---

## Critério de parada

Se a Fase 4 não fechar em três tentativas (nove meses de uso), o problema não é código — é o produto ou o hábito. Parar e reavaliar com `historico/QUESTIONARIO.md` na mão.
