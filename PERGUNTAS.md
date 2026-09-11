# Perguntas de recomeço

> Não são perguntas para testar a ideia — isso já foi feito em `historico/QUESTIONARIO.md`.
> São as perguntas cuja resposta **eu preciso para construir certo**. Cada uma diz por que pergunto e o que assumo se você não responder — assim nada trava.
> Responda o que souber, na ordem que quiser, aos poucos. Cada resposta vira uma linha em `DECISOES.md` ou uma fixture em `app/fixtures/`.
>
> ⚑ = destrava trabalho imediato. Responda estas primeiro.

---

## A — As fontes que você vai plugar no dia 1

**A1 ⚑ Liste todo sistema, app, banco e planilha de onde sai dinheiro ou informação de dinheiro hoje — um por linha, com o negócio a que pertence.**
*Por que pergunto:* a Tomada é treinada em cima das suas fontes reais. Sem a lista, eu construo para um produtor genérico.
*Se não responder, assumo:* FrigoGest, Calculadora de Boi, 1 conta bancária PF, 1 cartão, 1 planilha da fazenda, 1 planilha do contador.

**A2 ⚑ Para cada fonte de A1: em que formato ela exporta (xlsx, csv, ofx, pdf, "só na tela")? Com que frequência você tiraria esse export (diário, semanal, mensal)?**
*Por que:* define a ordem dos parsers e quais canais importam. Fonte que só mostra na tela precisa de outro caminho (foto, digitação, HTTP).
*Assumo:* xlsx e csv mensais; banco em csv/ofx mensal.

**A3 ⚑ Você consegue me mandar um arquivo real de cada fonte, anonimizado (troca nomes, mantém o layout)? Pelo menos dois meses seguidos do extrato bancário.**
*Por que:* é a Fase 0 de `QUALIDADE.md`. Leitor treinado em arquivo inventado erra no primeiro arquivo de verdade. Dois meses seguidos testam a sobreposição.
*Assumo:* fixtures sintéticas fiéis aos layouts públicos de BB, Sicoob, Bradesco, Itaú, Nubank e Inter, marcadas como sintéticas, até os reais chegarem.

**A4 Quais bancos, quantas contas em cada um, e cada conta é PF ou PJ? O internet banking de cada um oferece OFX?**
*Por que:* OFX tem `FITID` (id único por transação) e torna a dedup exata. CSV não tem. Muda a estratégia por banco.
*Assumo:* 1 conta PF com CSV e OFX.

**A5 O FrigoGest é seu (banco Supabase próprio). Prefere que ele mande direto por HTTP para a Tomada, ou que você exporte planilha dele como qualquer outra fonte?**
*Por que:* HTTP é canal v1.2 e exige chave e código no FrigoGest. Export é v1 e não exige nada. A resposta define se o canal HTTP sobe de prioridade.
*Assumo:* export (planilha) na v1; HTTP depois.

**A6 Do FrigoGest, o que precisa entrar no Cérebro: vendas, compras de gado, abates, despesas operacionais, tudo? Cada um vira que tipo (entrada/saída) e que categoria?**
*Por que:* define o mapa da fonte "frigogest" e as regras de classificação já prontas no primeiro upload.
*Assumo:* vendas = ENTRADA/Receita; compras de gado = SAÍDA/Custo de Mercadoria; despesas = SAÍDA/Custo Operacional.

**A7 A Calculadora de Boi exporta o quê hoje (pesagens, lotes, valor estimado)? Só a venda confirmada deve virar lançamento, ou a pesagem de conferência também aparece em algum lugar?**
*Por que:* pesagem não é dinheiro. Se entrar como lançamento, infla o caixa. Pode virar `extras` ou ficar de fora.
*Assumo:* só venda e compra confirmadas viram lançamento; conferência não entra.

**A8 O que o contador te manda e o que ele te pede hoje, em que formato, e quando no mês?**
*Por que:* a planilha mestre exportada tem que servir para ele sem retrabalho. Se ele já tem um plano de contas, a gente usa o dele (ver D1).
*Assumo:* ele pede um resumo mensal em xlsx; não manda nada estruturado.

**A9 Você recebe XML de NF-e dos fornecedores (por e-mail, pelo portal, pelo contador)? Quer que a Tomada leia XML?**
*Por que:* XML é 100% exato, sem heurística. Se você recebe, é a melhor fonte de compras que existe.
*Assumo:* não na v1; entra na v1.2 se houver volume.

**A10 Existe cooperativa, frigorífico comprador ou leilão que te manda romaneio/extrato/nota de venda? Em que formato?**
*Por que:* é a fonte da receita de gado quando a venda não passa pelo FrigoGest. Layout costuma ser PDF ou planilha própria.
*Assumo:* não na v1.

