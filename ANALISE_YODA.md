# Análise Yoda — Cérebro Rural

> Julgamento frio do projeto, item por item, em loop.
> Cada peça recebe um veredicto: **SERVE**, **SERVE COM CORTE** ou **NÃO SERVE**.
> O que não serve não é apagado — vai para o **corredor da lixeira**, identificado e congelado.
>
> Data do julgamento: 11/09/2026 · Base: commit `cdfb471`

---

## 1. Veredicto em uma frase

*"Uma catedral você construiu. Uma porta, ela não tem."*

**A ideia é boa e o problema é real. O projeto está doente de arquitetura: 7.800 linhas de infraestrutura e schema para um produto que não tem uma única tela funcionando, nenhum usuário e nenhum dado real.**

---

## 2. O que este repositório realmente é (números, não opinião)

| Medida | Valor |
|---|---|
| Commits | 17 |
| Período de atividade | 19/04/2026 → 07/06/2026 |
| **Dias sem commit até hoje** | **~96 dias** |
| Documentação | 28 arquivos `.md`, 3.323 linhas |
| SQL (migrations + seed + testes) | 3.424 linhas · **41 tabelas** |
| Go (host de plugins, gRPC, MCP, agentes) | 4.297 linhas |
| HTML (protótipos estáticos) | 2.633 linhas |
| **React / TypeScript** | **0 arquivos** |
| **package.json no repositório** | **0** |
| Apps de domínio implementados | **0 de 10** |
| Usuários reais | **0** |
| Receita | **R$ 0** |

**Proporção do projeto:** 68% do código é infraestrutura e schema que ninguém usa. 0% é produto que alguém abre.

*"Escrever sobre o app, mais fácil que escrever o app é. Perigoso, isso é."*

---

## 3. As contradições internas (a documentação mente para você)

Um documento que mente é pior que documento nenhum — porque você toma decisão em cima dele.

| # | Contradição | Onde |
|---|---|---|
| C1 | `CONTINUAR.md` diz *"Código: zero linhas escritas ainda (intencionalmente)"* — existem 4.297 linhas de Go e 3.424 de SQL commitadas | `CONTINUAR.md` vs `plugins/`, `supabase/` |
| C2 | `PLANO_ACAO.md` marca *"Schema Supabase ▢ não existe — bloqueador #1"* — existem 9 migrations com 41 tabelas | `PLANO_ACAO.md` vs `supabase/migrations/` |
| C3 | `PLANO_ACAO.md` diz *"Não comece nenhum app de domínio antes da Fase 1"* — e as migrations 0006–0010 já criam schema avançado de pecuária de um app inexistente | `PLANO_ACAO.md` vs `0006_pecuaria_avancada.sql` |
| C4 | Regra *"cada app nasce completo e sozinho"* vs. schema único compartilhado com triggers cruzados — os apps já nascem acoplados pelo banco | `README.md` vs `0003_triggers.sql` |
| C5 | Stack "confirmada" React+Vite+Vercel vs. host Go que precisa de servidor persistente — a Vercel não roda esse processo | `ARQUITETURA.md` vs `plugins/host/` |
| C6 | *"Não invente código antes de documentação estar fechada"* — a regra que produziu 3.323 linhas de doc e 0 linhas de frontend | `CONTINUAR.md`, regra 2 |

**Ação obrigatória antes de qualquer linha nova:** um único `ESTADO.md` gerado a partir do que o `git` mostra, e todos os outros docs passam a ser subordinados a ele. Se doc e código divergirem, o código vence.

---

## 4. Julgamento item por item (o loop)

### 4.1 — Conceito e produto

