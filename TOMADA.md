# A Tomada — como o Cérebro lê qualquer app

> Documento central. Descreve o que a biblioteca `app/src/tomada/` faz, etapa por etapa.
> Se o código fizer diferente do que está aqui, o código vence e este arquivo é corrigido no mesmo commit.

---

## O princípio

Não existe integração com app A, B ou C. Existe **leitura de tabela**. Todo app exporta tabela; a Tomada lê tabela. O que muda de um app para outro é o *layout* — e layout é coisa que se **aprende uma vez e se lembra**.

Três compromissos que não se negociam:

1. **Nada entra duas vezes.** Reenviar o mesmo arquivo, ou um extrato que sobrepõe o anterior, não duplica nada.
2. **Nada entra sem origem.** Todo lançamento sabe de qual arquivo, qual aba e qual linha veio.
3. **Nada entra sem que o humano tenha visto a prévia.** Uma vez por arquivo — não uma vez por linha.

---

## Como o arquivo chega (canais)

| # | Canal | Quando | Como funciona |
|---|---|---|---|
| 1 | **Upload** | v1 | Arrasta o arquivo no painel, do PC ou do celular. A leitura acontece no navegador; o arquivo só sobe depois da confirmação. |
| 2 | **Google Sheets / Drive** | v1.1 | Aponta um link. A Tomada relê sozinha quando a planilha muda. O produtor só mantém a planilha dele viva. |
| 3 | **E-mail** | v1.2 | Endereço próprio por fazenda. Banco e sistemas mandam relatório por e-mail — basta encaminhar. Anexo é lido como upload. |
| 4 | **HTTP** | v1.2 | `POST /ingest` com chave por fonte. Para app próprio (FrigoGest, Calculadora de Boi) mandar direto, sem passar por arquivo. |
| 5 | **WhatsApp** | v1.3 | Anexo enviado ao número da fazenda. Mesmo caminho do e-mail. |

Formatos, em ordem de prioridade: **xlsx**, **csv/tsv**, **ofx** (extrato bancário — o maior volume no Brasil), xls, **xml de NF-e** (100% exato, sem heurística), pdf de extrato (texto, por último).

---

## O pipeline de um arquivo

```
arquivo
  → 1 detectar   (que formato é isso?)
  → 2 abrir      (vira grades: uma por aba)
  → 3 achar tabela   (onde, dentro da aba, está a tabela de verdade?)
  → 4 perfilar   (que tipo tem cada coluna?)
  → 5 mapear     (que coluna é a data, o valor, a descrição?)
  → 6 normalizar (datas, dinheiro, sinal, texto)
  → 7 classificar (que categoria é cada linha?)
  → 8 deduplicar (isso já entrou?)
  → 9 PRÉVIA     (humano vê e confirma)
  → 10 gravar    (com rastro: arquivo, aba, linha)
```

Cada etapa é uma função pura em `app/src/tomada/`, com teste próprio e sem React. A interface só orquestra.

### 1. Detectar

Formato por **magic bytes** primeiro, extensão depois — a extensão mente (`.xls` que é HTML, `.csv` que é `;`-separado com BOM).

- `xlsx`/`xlsm`: zip (`PK\x03\x04`).
- `xls`: `D0 CF 11 E0` (OLE).
- `ofx`: começa com `OFXHEADER` (SGML, v1) ou `<?xml` + `<OFX>` (v2).
- `xml` de NF-e: `<nfeProc` ou `<NFe`.
- `csv`/`tsv`: texto. Detectar **encoding** (UTF-8 com/sem BOM, latin-1 — comum em banco), depois **separador** (`;` é o padrão pt-BR; `,`, `\t`, `|`), contando consistência de campos por linha.

### 2. Abrir

Cada formato vira a mesma coisa: `Grade[]` — uma grade por aba, célula com valor bruto **e** tipo original (número, texto, data serial, fórmula). Sem perder nada.

- xlsx/xls/csv: SheetJS, `cellDates: true`, sem `raw: false` (não formatar — a Tomada formata).
- ofx: parser próprio. OFX v1 é SGML sem fechamento de tag; tolerar `<TAG>valor` sem `</TAG>`. Extrair `STMTTRN`: `DTPOSTED`, `TRNAMT`, `FITID`, `MEMO`, `NAME`, `CHECKNUM`. O `FITID` é o id do banco — vira `referencia_externa` e torna a dedup exata.
- xml NF-e: `emit`, `dest`, `dhEmi`, `vNF`, `nNF`, itens `det/prod`. Tudo estruturado, sem chute.

### 3. Achar a tabela dentro da aba

É aqui que planilha de produtor rural derrota software ingênuo. Casos reais:

- Título nas linhas 1–3 ("FAZENDA BOA VISTA — CONTROLE 2026"), cabeçalho na 4.
- **Totais no rodapé** ("TOTAL", "SOMA", "SALDO") que não são lançamentos.
- Células mescladas no título; colunas vazias no meio; coluna A vazia como margem.
- **Duas tabelas na mesma aba** separadas por linhas em branco (despesas em cima, receitas embaixo).
- Uma aba por mês, mesmo layout.
- Linha de "saldo anterior" no topo do extrato.

