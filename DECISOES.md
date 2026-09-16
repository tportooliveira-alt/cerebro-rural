# Decisões

> Numeradas, com data e motivo. Quando uma for revertida, registrar aqui a nova com a justificativa — nunca apagar a antiga.
> As decisões da versão anterior do projeto (D01–D10 de abril/2026) estão em [`historico/DECISOES_v0.md`](./historico/DECISOES_v0.md). Este arquivo recomeça do D01.

---

## D01 — O Cérebro é uma Tomada, não um construtor de apps
**Data:** 11/09/2026
**Decisão:** o produto lê o que qualquer app exporta. Não constrói módulos de almoxarifado, pastagem, obras, folha etc. Os apps que fazem isso continuam existindo; o Cérebro pluga neles pela saída.
**Substitui:** v0 D01 (micro-apps separados).
**Por quê:** dez apps são dez produtos; nenhum solo entrega isso. E todo app já exporta tabela — construir o que já existe é desperdício.

## D02 — Planilha/export é o adaptador universal; HTTP é canal secundário
**Data:** 11/09/2026
**Decisão:** o caminho principal de entrada é arquivo (xlsx, csv, ofx, xml). O canal HTTP existe para app próprio mandar direto, mas nunca é pré-requisito.
**Por quê:** nenhum banco, cooperativa ou sistema de terceiro vai integrar com a gente. Todos exportam planilha. Quem lê planilha bem, lê tudo.

## D03 — Dedup por hash de linha e de arquivo; provável vai para revisão, nunca é rejeitada em silêncio
**Data:** 11/09/2026
**Decisão:** `UNIQUE(fonte_id, hash_linha)` no banco; hash do arquivo corta reenvio antes de abrir; duplicata *provável* (mesma data e valor, fontes diferentes) entra na fila de revisão com o par apontado.
**Substitui:** v0 D03 (cinco checkpoints obrigatórios em toda entrada).
**Por quê:** cinco checkpoints em cada lançamento transformam app de campo em cartório. Dois portões automáticos + uma fila humana protegem o relatório sem travar o uso.

## D04 — Leitura no navegador; nenhum servidor próprio na v1
**Data:** 11/09/2026
**Decisão:** detecção, abertura, perfil, mapeamento e dedup local rodam no navegador (SheetJS, PapaParse, parser OFX próprio). O arquivo só sobe para o Storage depois da confirmação. Única função de borda: `sugerir-mapa`, opcional.
**Substitui:** v0 host Go/gRPC.
**Por quê:** a stack escolhida (Vercel + Supabase) não roda processo persistente; leitura local é mais rápida, mais privada e sem custo de infra.

## D05 — Nada entra sem origem
**Data:** 11/09/2026
**Decisão:** todo lançamento guarda `fonte_id, arquivo_id, aba, linha, hash_linha`. O arquivo bruto fica no Storage. O Painel abre a linha original em dois cliques.
**Por quê:** confiança em relatório financeiro vem de poder conferir. "De onde saiu esse número?" tem que ter resposta sempre.

## D06 — A planilha mestre é do produtor
**Data:** 11/09/2026
**Decisão:** `lancamentos` exporta inteira em xlsx/csv a qualquer momento, com colunas fixas e legíveis. Não existe dado no Painel que não esteja na exportação.
**Por quê:** o contador quer planilha; o produtor quer poder sair sem perder nada. Retenção vem de utilidade, não de cativeiro.

## D07 — Confirmação humana uma vez por arquivo, não uma vez por linha
**Data:** 11/09/2026
**Decisão:** a prévia é a única parada obrigatória. O que o humano corrige ali vira template (como ler) e memória (o que é cada coisa). Segundo arquivo da mesma fonte, mesmo layout: zero perguntas.
**Por quê:** é o que faz a Tomada *aprender* cada app em vez de perguntar para sempre.

## D08 — Documento descreve o que existe no código
**Data:** 11/09/2026
**Decisão:** se doc e código divergirem, o código vence e o doc é corrigido no mesmo commit. Nenhum `.md` novo na raiz até a v1 estar em uso real.
**Substitui:** v0 regra "não codar antes da documentação fechar".
**Por quê:** a regra antiga produziu 3.323 linhas de doc, 0 de frontend e docs que se contradiziam.