| Item | Veredicto | Motivo |
|---|---|---|
| Dor: produtor multi-negócio sem visão consolidada | **SERVE** | Dor real, recorrente, cara. Ninguém no Brasil resolve *a consolidação entre negócios rurais e não-rurais do mesmo dono*. |
| Afirmação *"nenhum software existente entende esse perfil"* | **NÃO SERVE** | Falsa como está escrita. Aegro, Ruralbit/Prodap, Gestor Rural, SIAGRI, TOTVS Agro, Agrare, Fazenda Premium existem e atacam o agro. Verdadeiro só no recorte "fazenda + imóvel + loja + pessoal no mesmo caixa". Reescreva a frase ou a tese cai na primeira conversa de venda. |
| Você ser o cliente #1 | **SERVE — é o maior ativo do projeto** | Você tem fazenda, gado, frigorífico e a dor. Isso é o que 99% dos concorrentes não tem. Está sendo desperdiçado construindo host gRPC. |
| Ser "ERP" | **SERVE COM CORTE** | ERP é promessa de 5 anos. Venda "caixa consolidado + relatório do contador". ERP é o que vira depois, não o que se anuncia. |
| 9 a 10 micro-apps no MVP | **NÃO SERVE** | 10 apps é 10 produtos. Nenhum solo part-time entrega isso. MVP = 1 app + o consolidado. |
| Módulo Bolsa/FII | **NÃO SERVE (agora)** | Zero relação com a cunha. Existem 20 apps grátis melhores. Não retém, não diferencia, não vende. |
| Módulo Vida Pessoal | **NÃO SERVE (agora)** | Mesmo caso. Vira ruído no DRE e concorre com Mobills/Organizze. |
| Módulo Pastagem com desenho de polígono em mapa | **SERVE COM CORTE** | Bonito de demo, caro de fazer, não gera lançamento financeiro (o próprio roadmap admite). Adia. |
| Calculadora de Boi (já existe, PWA) | **SERVE** | Já funciona, já tem uso real. É o único ativo de produto validado. Deveria ser o ponto de partida, não o item 3 da onda 2. |
| FrigoGest | **SERVE COMO FONTE DE DADOS** | Não migre. Só leia. |
| Importação de Excel/planilha do produtor no onboarding | **SERVE — é a cunha comercial** | O produtor já tem histórico. Quem importa o passado dele ganha o cliente. Isso é mais valioso que 5 módulos novos. |
| OCR de foto de nota fiscal no MVP | **NÃO SERVE** | Caro, erra, frustra. **XML da NF-e é 100% exato e de graça** — e está enterrado em `IDEIAS_FUTURAS.md`. Prioridade invertida. |
| Briefing diário por voz | **NÃO SERVE** | Demo de feira. Ninguém cancela assinatura por falta de voz. |

### 4.2 — Arquitetura

| Item | Veredicto | Motivo |
|---|---|---|
| Tabela única `lancamentos` como conector (D02) | **SERVE — é o coração certo** | Simples, auditável, consultável, uma tabela para a IA ler. Decisão madura. Mantém. |
| Um projeto Vercel e uma URL por micro-app | **NÃO SERVE** | 10 deploys, 10 PWAs para instalar, 10 sessões, navegação quebrada entre apps, custo de manutenção multiplicado por 10. Um app, rotas por módulo, permissão por papel. |
| "Nenhum micro-app exibe fluxo de caixa próprio" (regra de ouro) | **NÃO SERVE** | Arbitrário. O gerente do almoxarifado quer saber quanto gastou no mês, ali. Você está criando fricção para proteger uma regra estética. |
| Offline-first (IndexedDB + service worker) | **SERVE** | Restrição real de campo. Mas custa caro: implemente em **1 tela** (lançamento rápido), não no app inteiro. |
| PWA em vez de nativo (D08) | **SERVE** | Correto para o estágio. |
| Supabase + RLS + Vercel | **SERVE** | Pragmático, é a stack que você domina. Não troque. |
| **Host Go + go-plugin + gRPC (`plugins/host/`, 4.297 linhas)** | **NÃO SERVE — o maior desperdício do projeto** | Resolve "plugins multi-linguagem de terceiros". Você não tem terceiros. Não tem clientes. E não tem onde rodar isso: Vercel não hospeda processo persistente, então exige mais um servidor, mais ops, mais custo, mais superfície de falha. Um endpoint serverless de 40 linhas faz hoje o que esse host faz. |
| Camada MCP + 9 provedores LLM + 5 sub-agentes + orquestrador | **NÃO SERVE** | Infraestrutura para parecer moderno. v1 precisa de **1 modelo, 1 prompt, 1 rota**. |
| Adaptador `docs` (xlsx/csv/pdf) | **SERVE — mas no lugar errado** | A capacidade é ouro (é a cunha de importação). O empacotamento como plugin gRPC é que não serve. Reescreva como função serverless com SheetJS. |
| Migrations 0001–0004 (base, almoxarifado, triggers, RLS) | **SERVE** | Fundação sólida e utilizável. |
| Migrations 0006–0010 (pecuária avançada: SISBOV, GTA, estação reprodutiva, timeline, custos alocados — 1.400+ linhas) | **NÃO SERVE (agora)** | Schema de um app que não tem uma única tela. Schema sem UI é ficção: **vai mudar 100% quando a primeira tela existir**. Congela. |
| 41 tabelas antes do primeiro usuário | **NÃO SERVE** | Sintoma clássico. Um cliente real quebra metade desse modelo na primeira semana. |
| Protótipos HTML v2/v3/mobile | **SERVE COMO REFERÊNCIA** | Úteis para definir visual. Não são produto e não devem receber mais uma linha. |