**A11 A planilha/caderno da fazenda: quantas planilhas, uma aba por mês ou por ano, tem totais no rodapé, tem mais de uma tabela por aba? Quem preenche?**
*Por que:* é o caso mais difícil de `TOMADA.md` §3. Saber o layout real evita heurística no escuro.
*Assumo:* uma planilha por ano, uma aba por mês, título em cima, total embaixo, uma pessoa preenche.

**A12 Alguma fonte só existe em papel (nota de feira, recibo de mão de obra, cupom)? Quanto do gasto mensal isso representa, em %?**
*Por que:* se for > 20%, precisa de um caminho de digitação rápida no celular na v1. Se for < 20%, fica para depois.
*Assumo:* < 20%; digitação manual mínima na v1 (data, valor, descrição, negócio).

---

## B — Os negócios e as contas

**B1 ⚑ Liste os negócios exatamente como quer vê-los no Painel (ex.: Fazenda Boa Vista, Frigorífico, Imóveis, Comércio, Pessoal). Cada um tem CPF/CNPJ próprio ou está tudo no seu CPF?**
*Por que:* `negocio` é a etiqueta principal de tudo. E a obrigação fiscal muda entre PF e PJ (Livro Caixa × contabilidade).
*Assumo:* fazenda, frigorífico, imóveis, pessoal — fazenda e pessoal no CPF, frigorífico em CNPJ.

**B2 Há mais de uma fazenda ou propriedade rural? Quer vê-las separadas ou juntas?**
*Por que:* o Livro Caixa do produtor rural é por imóvel rural. Se há mais de uma, `negocio` precisa de um nível abaixo.
*Assumo:* uma fazenda.

**B3 Qual conta bancária pertence a qual negócio? Alguma conta mistura tudo (pessoal + fazenda na mesma conta)?**
*Por que:* fonte mista exige reetiquetar linha a linha na prévia — a memória aprende, mas o começo é manual. Saber de antemão poupa surpresa.
*Assumo:* a conta PF mistura pessoal e fazenda; a conta PJ é só frigorífico.

**B4 Existe dinheiro em espécie relevante (caixa da fazenda, caixinha do frigorífico)? Como é controlado hoje?**
*Por que:* espécie não aparece em extrato. Se importa, precisa de fonte própria (planilha ou digitação).
*Assumo:* espécie irrelevante para o Painel na v1.

**B5 Cartões: quantos, de quem, pagam o quê? A fatura é lançada como uma saída só ou item a item?**
*Por que:* item a item duplica com o extrato (o pagamento da fatura já aparece lá). A regra padrão é: itens entram e o pagamento da fatura vira Transferência.
*Assumo:* 1 cartão PF, item a item, pagamento = Transferência.

**B6 Investimentos (FII, ações, CDB) entram no Cérebro? Só os proventos que caem na conta, ou a posição também?**
*Por que:* proventos já aparecem no extrato como crédito — basta classificar. Posição é outra coisa (patrimônio, não caixa).
*Assumo:* só o que cai na conta, classificado como Receita Financeira; posição fica fora.

**B7 Aluguéis: quantos imóveis, o inquilino paga por transferência (aparece no extrato) ou em dinheiro?**
*Por que:* se aparece no extrato, é só regra de classificação. Se é dinheiro, precisa de fonte.
*Assumo:* transferência; regra por nome do inquilino.

**B8 Funcionários: pagamento cai no extrato (PIX/transferência) ou é dinheiro? Precisa ver por funcionário ou só o total de folha?**
*Por que:* por funcionário exige `contraparte` bem preenchida e regra por nome.
*Assumo:* PIX; ver por funcionário via contraparte.

---

## C — Regras de dinheiro

**C1 ⚑ Transferência entre suas próprias contas (PF → PJ, conta → cartão, conta → caixa): como quer que apareça? Sugestão: marcada como Transferência, fora do resultado, visível à parte.**
*Por que:* é o erro nº 1 de qualquer consolidação — a mesma grana contada como saída de um lado e entrada do outro.
*Assumo:* a sugestão.

**C2 Compra parcelada em 6x: o que conta é quando o dinheiro sai (regime de caixa) ou quando comprou (competência)? Sugestão: caixa — é o que o extrato mostra e o que o Livro Caixa exige.**
*Por que:* muda todo cálculo do mês.
*Assumo:* caixa.