## D09 — Sem pressa: portões de qualidade por fase, não prazos
**Data:** 11/09/2026
**Decisão:** cada fase só fecha quando bate o portão mensurável de `QUALIDADE.md`. Não existe data de entrega; existe critério de pronto.
**Por quê:** pedido explícito do autor — "não tenho pressa, quero algo perfeito". Perfeito precisa de definição, não de adjetivo.

## D10 — v1 é só a fazenda; empresas entram depois, no mesmo lugar
**Data:** 12/09/2026 · **Origem:** resposta B1
**Decisão:** o único `negocio` da v1 é `fazenda` (uma ou mais propriedades). Frigorífico, imóveis, comércio e pessoal entram depois — sem mudar o modelo, só ligando fontes novas.
**Por quê:** "por enquanto só as fazendas; depois aplicamos o Cérebro pra tudo que a pessoa tiver de empresa".

## D11 — A Tomada lê qualquer tabela, não só tabela de dinheiro
**Data:** 12/09/2026 · **Origem:** respostas A2, E1, I1
**Decisão:** cada fonte pertence a uma **área**: `financas`, `gado`, `estoque`, `almoxarifado`, `ferramentas`, `pasto`. Cada área tem seu esquema canônico (ver `TOMADA.md` §Áreas), seu dicionário de sinônimos, sua planilha mestre e seu painel. O pipeline (detectar → … → prévia → gravar com origem) é o mesmo para todas; só o passo "normalizar para o canônico" muda por área.
**Substitui:** a leitura restrita a `lancamentos` da versão de 11/09.
**Por quê:** o autor quer ver "estoque e almoxarifado", "gado", "ferramentas", "cada qual com seu filtro, separadamente". Pesagem não é dinheiro; sal mineral no estoque não é dinheiro. Mas todos são tabela — e tabela a Tomada lê.

## D12 — Google Sheets, Drive e e-mail são canais da v1
**Data:** 12/09/2026 · **Origem:** resposta B1
**Decisão:** além do upload, a v1 lê planilhas do Google Sheets por link (releitura automática), arquivos numa pasta do Drive e anexos de um endereço de e-mail. A planilha do produtor continua sendo *o app* — o Cérebro lê.
**Substitui:** a ordem "upload v1 → Sheets v1.1 → e-mail v1.2" de `TOMADA.md`.
**Por quê:** "tudo num lugar só, conectado a planilhas Google, e-mail e Drive". Se a equipe já preenche planilha, não há por que criar tela de digitação.

## D13 — Calculadora de Boi conecta direto: a pesagem entra na hora
**Data:** 12/09/2026 · **Origem:** resposta A2
**Decisão:** a Calculadora de Boi (app próprio) envia cada pesagem por HTTP para a Tomada, área `gado`. A pesagem fica registrada no ato; a atribuição do **pasto** é feita depois, no painel de gado, por quem tem o papel. Venda/compra confirmadas na Calculadora geram também um lançamento em `financas`.
**Por quê:** "assim, pesar já entra no sistema; depois encaminhamos qual pasto".

## D14 — Papéis por área desde a v1
**Data:** 12/09/2026 · **Origem:** resposta F1
**Decisão:** cada pessoa tem um papel por área (`ver`, `lançar`, `revisar`, `administrar`) e só enxerga as áreas do seu cargo. O dono vê tudo. RLS por `fazenda_id` **e** por área.
**Por quê:** "várias pessoas, cada uma com área separada, acesso exclusivo dependendo do cargo".

## D15 — Sem importar histórico: começa hoje, com saldos de abertura
**Data:** 12/09/2026 · **Origem:** resposta I1
**Decisão:** nada do passado é carregado. No primeiro dia entram os **saldos de abertura** de cada área: dinheiro em caixa, estoque, gado (por lote/brinco), almoxarifado, ferramentas. Cada saldo de abertura é um registro normal com `origem = abertura`.
**Substitui:** Fase 0 de `QUALIDADE.md` (coleta de 2 meses de extrato etc.) — a coleta agora é das planilhas *atuais* de cada área.
**Por quê:** "começar de agora pra não atrapalhar".