### 4.3 — Integridade e dados

| Item | Veredicto | Motivo |
|---|---|---|
| Ideia de barrar dado ruim antes de gravar | **SERVE — é diferencial real** | Relatório financeiro com duplicata silenciosa mata a confiança e o contrato. Certíssimo. |
| Checkpoint 1 — validação de formato | **SERVE** | Barato e obrigatório. |
| Checkpoint 2 — hash de duplicata + chave única por contexto | **SERVE — é o mais valioso dos cinco** | É o que salva o relatório do contador. |
| Checkpoint 3 — IA pergunta em ambiguidade | **SERVE COM CORTE** | Só na importação em lote. No lançamento manual vira chateação diária. |
| Checkpoint 4 — anomalia estatística | **NÃO SERVE (agora)** | Você não tem histórico para fazer estatística. Anomalia sobre 12 lançamentos é chute. Volta quando tiver 6 meses de dado. |
| Checkpoint 5 — confirmação humana | **SERVE COM CORTE** | Confirmar tudo, todo dia, mata o uso. Confirme só importação, OCR e valor acima de um limite. |
| "5 checkpoints obrigatórios em TODA entrada" | **NÃO SERVE** | O dogma transforma um app de campo num cartório. v1 = checkpoints 1, 2 e confirmação seletiva. |
| Auditoria em tabela própria | **SERVE** | Barato e indispensável em produto financeiro. |
| RLS obrigatório | **SERVE** | Inegociável. Correto. |

### 4.4 — Negócio

| Item | Veredicto | Motivo |
|---|---|---|
| SaaS por assinatura | **SERVE** | Modelo certo para o problema. |
| Preço "base + R$ por módulo" | **NÃO SERVE** | Cobra por complexidade, não por valor. O valor está na consolidação (a base). O cliente ativa 1 módulo, nunca vê o cérebro, não percebe valor e cancela. Cobre por **fazenda/CNPJ ou por volume**, com tudo liberado. |
| Nome comercial indefinido | **NÃO SERVE COMO BLOQUEIO** | Está listado como decisão pendente desde abril. Isso não bloqueia nada. Decida em 10 minutos ou fique com o codinome. |
| Critério "pronto pra cobrar" = 5 itens incluindo 90 dias de uso próprio | **SERVE COM CORTE** | O espírito é correto (dogfooding). 90 dias antes de cobrar de qualquer um é longo demais. 30 dias de uso próprio + 1 amigo pagando R$ 50 já valida mais. |
| Marketplace, comparador anonimizado entre fazendas, portal do contador, carbono/ESG | **NÃO SERVE** | Todos exigem 50–100 fazendas ativas. Você tem 0. É planejar a decoração do décimo andar sem fundação. |
| Parceria com cooperativa | **SERVE COMO HIPÓTESE** | Canal plausível e barato de testar — uma conversa. Mas só depois de ter o que mostrar. |
| Versão "peão" gratuita | **SERVE** | Dono paga, peão usa. Estratégia de adoção correta. |
| Onboarding assistido pago | **SERVE** | Receita imediata, e te coloca dentro dos dados do cliente. Provavelmente seu primeiro R$ de verdade. |
| Estimativa de 7 meses part-time até vender | **NÃO SERVE** | Otimista por um fator de 2 a 3 — e já se passaram ~5 meses desde abril com o frontend em zero. Assuma 18 meses no plano atual, ou corte o escopo em 10x. |

### 4.5 — Processo

| Item | Veredicto | Motivo |
|---|---|---|
| Registrar decisões em `DECISOES.md` | **SERVE** | Ótima prática, bem executada. |
| `IDEIAS_FUTURAS.md` como parking lot | **SERVE** | Impede que ideia nova vire tarefa. Mantém. |
| Regra "não codar antes da documentação fechar" | **NÃO SERVE — é a causa raiz da paralisia** | Documentação nunca "fecha". Essa regra é o que produziu 96 dias de silêncio. Inverta: **código primeiro, doc do que já existe depois**. |
| Regra "UI zerada, não reaproveitar componente de outro projeto" | **NÃO SERVE** | Desperdício puro. Você tem componentes funcionando no FrigoGest e na Calculadora. Reaproveitar economiza semanas e não custa nada. |
| `TESTES.md` com testes mínimos por módulo | **SERVE** | Critério de pronto objetivo. Raro e valioso. |
| 28 arquivos de documentação | **NÃO SERVE** | Você já não consegue mantê-los coerentes (ver seção 3). Alvo: **6 documentos vivos**. |

