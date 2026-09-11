# Qualidade — o que "perfeito" significa aqui

> Sem pressa não é fase mais longa; é **portão mais alto**. Uma fase só fecha quando todos os itens do portão dela estão verdes. Nenhuma data neste arquivo.

---

## Fase 0 — Arquivos reais antes de qualquer código de leitura

Um leitor treinado em exemplo inventado erra no primeiro arquivo real. Por isso a Fase 0 é coleta.

**Coletar (anonimizados) e commitar em `app/fixtures/`:**
- extrato de cada conta bancária do autor, em **csv e ofx**, de pelo menos 2 meses consecutivos (para testar sobreposição);
- fatura de cartão;
- export do FrigoGest (vendas, compras, abates);
- export da Calculadora de Boi;
- a planilha/caderno da fazenda (a de verdade, com título, totais e tudo);
- a planilha que o contador manda ou pede;
- se houver: extrato da cooperativa, romaneio de frigorífico comprador, export Conta Azul/Aegro, XML de NF-e recebida.

Cada fixture ganha um arquivo `*.esperado.json` escrito à mão com as linhas canônicas que a Tomada **deve** produzir (golden file).

**Portão:** ≥ 8 fontes distintas, ≥ 20 arquivos, todos com golden file. Enquanto os reais não chegam, fixtures sintéticas fiéis aos layouts públicos de BB, Sicoob, Bradesco, Itaú, Nubank e Inter — marcadas como sintéticas.

---

## Fase 1 — `tomada/` verde

**Portão:**
- 100% das fixtures produzem exatamente o golden file;
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
- o autor sobe um export real do FrigoGest e um extrato real, confirma o mapa **uma vez**, sobe o do mês seguinte e **não é perguntado nada**;
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

**Portão:** o autor fecha **três meses seguidos** com todos os negócios dele dentro, sem planilha externa e sem corrigir nada direto no banco. A cada mês, anotar: quantas perguntas a Tomada fez, quantas linhas foram para revisão, quanto tempo levou para fechar.

Só depois deste portão entram: Google Sheets ao vivo, e-mail, WhatsApp, HTTP para o FrigoGest, Livro Caixa/LCDPR, e o primeiro produtor que não é o autor.

---

## Critério de parada

Se a Fase 4 não fechar em três tentativas (nove meses de uso), o problema não é código — é o produto ou o hábito. Parar e reavaliar com `historico/QUESTIONARIO.md` na mão.