## D16 — Transferência entre contas próprias é neutra
**Data:** 12/09/2026 · **Origem:** resposta C1 (premissa aceita)
**Decisão:** marcada `Transferência`, fora do resultado, visível à parte.

## D17 — Plano de contas padrão, ajustável
**Data:** 12/09/2026 · **Origem:** resposta D1 (premissa aceita)
**Decisão:** o plano proposto em `PERGUNTAS.md` D1 vira o padrão inicial (`app/src/tomada/plano-de-contas.ts`); o produtor renomeia e acrescenta pelo painel.

## D18 — Projeto Supabase novo, São Paulo, criado com autorização do autor
**Data:** 12/09/2026 · **Origem:** resposta H1 (premissa aceita)
**Decisão:** projeto novo, free tier, região `sa-east-1`. Criação só quando `0001_cerebro.sql` estiver pronto, e confirmada com o autor no momento (é ação na conta dele).

## D19 — Cada área é um APP SEPARADO que pluga; o Cérebro é a tomada e o painel
**Data:** 12/09/2026 · **Origem:** resposta J4
**Decisão:** o Cérebro **não constrói** as telas de gado, almoxarifado, ferramentas ou estoque. Cada um desses é um app separado (ou uma planilha, ou a Calculadora de Boi) que **se pluga**. As 6 áreas de D11 deixam de ser módulos a construir e passam a ser o **contrato de leitura**: o canônico que um app precisa falar para ser lido, e o painel que o Cérebro mostra do que recebeu.
**Corrige:** a leitura de D11, que dava a entender que as áreas seriam construídas dentro do Cérebro.
**Por quê:** "colocar gado, almoxarifado, ferramentas — mas isso vai ser em outro app; ele vai ser plugado".
**Consequência prática:** o que eu construo é só (a) a Tomada, (b) a planilha mestre, (c) o Painel. Nada mais. O canônico por área continua no código porque é o que permite ler o que chega.

## D20 — O Cérebro se expõe como servidor MCP (depois da v1)
**Data:** 12/09/2026 · **Origem:** resposta J4 ("ideia do Cérebro: plugin MCP")
**Decisão:** depois de o Painel estar em uso real, o Cérebro publica um **servidor MCP** com poucas ferramentas (`listar_fontes`, `ler_area`, `enviar_registros`, `resumo_do_dia`). Assim qualquer app ou agente — inclusive o Claude — pluga sem HTTP próprio.
**Não confundir com** o que foi para o arquivo morto: aquilo era uma camada *cliente* de 9 provedores de LLM dentro de um host Go. Isto é o contrário: expor os dados do Cérebro como servidor, algumas dezenas de linhas sobre o mesmo banco.
**Por quê:** é o mesmo contrato do canal HTTP, com adaptador que agentes já sabem usar. Custa pouco e é exatamente "plugo tudo".
**Quando:** só depois do portão da Fase 3 (Painel completo). Antes disso, é distração — e você pediu para ver o dashboard abrindo.

## D21 — O Painel vem antes de qualquer canal novo
**Data:** 12/09/2026 · **Origem:** resposta J4 ("quero ver dashboard abrindo")
**Decisão:** a próxima entrega é um Painel que **abre e mostra números**, alimentado pela Tomada rodando no navegador, sem banco. Google Sheets, Drive, e-mail e MCP vêm depois dele.
**Por quê:** pedido direto do autor, e é o único jeito de ele julgar o que está sendo feito.

---

## Pendentes (esperando as respostas de `PERGUNTAS.md`)

- Quais planilhas Google existem hoje para cada área e quem preenche (novas perguntas A13–A16)
- Lista de cargos e o que cada um vê (F6–F8)
- Formato exato do que a Calculadora de Boi envia (A17)
- Nome comercial e domínio (H3)