**C3 Venda de gado a prazo, com comissão e frete descontados pelo comprador: quer ver o bruto e os descontos separados, ou só o líquido que caiu?**
*Por que:* o extrato só mostra o líquido. Separar exige a nota de venda como fonte (ver A10).
*Assumo:* líquido na v1; bruto/descontos quando houver a nota como fonte.

**C4 Consumo próprio (boi abatido para a casa, insumo da fazenda usado no pessoal): registra? Como?**
*Por que:* não passa por banco; se importa, precisa de fonte ou digitação.
*Assumo:* fora da v1.

**C5 Retirada pessoal da conta da fazenda: é Transferência (para o negócio Pessoal) ou é despesa da fazenda?**
*Por que:* define se o resultado da fazenda "paga" a vida pessoal ou não.
*Assumo:* Transferência fazenda → pessoal; aparece como saída no pessoal.

**C6 Estorno, devolução, PIX errado devolvido: some com o par original ou aparece como entrada?**
*Por que:* afeta dedup e resultado. Sugestão: fica visível, marcado como Estorno, e o Painel anula o par.
*Assumo:* a sugestão.

**C7 Existe alguma moeda além de real (dólar em investimento, compra de máquina)?**
*Por que:* se sim, precisa de coluna de moeda e cotação. Se não, simplifica tudo.
*Assumo:* só BRL.

**C8 Qual é o valor que, se aparecer num lançamento, você quer que seja confirmado antes de entrar (teto por fonte)?**
*Por que:* é o único "checkpoint" automático de anomalia da v1 — barato e útil.
*Assumo:* R$ 20.000 na fonte bancária; sem teto nas outras.

**C9 Se o mesmo valor, na mesma data, aparece no FrigoGest (venda) e no extrato (crédito): são dois lançamentos ou o mesmo? Sugestão: o mesmo — o extrato confirma o que o FrigoGest disse, e um deles vira espelho.**
*Por que:* é o caso "provável" de `TOMADA.md` §8. Sua regra vira o padrão da fila de revisão.
*Assumo:* a sugestão, com você confirmando o par na revisão.

**C10 Mês "fecha"? Depois de fechado, ainda pode entrar lançamento atrasado? Como quer ver isso?**
*Por que:* extrato de setembro que chega em novembro muda o setembro que você já olhou.
*Assumo:* não existe fechamento na v1; lançamento atrasado entra e o Painel marca "N lançamentos entraram depois".

---

## D — Categorias

**D1 ⚑ Você (ou seu contador) já tem um plano de contas? Manda ele. Se não tem, aceita começar com este e ajustar?**
```
ENTRADA  Receita › Venda de Gado · Venda de Carne/Abate · Aluguel · Serviço · Financeira · Outra
SAÍDA    Custo Produção › Suplementação · Sanidade · Pasto/Forragem · Combustível · Mão de Obra · Frete
         Custo Frigorífico › Compra de Gado · Insumo · Energia · Mão de Obra · Frete
         Custo Fixo › Folha · Encargos · Energia · Água · Telefone/Internet · Contador · Seguro
         Investimento › Máquina · Benfeitoria · Cerca · Animal de Reposição
         Imóveis › Manutenção · IPTU · Condomínio
         Pessoal › Alimentação · Saúde · Educação · Casa · Lazer · Transporte
         Impostos › ITR · Funrural · IR · Outros
NEUTRO   Transferência · Estorno · Pagamento de Fatura
```
*Por que:* toda classificação automática depende disso. Mudar depois custa reclassificar.
*Assumo:* o padrão acima.

**D2 Quais palavras aparecem na descrição do extrato que já te dizem a categoria na hora? (ex.: "AGROPEC" = insumo, "POSTO" = combustível, nome do inquilino = aluguel). Liste as que lembrar.**
*Por que:* viram as regras iniciais da fonte — o primeiro upload já sai classificado.
*Assumo:* começo com um dicionário rural genérico e a memória aprende.

**D3 Subcategoria importa para você no dia a dia, ou categoria já basta e subcategoria é para o contador?**
*Por que:* define o nível padrão do Painel e quanto a prévia pede.
*Assumo:* Painel em categoria; subcategoria opcional, preenchida por regra/memória.

**D4 Quer que a IA sugira categoria quando regra e memória não resolvem, ou prefere que a linha fique "sem categoria" até você classificar?**
*Por que:* IA custa dinheiro e erra às vezes; "sem categoria" custa seu tempo. É escolha sua.
*Assumo:* IA sugere, marcada como sugestão, e vai para a fila de revisão.

**D5 Existe categoria que você NÃO quer ver no Painel por padrão (ex.: Pessoal), só quando pedir?**
*Por que:* o Painel abre no que importa.
*Assumo:* tudo visível; Pessoal em bloco separado.