Heurística, nesta ordem:

1. **Candidatos a cabeçalho**: linhas com ≥ 3 células de texto não vazias, sem números puros.
2. Para cada candidato, olhar as 5 linhas seguintes: **consistência de tipo por coluna** ≥ 70% → é um cabeçalho de verdade.
3. O bloco vai do cabeçalho até a primeira sequência de 2 linhas vazias, ou até o fim.
4. Cortar do fim as linhas com `total|soma|saldo|subtotal` em qualquer célula de texto, ou linhas com apenas células numéricas.
5. Cortar do início linhas com `saldo anterior|saldo inicial`.
6. Repetir a partir do fim do bloco para achar a próxima tabela.

Sempre devolver **o que foi lido e o que foi ignorado**, com número de linha — a prévia mostra os dois.

### 4. Perfilar colunas

Para cada coluna do bloco, amostra até 200 valores e infere:

| Tipo | Como reconhece |
|---|---|
| `data` | `dd/mm/aaaa`, `dd/mm/aa`, `aaaa-mm-dd`, serial Excel (número entre 30000 e 60000 numa coluna com cabeçalho de data), `10/set`, `10 set 2026`, `setembro/26` |
| `dinheiro` | `R$ 1.234,56`, `1.234,56`, `1234,56`, `(1.234,56)` negativo, `1.234,56-` negativo, `1.234,56 D`, e o formato gringo `1,234.56` quando o export é de sistema americano — decidir pelo **último separador** e pela consistência da coluna |
| `inteiro` | só dígitos |
| `texto` | resto |
| `categoria` | texto com cardinalidade baixa (≤ 30 valores distintos em ≥ 50 linhas) |
| `id` | texto/número com cardinalidade ≈ nº de linhas, sem espaços |
| `flag_dc` | coluna com só `D`/`C`, `Débito`/`Crédito`, `Entrada`/`Saída`, `E`/`S`, `+`/`-` |
| `vazia` | > 95% vazia — ignorada |

**Convenção de sinal** da tabela inteira, detectada a partir do perfil:

- (a) uma coluna `dinheiro` com sinais → negativo é SAÍDA;
- (b) duas colunas `dinheiro` com cabeçalho `débito/crédito`, `saída/entrada`, `pago/recebido` → cada uma define o tipo;
- (c) uma coluna `dinheiro` sempre positiva + uma coluna `flag_dc` → o flag define;
- (d) uma coluna `dinheiro` sempre positiva e nada mais → **perguntar** (é tudo saída? tudo entrada?).

### 5. Mapear colunas para o canônico

O canônico é a linha da planilha mestre:

```
data · tipo (ENTRADA|SAIDA) · valor · descricao · categoria · subcategoria
negocio · contraparte · referencia_externa · extras (o que sobrou, como veio)
```

Três camadas, nesta ordem, parando na primeira que resolve:

1. **Dicionário de sinônimos** (`app/src/tomada/sinonimos.ts`), sem acento e em minúsculas:
   - `data`: `data, dt, dia, vencimento, emissao, competencia, data mov, data lancamento, dtposted`
   - `valor`: `valor, vlr, total, montante, quantia, importancia, trnamt`
   - `descricao`: `descricao, historico, memo, lancamento, detalhe, observacao, item, produto, name`
   - `debito`: `debito, saida, pago, despesa, gasto, retirada`
   - `credito`: `credito, entrada, recebido, receita, deposito`
   - `categoria`: `categoria, conta, natureza, plano de contas, classificacao, grupo, tipo de despesa`
   - `contraparte`: `fornecedor, cliente, favorecido, beneficiario, comprador, vendedor, pagador`
   - `referencia_externa`: `documento, doc, n, numero, nf, nota, ref, id, fitid, codigo`
2. **IA** (Claude Haiku via `supabase/functions/sugerir-mapa`) só para colunas que sobraram sem mapa, recebendo cabeçalho + 5 amostras. Resposta é *sugestão*, marcada como tal.
3. **Humano confirma** na prévia — e essa confirmação vira **template**.

**Template por fonte.** O *fingerprint* de uma tabela é `sha256(cabeçalhos normalizados, em ordem)`. A confirmação do humano grava em `fonte_templates`: fingerprint → mapa de colunas, convenção de sinal, formato de data e de moeda, linhas a ignorar. Próximo arquivo da mesma fonte com o mesmo fingerprint: **zero perguntas**. Fingerprint diferente (o app mudou o export): a Tomada avisa "o layout mudou", mostra o que casou e pergunta só o resto.

### 6. Normalizar