---

## 5. O núcleo que SERVE (guarde e defenda)

1. A dor real do produtor multi-negócio.
2. Você ser o cliente zero, com dados reais desde o dia 1.
3. A tabela `lancamentos` como conector universal.
4. Importar o histórico do cliente (Excel/planilha) como cunha de entrada.
5. Anti-duplicata + validação de formato (a parte útil da Camada de Integridade).
6. Supabase + RLS + PWA + Vercel.
7. Conhecimento de domínio real: @ = 15 kg, custo médio ponderado, os 3 modos da pesagem, GTA, sal mineral, lote, pasto. **Isso não se compra e nenhum concorrente de São Paulo tem.**
8. Calculadora de Boi funcionando com uso real.
9. Migrations 0001–0004.
10. A disciplina de `DECISOES.md` e `TESTES.md`.

*"Pequeno o núcleo é. Mas nele, tudo que vive está."*

---

## 6. 🗑️ AO LADO DA LIXEIRA

> Não apague. Mova para `_arquivo/` com um `README` de uma linha dizendo por que saiu e o que faria voltar.
> Está do **lado** da lixeira para você reconhecer na hora que bater a vontade de voltar a mexer.

| # | Peça | Tamanho | Por que não serve | O que a traria de volta |
|---|---|---|---|---|
| L01 | Host Go + go-plugin + gRPC | 4.297 linhas | Resolve problema de terceiros que não existem; não roda na stack escolhida | Um parceiro externo querendo escrever módulo em outra linguagem |
| L02 | Camada MCP + 9 provedores LLM + 5 sub-agentes + orquestrador | dentro de L01 | v1 precisa de 1 modelo e 1 prompt | Custo de IA virar >10% da receita, aí sim vale roteador |
| L03 | Migrations 0006–0010 (pecuária avançada) | 1.620 linhas | Schema de app sem tela; vai mudar inteiro | A primeira tela de manejo existir e pedir esses campos |
| L04 | Checkpoint 4 — anomalia estatística | doc | Sem histórico não há estatística | 6 meses de lançamentos reais |
| L05 | Dogma "5 checkpoints em toda entrada" | doc | Transforma app de campo em cartório | Nunca como dogma; volta como regra por tipo de entrada |
| L06 | Um deploy/URL por micro-app | arquitetura | 10x manutenção, navegação e login quebrados | Um módulo virar produto vendido separadamente |
| L07 | Regra "nenhum app mostra caixa próprio" | arquitetura | Fricção estética contra o usuário | Nunca |
| L08 | Módulo Bolsa/FII | spec | Fora da cunha, concorrência grátis e melhor | Cliente pagante pedir explicitamente |
| L09 | Módulo Vida Pessoal | spec | Fora da cunha | Idem |
| L10 | Mapa com desenho de polígono (Pastagem) | spec | Caro, não gera lançamento | Depois do caixa consolidado funcionar |
| L11 | OCR de nota fiscal no MVP | spec | Caro e impreciso; XML da NF-e resolve melhor e de graça | Nota sem XML (cupom, recibo de feira) virar >30% dos gastos |
| L12 | Briefing por voz / Web Speech / jargão rural | spec | Demo, não retenção | Depois de 100 clientes |
| L13 | Sync P2P Bluetooth entre celulares | spec | Complexidade altíssima, ganho marginal | Nunca, na prática |
| L14 | Alertas por SMS | spec | Custo por mensagem, WhatsApp resolve | Cliente sem sinal de dados reclamar de verdade |
| L15 | Marketplace / comparador entre fazendas / portal do contador / carbono-ESG | spec | Exigem 50–100 fazendas ativas | 50 fazendas ativas |
| L16 | Preço "base + módulos" | modelo | Cobra complexidade, esconde o valor | Teste de preço mostrar o contrário |
| L17 | Regra "não codar antes da doc fechar" + "UI zerada" | processo | Causa direta da paralisia e do retrabalho | Nunca |
| L18 | 22 dos 28 arquivos `.md` | 3.323 linhas | Já se contradizem; custo de manutenção > valor | Nada. Consolidar em 6. |

**Soma do que vai para o lado da lixeira: ~6.000 linhas de código e schema, e a maior parte da documentação.**
Isso não é fracasso — é o preço já pago de uma aula. O erro seria continuar pagando.

---

## 7. Os 5 erros de fundo (o diagnóstico, não os sintomas)

