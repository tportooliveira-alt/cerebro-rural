# O Painel e a planilha mestre

## As planilhas mestras — uma por área

Tudo que a Tomada aceitou vive nas tabelas canônicas de cada área (`financas`, `gado`, `estoque`, `almoxarifado`, `ferramentas`, `pasto` — ver `TOMADA.md` §Áreas), e essas tabelas **são** as planilhas mestras. A de finanças é `lancamentos`. Ela sai do sistema a qualquer momento, inteira ou filtrada, em:

- **xlsx** — uma aba por negócio + uma aba "Tudo" + uma aba "Origem" (arquivo, aba, linha de cada lançamento);
- **csv** — para o contador ou para qualquer outro sistema;
- **Google Sheets** (v1.1) — uma planilha viva que o Cérebro mantém atualizada, para quem prefere olhar no Sheets.

Colunas fixas, sempre na mesma ordem: `data · negocio · tipo · valor · descricao · categoria · subcategoria · contraparte · referencia_externa · fonte · arquivo · aba · linha · classificacao_origem`. Quem abre no Excel entende sem manual.

**Regra:** o dado é do produtor. Não existe informação no Painel que não esteja na planilha mestre exportada.

## O que o Painel mostra

**A primeira tela é "Hoje"** (E1): o que aconteceu hoje em cada área, um cartão por área — finanças do dia (entrou, saiu, caixa), estoque e almoxarifado (o que saiu hoje, o que está abaixo do mínimo), gado (pesagens de hoje, animais sem pasto atribuído), ferramentas (movimentações), pasto (ocupação). Cada cartão abre o painel daquela área. A pessoa só vê os cartões das áreas do seu papel (D14).

**O painel de finanças** tem os quatro blocos abaixo. Os painéis das outras áreas seguem a mesma forma — resumo, lista, fontes, revisão — com os números da área (cabeças por pasto e por categoria, saldo por item, ferramentas por responsável).

### 1. Resultado
Entradas, saídas e resultado do mês, **por negócio** (fazenda, frigorífico, imóveis, comércio, pessoal) e consolidado. Transferências entre contas do mesmo dono ficam fora do resultado e aparecem à parte. Seletor de mês e de intervalo; comparação com o mês anterior e com o mesmo mês do ano anterior.

### 2. Por categoria
Barras por categoria dentro do negócio escolhido. Clicar numa barra abre a lista de lançamentos. Clicar num lançamento abre a **linha original** do arquivo de onde ele veio — arquivo, aba, linha, como estava antes de normalizar. Dois cliques do número até a origem, sempre.

### 3. Fontes
Um cartão por app plugado: nome, negócio, canal, último arquivo lido, linhas lidas no período, e um estado:

| Estado | Significa |
|---|---|
| **ok** | leu nos últimos 7 dias sem rejeição |
| **silenciosa** | mais de 7 dias sem receber nada (o extrato de setembro não veio) |
| **com erro** | houve linhas rejeitadas no último arquivo |
| **layout mudou** | o último arquivo veio com fingerprint diferente do template |
| **nunca leu** | fonte criada, nada recebido |

### 4. Revisão
Fila única do que precisa de um humano: duplicatas prováveis (com o par lado a lado), classificações sugeridas pela IA, valores acima do teto da fonte, linhas rejeitadas com motivo. Cada item se resolve com um toque: *é a mesma coisa / são duas / essa categoria / descartar*. Cada resolução vira memória para a próxima.

## Busca

Um campo de busca que procura em descrição, contraparte, categoria e nos `extras`. "sal mineral" traz tudo que já entrou com isso, de qualquer fonte, de qualquer ano.

## Quem vê o quê

Papéis por área, desde a v1 (D14): `ver` (só olha), `lançar` (sobe arquivo e resolve revisão da área), `revisar` (fecha o mês da área), `administrar` (fontes, papéis, plano de contas). O dono tem tudo em todas as áreas. Um peão com `lançar` em `estoque` abre o Cérebro e vê só o cartão de estoque.

## No celular

O Painel é a mesma página, em uma coluna. Alvos de toque ≥ 44 px. O bloco Resultado vem primeiro; Revisão tem badge com a contagem. Subir arquivo pelo celular funciona igual ao PC.

## O que o Painel não faz (nesta versão)

Não projeta caixa futuro, não faz DRE gerencial, não emite Livro Caixa/LCDPR, não consolida empresas além da fazenda (D10) — isso entra depois que houver três meses reais dentro (ver `QUALIDADE.md`, Fase 4). Antes disso, seria enfeite sobre dado que ainda não existe.