---

## E — O Painel: o que você quer ver

**E1 ⚑ Quando você abrir o Cérebro de manhã, qual é a ÚNICA pergunta que ele tem que responder na primeira tela?**
*Por que:* é o bloco 1 do Painel. Tudo o mais é secundário.
*Assumo:* "Esse mês, em cada negócio, entrou quanto, saiu quanto, sobrou quanto?"

**E2 O período natural para você é mês civil, safra (ex.: jul–jun), ou os dois?**
*Por que:* define o seletor de período e as comparações.
*Assumo:* mês civil com opção de intervalo livre.

**E3 Comparar com o que: mês anterior, mesmo mês do ano passado, média dos últimos 12?**
*Por que:* define os indicadores ao lado de cada número.
*Assumo:* mês anterior e mesmo mês do ano anterior.

**E4 Que alertas você quer que o Painel te dê sem você pedir?** (ex.: fonte silenciosa há 10 dias, mês negativo, saída acima de R$ X, lançamento em revisão há mais de 7 dias)
*Por que:* alerta bom é o que você agiria em cima; alerta ruim vira ruído ignorado.
*Assumo:* fonte silenciosa, itens em revisão, saída acima do teto.

**E5 Gráfico ou tabela? Quando você olha dinheiro, o que te faz entender mais rápido?**
*Por que:* define a forma do bloco "por categoria".
*Assumo:* barras horizontais por categoria, tabela ao clicar.

**E6 O que você quer ver ao clicar num número: a lista de lançamentos, ou direto a linha do arquivo original?**
*Por que:* dois cliques até a origem é a regra (D05); a ordem dos cliques é sua.
*Assumo:* número → lista → linha original.

**E7 A busca livre ("sal mineral") precisa achar dentro dos `extras` (colunas que não mapearam) também?**
*Por que:* busca em jsonb é mais lenta e exige índice específico. Vale se você usar.
*Assumo:* sim, com índice GIN.

**E8 Precisa de modo escuro? Vai usar mais no celular ou no PC?**
*Por que:* define onde caprichar primeiro no layout.
*Assumo:* celular primeiro, tema claro e escuro.

---

## F — Quem usa

**F1 ⚑ Além de você, quem vai abrir o Painel? Esposa, sócio, gerente, contador? Cada um vê o quê?**
*Por que:* define papéis e RLS. Só você = um papel, tudo mais simples.
*Assumo:* só você na v1; contador com acesso somente leitura na v1.1.

**F2 Alguém além de você vai subir arquivo na Tomada?**
*Por que:* se sim, a prévia tem que ser à prova de quem não conhece o sistema.
*Assumo:* só você.

**F3 O contador precisa entrar no sistema ou basta receber a planilha mestre?**
*Por que:* acesso do contador exige papel, convite e tela; planilha exige só o botão exportar.
*Assumo:* planilha.

**F4 Se um dia entrar outro produtor, os dados dele ficam totalmente separados dos seus (multi-tenant desde o dia 1)?**
*Por que:* fazer depois é retrabalho grande; fazer agora custa pouco (`fazenda_id` em tudo + RLS).
*Assumo:* sim, desde o dia 1.

**F5 Login: e-mail + senha, link mágico por e-mail, ou Google?**
*Por que:* Supabase Auth suporta os três; cada um tem um atrito.
*Assumo:* link mágico por e-mail + Google.

---

## G — Aparelhos e canais

**G1 Celular: iPhone ou Android? PC: Windows ou Mac?**
*Por que:* define onde testar upload, PWA e compartilhamento de arquivo.
*Assumo:* iPhone + Windows.

**G2 Onde os arquivos das fontes caem hoje: pasta Downloads, WhatsApp, e-mail, Google Drive?**
*Por que:* o canal certo é o que já está no seu hábito. Se o extrato chega por e-mail, o canal e-mail sobe de prioridade.
*Assumo:* e-mail para banco; Downloads para exports.

**G3 Você usa Google Sheets? Aceitaria manter a planilha da fazenda no Sheets para a Tomada ler sozinha?**
*Por que:* é o canal v1.1 — o mais confortável para planilha própria.
*Assumo:* sim.

**G4 Que e-mail recebe extrato/fatura hoje? Aceitaria criar um encaminhamento automático para um endereço do Cérebro?**
*Por que:* define o canal e-mail (v1.2).
*Assumo:* sim, depois.

**G5 Quer instalar como app na tela inicial (PWA) ou usar no navegador basta?**
*Por que:* PWA exige manifest e service worker; vale se for hábito diário.
*Assumo:* PWA sim.