1. **Fuga para o confortável.** Escrever host gRPC é divertido e sem risco de rejeição. Botar uma tela na frente de um produtor é desconfortável e pode doer. Você escolheu o divertido por 5 meses.
2. **Arquitetura como procrastinação.** Toda decisão de plataforma tomada antes do primeiro usuário é chute caro.
3. **Escopo como identidade.** 10 apps soam grandes. Grande não é forte: grande é lento.
4. **Documentação como prova de progresso.** 3.323 linhas de doc criam a sensação de avanço sem nenhum avanço verificável.
5. **Nenhum critério de morte.** Não existe no repositório uma única linha dizendo "se X não acontecer até Y, eu paro". Projeto sem condição de parada não é aposta, é hobby caro.

---

## 8. O erro factual mais caro do projeto

Toda a documentação promete **"DRE mensal pronto pro contador"**.

Produtor rural pessoa física **não apura por DRE**. A obrigação dele é o **Livro Caixa do Produtor Rural** — e, acima do limite de receita bruta anual definido pela Receita, o **LCDPR (Livro Caixa Digital do Produtor Rural)**, entregue em layout próprio via SPED, com Anexo do demonstrativo e classificação por conta de fazenda/imóvel rural.

Consequências:
- O entregável que você está prometendo é o entregável errado para boa parte do público.
- E, ao mesmo tempo, **aqui está o maior diferencial não explorado do projeto**: exportar o arquivo do LCDPR pronto, por imóvel rural, a partir dos lançamentos. Isso é dor aguda, anual, com multa — e quase nenhum app pequeno entrega.

**Ação:** confirme o enquadramento com um contador rural (1 hora, hoje) e troque "DRE" por "Livro Caixa / LCDPR" em toda a documentação e no discurso de venda. Mantenha o DRE apenas para os negócios pessoa jurídica (frigorífico, loja).

---

## 9. A pergunta que o projeto inteiro está evitando

**Alguém que não é você já pediu isso, e quanto pagaria?**

Não existe no repositório, em 28 documentos, uma única linha de conversa com um produtor que não seja você. Nem um nome. Nem uma objeção ouvida. Nem um preço testado.

Enquanto isso não existir, tudo aqui — inclusive esta análise — é opinião sobre opinião.

---

## 10. O recorte que eu defenderia (30 dias, não 7 meses)

**Produto:** *"Você joga sua planilha aqui e eu te digo quanto você ganhou e gastou no mês, por negócio."*

| Semana | Entrega |
|---|---|
| 0 (2 dias) | `_arquivo/` criado, L01–L18 congelados, `ESTADO.md` escrito, 28 docs → 6 |
| 1 | Um app Vite+React+Supabase. Login, `lancamentos` CRUD, lista filtrável. Migrations 0001–0004 apenas. |
| 2 | Importar `.xlsx`/`.csv` → mapeamento de coluna com IA → preview editável → gravação em lote com anti-duplicata. **É a cunha.** |
| 3 | Painel: saldo, entradas, saídas por categoria, por negócio, 12 meses. Exportar CSV + PDF. |
| 4 | Você carrega **3 anos do seu próprio histórico real**. Fecha um mês de verdade sem planilha. Mostra para 5 produtores da região e anota o que eles falam, palavra por palavra. |

**Depois disso, e só depois:** 1 módulo de entrada de dado — e o candidato certo é o Almoxarifado (volume diário, simples) ou a Calculadora de Boi (já existe).

O que fica de fora nos 30 dias: offline, OCR, voz, 9 apps, plugin host, MCP, pastagem, mapa, billing, marketplace.

---

## 11. Critério de morte (escreva isso e assine)

Sem isso, você vai ficar mais 5 meses.

- Se em **30 dias** não houver um app no ar onde você lance dado real → o problema não é escopo, é tempo disponível. Reveja a vida, não o roadmap.
- Se em **60 dias** você não tiver usado o próprio produto para fechar 1 mês sem planilha → o produto não resolve nem a sua dor. Pare.
- Se em **90 dias** nenhum produtor além de você tiver pedido acesso depois de ver → não existe mercado no recorte atual. Mude o recorte ou pare.
- Se em **180 dias** ninguém tiver pago R$ 1 → é hobby. Hobby é legítimo. Mas pare de chamar de startup e pare de otimizar arquitetura.

---

## 12. Última palavra

*"Fazer, ou não fazer. Documentar, não existe."*

O projeto não morre por falta de ideia — a ideia é boa e a dor é verdadeira.
Morre por excesso de preparação e ausência de contato com a realidade.

**O antídoto é uma tela feia no ar com dado seu dentro, esta semana.**

---

*Julgamento produzido por análise integral do repositório. As 200 perguntas que sustentam este veredicto estão em [`QUESTIONARIO.md`](./QUESTIONARIO.md).*