- **Data** → `date` ISO. Sem hora: extrato bancário não tem hora que importe. Ambiguidade `dd/mm` × `mm/dd` é resolvida pela coluna inteira (se algum valor tem primeiro campo > 12, é `dd/mm`; no Brasil, empate → `dd/mm`).
- **Valor** → `numeric(12,2)`, sempre positivo. O sinal vira `tipo`.
- **Tipo** → `ENTRADA` | `SAIDA` pela convenção de sinal detectada. Transferência entre contas do mesmo dono é marcada `SAIDA` + `categoria = Transferência` e o Painel exclui do resultado.
- **Descrição** → trim, espaços colapsados, sem código de agência no meio; a versão *normalizada* (minúscula, sem acento, sem dígitos) é guardada à parte para memória e dedup.
- **Negócio** → herdado da fonte (`fazenda | frigorifico | imoveis | comercio | pessoal | outro`); a linha pode ser reetiquetada na prévia. A conta corrente do produtor mistura tudo — por isso o negócio é da fonte *e* da linha.
- **Extras** → toda coluna que não mapeou para o canônico é guardada em `extras` como veio. Nada se perde.

### 7. Classificar

Categoria e subcategoria, em três camadas, parando na primeira:

1. **Regras da fonte** — `regex` na descrição normalizada → categoria. Ex.: `sal mineral|sal proteinado → Custo Produção / Suplementação`. Editáveis pelo usuário.
2. **Memória** — `classificacao_memoria`: descrição normalizada já classificada antes por um humano nesta fazenda → mesma categoria. Toda correção na prévia ou na revisão grava aqui. Com o tempo, a memória resolve quase tudo.
3. **IA** — só para o que sobrou; resposta marcada `sugerida` e vai para a fila de revisão, não para o caixa definitivo.

Toda linha guarda `classificacao_origem ∈ {regra, memoria, ia, manual}`. O Painel mostra quanto do mês está em cada uma.

### 8. Deduplicar

Três chaves, em ordem:

1. **Hash do arquivo** — `sha256(bytes)`. Igual a um já lido nesta fonte → o arquivo inteiro é no-op, sem nem abrir.
2. **Hash da linha** — `sha256(fonte, data, valor, descricao_normalizada, referencia_externa)`. Igual a um existente → `duplicado`, não grava. É o que faz extrato de 60 dias enviado todo mês só entrar com as linhas novas. Quando há `referencia_externa` forte (FITID do banco, nº da NF), ela entra no hash e a dedup vira exata.
3. **Provável** — mesma fazenda, mesma data, mesmo valor, **fontes diferentes** ou descrição diferente (a venda no FrigoGest e o crédito no banco) → vai para **revisão** com o par apontado. Nunca é rejeitada em silêncio: o humano decide se são a mesma coisa (e uma vira `Transferência`/espelho) ou duas.

### 9. Prévia

Uma tela por arquivo. Mostra:

- o que foi detectado (formato, abas, tabela encontrada, linhas ignoradas e por quê);
- o mapa de colunas aplicado, editável, com a origem de cada decisão (template, sinônimo, IA);
- a tabela normalizada, com cada linha marcada **nova / duplicada / provável / rejeitada**;
- totais por tipo e por negócio;
- um botão: **Gravar N linhas novas**.

Nada é gravado antes desse botão. Depois dele, o que o humano mudou (mapa, sinal, categoria) vira template e memória.

### 10. Gravar

Em uma transação:

- `arquivos` ← metadados + bytes no Storage (bucket privado) — a origem fica guardada;
- `lancamentos` ← as linhas novas, cada uma com `arquivo_id`, `aba`, `linha`, `hash_linha`;
- `ingest_eventos` ← **todas** as linhas, aceitas ou não, com resultado e motivo;
- `revisao` ← as prováveis;
- `fonte_templates` e `classificacao_memoria` ← o que o humano confirmou.

`UNIQUE(fonte_id, hash_linha)` no banco garante a dedup mesmo se dois uploads correrem ao mesmo tempo.

---

## O canal HTTP (para app próprio)

Mesmo pipeline, sem as etapas 1–5: o app manda já no canônico.

```
POST /ingest
Authorization: Bearer cr_live_…

{ "eventos": [ {
    "evento_id": "frigogest:venda:88213",     ← idempotência (vira referencia_externa)
    "data": "2026-09-10",
    "tipo": "ENTRADA",
    "valor": 18400.50,
    "descricao": "Venda 12 cabeças — Frigorífico X",
    "categoria": "Receita", "subcategoria": "Venda de Gado",
    "negocio": "fazenda",
    "extras": { "cabecas": 12, "arrobas": 210.4 }
} ] }
```

Resposta por evento: `aceito | duplicado | revisao | rejeitado`, com motivo. Chave por fonte, guardada só como hash. Rate limit por fonte.

---

## O que a Tomada não faz

- Não corrige o app de origem. Se o export vem errado, a linha vai para revisão com o erro apontado.
- Não inventa valor. Célula vazia em `valor` é linha rejeitada com motivo, nunca zero.
- Não classifica em silêncio. Sugestão de IA é sugestão até um humano confirmar.
- Não grava sem prévia. Nem pelo canal HTTP — lá a "prévia" é a fila de revisão para tudo que não bater 100%.
