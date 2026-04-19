# Cérebro Rural — ERP do Produtor Brasileiro

> Plataforma SaaS de micro-apps interligados por um Cérebro Central com IA e fluxo de caixa unificado.

---

## O problema que resolve

O produtor rural brasileiro que tem múltiplos negócios — fazenda, gado, imóvel, loja, obras, investimentos — não tem onde ver tudo em um lugar só. Hoje o dinheiro está espalhado: uma planilha aqui, um caderno ali, um WhatsApp com o contador. Ele não sabe no dia a dia se está ficando rico ou quebrando.

Nenhum software existente entende esse perfil. O Quickbooks é gringo. O Conta Azul é pra empresa urbana. Nenhum sabe que o mesmo homem que pesa 40 bois de manhã paga aluguel de imóvel à tarde e ainda tem posição em FII.

---

## A solução

Micro-apps independentes, cada um focado em uma coisa, todos conectados a um Cérebro Central.

O peão registra que usou 3 sacos de sal mineral → já entrou como saída classificada automaticamente.
O fazendeiro pesou 40 bois → o sistema já calculou o valor do lote pelo preço da arroba do dia.
O aluguel venceu → entrou como receita automaticamente.

No fim do mês: relatório pronto pro contador. O produtor nunca tocou em planilha.

---

## Micro-apps do MVP

### Agronegócio
- **Pastagem** — manejo de pastos, rotação, lotação em UA, área em hectares via mapa
- **Almoxarifado** — insumos, ração, vacinas, medicamentos, sal mineral, controle de estoque
- **Calculadora de Boi** — pesagem offline, cálculo de arrobas, valor do lote (já existe, PWA)
- **FrigoGest** — abate, expedição, vendas, margens (já existe)

### Patrimônio e renda
- **Obras** — construções, reformas, materiais, mão de obra
- **Funcionários** — folha, ponto, adiantamento, encargos
- **Aluguel** — imóveis, contratos, recebimentos, inadimplência

### Financeiro pessoal
- **Vida pessoal** — Uber, boletos, compras, despesas do dia a dia
- **Bolsa / FII** — posição, dividendos, aportes

---

## O Cérebro Central

Não é um fluxo de caixa padrão de contabilidade.
É um fluxo que **entende o contexto** — sabe que ração é custo de produção, que arroba vendida é receita de pecuária, que reforma de cerca é capital imobilizado.

### Conector universal (tabela `lancamentos`)
Toda transação de qualquer app passa por aqui:

```
id
fazenda_id
app_origem        → qual micro-app gerou
categoria         → Custo de Produção | Receita | Custo Fixo | Capital | Pessoal
subcategoria      → Insumo | Mão de Obra | Aluguel | Venda de Gado | ...
tipo              → ENTRADA | SAIDA | TRANSFERENCIA
valor
data
descricao
responsavel
status            → confirmado | pendente | cancelado
referencia_id     → ID do registro de origem no app
referencia_tipo   → pastagem | almoxarifado | obra | ...
```

A IA lê essa tabela única e responde qualquer pergunta:
- "Quanto gastei com insumos esse mês?"
- "Qual foi o lucro da última venda de gado?"
- "Meu caixa fecha em agosto?"

### O que o Cérebro entrega
- Posição consolidada de todos os negócios em tempo real
- DRE simples mensal gerado automaticamente
- Relatório exportável (PDF/Excel) pronto pro contador
- Alertas de vencimento, estoque baixo, superlotação de pasto
- Briefing diário por voz ou texto

---

## Arquitetura técnica

- **Frontend**: React + TypeScript (cada micro-app é uma PWA standalone)
- **Backend / banco**: Supabase (banco compartilhado, schema unificado)
- **IA**: Groq (Llama) para agentes de campo, Claude Haiku para orquestrador
- **Deploy**: Vercel (cada app tem sua URL própria)
- **Offline**: cada app funciona sem internet e sincroniza quando conectar

---

## Modelo de negócio (SaaS)

- **Plano base**: Cérebro + 2 módulos — R$ X/mês
- **Módulos adicionais**: R$ Y/mês cada
- **Lógica**: quanto mais negócios o cliente tem, mais módulos ativa, mais paga — e mais depende (dados centralizados = retenção alta)

---

## Testes mínimos por módulo antes de conectar

1. Lança um registro → aparece no fluxo de caixa com tipo correto?
2. Edita o valor → fluxo atualiza em tempo real?
3. Deleta o registro → some do fluxo sem rastro fantasma?
4. IA responde: "quanto gastei com [categoria] esse mês?"

---

## Ordem de construção

1. **Schema Supabase** — tabela `lancamentos` (conector universal) + tabelas de cada módulo
2. **Cérebro** — dashboard de fluxo de caixa + IA básica
3. **Almoxarifado** — primeiro módulo (simples, gera volume de lançamentos)
4. **Pastagem + Calculadora de Boi** — já tem base, refinar e conectar
5. **Obras + Funcionários** — segunda onda
6. **Aluguel + Vida Pessoal** — terceira onda
7. **Bolsa / FII** — última (integração com corretora via API)

---

*Ideia registrada em abril de 2026 — Thiago Oliveira*
*Vitória da Conquista, Bahia*

---

## Formas de entrada de dados (por app)

### 1. Digitação manual
Uso diário. Formulário simples, campo por campo. Funciona offline.

### 2. Importação de arquivo
- Excel (.xlsx) — planilhas do produtor
- CSV — exportação de qualquer sistema
- Google Sheets — link direto ou exportado
- PDF — notas fiscais, boletos, extratos

A IA mapeia as colunas automaticamente, normaliza os dados e lança já classificado no app correto. O produtor não precisa ajustar nada manualmente.

### 3. OCR por câmera
Foto de nota fiscal, cupom fiscal ou boleto → IA lê, extrai valor, data, fornecedor e lança automaticamente.

### Impacto no onboarding
O cliente novo não começa do zero.
Ele importa o histórico que já tem (planilha, caderno fotografado) e entra com dados reais desde o primeiro dia.

---
