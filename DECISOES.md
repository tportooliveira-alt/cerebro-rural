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

---

## Pendentes (esperando as respostas de `PERGUNTAS.md`)

- Lista exata de negócios e contas de cada um
- Plano de contas: o do contador ou o padrão proposto
- Tratamento de transferências entre contas próprias
- Quem, além do autor, acessa — e com que papel
- Nome comercial e domínio
- Projeto Supabase: criar novo ou reaproveitar