**G6 Precisa funcionar sem internet? Em que situação real isso aconteceria?**
*Por que:* offline dobra a complexidade da gravação. Só vale se for dor real.
*Assumo:* não na v1; leitura de arquivo já é local, só a gravação precisa de rede.

---

## H — Infra, nome e credenciais

**H1 ⚑ Projeto Supabase: crio um novo (região São Paulo, `sa-east-1`) ou você já tem um para isso? Precisa da sua autorização para criar (tem custo zero no free tier, mas é uma ação na sua conta).**
*Por que:* sem ele não há schema aplicado nem login.
*Assumo:* novo, free tier, `sa-east-1`, criado por você ou por mim via MCP com seu OK.

**H2 Vercel: usa o time atual (`team_Ep4J…`) com um projeto novo `cerebro-rural`?**
*Por que:* deploy do `app/`.
*Assumo:* sim.

**H3 Nome comercial e domínio. "Cérebro Rural" fica? Tem domínio?**
*Por que:* aparece no login, no e-mail de captura, na aba do navegador. Não bloqueia nada; codinome serve.
*Assumo:* Cérebro Rural, sem domínio próprio na v1.

**H4 IA: aceita usar Claude Haiku para sugerir mapa de coluna e categoria (custo estimado < R$ 5/mês no seu volume), ou prefere zero IA na v1?**
*Por que:* é a única dependência externa paga além de Supabase/Vercel.
*Assumo:* sim, Haiku, só onde as heurísticas falham.

**H5 GitHub: o push está bloqueado (o app do Claude não tem acesso ao repositório). Você vai reconectar em claude.ai → Conectores, ou prefere que eu continue entregando por arquivo?**
*Por que:* sem push não há PR, CI nem deploy automático.
*Assumo:* reconecta; até lá, commits locais + arquivos por fora.

**H6 Backup: basta o do Supabase (diário no plano pago, nenhum no free) ou quer que a planilha mestre seja exportada automaticamente para o seu Drive toda semana?**
*Por que:* no free tier não há backup. A exportação semanal para o Drive é backup de graça e ainda é a "planilha mestre viva".
*Assumo:* exportação semanal para o Drive na v1.1.

---

## I — Histórico

**I1 ⚑ Quantos anos para trás você quer carregar na primeira leva? Tem os arquivos?**
*Por que:* define o volume dos primeiros uploads e o teste de performance.
*Assumo:* 2026 inteiro; 2025 se houver arquivo.

**I2 O histórico antigo está em planilha própria, em extrato baixável, ou só no contador?**
*Por que:* extrato antigo às vezes só sai em PDF. Se for o caso, o parser de PDF sobe de prioridade.
*Assumo:* planilha própria + extrato csv.

**I3 Quer que o histórico entre já classificado pela IA (rápido, com revisão depois) ou que entre "sem categoria" e você classifica aos poucos?**
*Por que:* meses de histórico geram centenas de linhas para revisar.
*Assumo:* IA classifica, tudo marcado como sugestão, você revisa por categoria em lote.

**I4 Há algum período que você sabe que está bagunçado e prefere não carregar?**
*Por que:* dado ruim no histórico polui comparação com o ano anterior.
*Assumo:* carrega tudo e marca.

---

## J — O que é "perfeito" para você

**J1 ⚑ Descreva o dia em que você diz "está perfeito". O que você fez, o que viu, quanto tempo levou?**
*Por que:* vira o portão da Fase 4 em `QUALIDADE.md`. Hoje ele diz "três meses fechados sem planilha externa" — quero a sua versão.
*Assumo:* a versão atual.

**J2 O que te irritaria mais: a Tomada perguntar demais, ou classificar errado sem perguntar?**
*Por que:* define o ponto de corte entre automático e revisão.
*Assumo:* classificar errado irrita mais → em dúvida, vai para revisão.

**J3 Quanto tempo por semana você aceita gastar alimentando o Cérebro (subir arquivo, revisar fila)?**
*Por que:* se for 10 minutos, a prévia tem que ser quase automática. Se for 1 hora, pode ser mais detalhada.
*Assumo:* 15 minutos por semana.

**J4 Qual é a primeira coisa que você vai querer adicionar depois que a v1 estiver rodando? (Você disse que vai colocando de trás pra frente — o que vem primeiro?)**
*Por que:* eu deixo a porta aberta para isso no desenho, sem construir agora.
*Assumo:* canal HTTP para o FrigoGest.

---

*Quando uma pergunta for respondida, a resposta vai para `DECISOES.md` (ou vira fixture) e a pergunta sai daqui. Quando este arquivo esvaziar, ele vai para `historico/`.*
