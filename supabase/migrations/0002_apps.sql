-- ============================================================
-- Cérebro Rural — Migration 0002: Tabelas dos apps de domínio
-- Almoxarifado, Pastagem, Obras, Funcionários, Aluguel,
-- Manejo de Gado, Vida Pessoal, Bolsa/FII
-- ============================================================

-- ############################################################
-- APP: ALMOXARIFADO
-- ############################################################

CREATE TABLE almox_itens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  nome            text NOT NULL,
  codigo_interno  text,
  categoria       text NOT NULL DEFAULT 'Outros'
                  CHECK (categoria IN (
                    'Ração e suplementos', 'Sal mineral', 'Vacinas',
                    'Medicamentos', 'Vermífugos', 'Ferramentas',
                    'Peças e reposição', 'Combustível', 'Lubrificantes',
                    'Material de construção', 'EPI', 'Material de escritório',
                    'Produtos de limpeza', 'Outros'
                  )),
  unidade         text NOT NULL DEFAULT 'un'
                  CHECK (unidade IN ('kg', 'g', 'L', 'mL', 'un', 'saco', 'caixa', 'm', 'rolo', 'par', 'dose')),
  marca           text,
  saldo           numeric(10,3) NOT NULL DEFAULT 0,
  saldo_minimo    numeric(10,3),
  custo_medio     numeric(12,2) NOT NULL DEFAULT 0,
  localizacao     text,
  foto_url        text,
  validade        date,
  ativo           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE almox_itens IS 'Cadastro de itens do almoxarifado da fazenda';

CREATE INDEX idx_almox_itens_fazenda   ON almox_itens(fazenda_id);
CREATE INDEX idx_almox_itens_categoria ON almox_itens(fazenda_id, categoria);
CREATE INDEX idx_almox_itens_saldo     ON almox_itens(fazenda_id) WHERE saldo <= saldo_minimo AND ativo = true;

CREATE TABLE almox_fornecedores (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  nome            text NOT NULL,
  cnpj_cpf        text,
  telefone        text,
  endereco        text,
  observacoes     text,
  ativo           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_almox_fornecedores_fazenda ON almox_fornecedores(fazenda_id);

CREATE TABLE almox_setores (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  nome            text NOT NULL,
  tipo            text DEFAULT 'geral'
                  CHECK (tipo IN ('pasto', 'curral', 'sede', 'casa_func', 'galpao', 'obra', 'geral', 'consumo_proprio')),
  ativo           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_almox_setores_fazenda ON almox_setores(fazenda_id);

CREATE TABLE almox_movimentos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  item_id         uuid NOT NULL REFERENCES almox_itens(id) ON DELETE RESTRICT,
  tipo            text NOT NULL CHECK (tipo IN ('ENTRADA', 'SAIDA', 'AJUSTE', 'TRANSFERENCIA')),
  quantidade      numeric(10,3) NOT NULL CHECK (quantidade > 0),
  valor_unitario  numeric(12,2),
  valor_total     numeric(12,2),
  data            timestamptz NOT NULL DEFAULT now(),
  fornecedor_id   uuid REFERENCES almox_fornecedores(id),
  numero_nota     text,
  foto_nota_url   text,
  forma_pagamento text CHECK (forma_pagamento IN ('dinheiro', 'prazo', 'cartao', 'boleto', 'pix', NULL)),
  setor_destino_id uuid REFERENCES almox_setores(id),
  setor_origem_id  uuid REFERENCES almox_setores(id),
  responsavel     uuid REFERENCES profiles(id),
  liberador       uuid REFERENCES profiles(id),
  motivo          text,
  observacao      text,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE almox_movimentos IS 'Toda movimentação de estoque — gera lançamento automático via trigger';

CREATE INDEX idx_almox_mov_fazenda     ON almox_movimentos(fazenda_id, data DESC);
CREATE INDEX idx_almox_mov_item        ON almox_movimentos(item_id, data DESC);
CREATE INDEX idx_almox_mov_tipo        ON almox_movimentos(fazenda_id, tipo);

-- ############################################################
-- APP: PASTAGEM
-- ############################################################

CREATE TABLE pastos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  nome            text NOT NULL,
  area_ha         numeric(8,2) NOT NULL CHECK (area_ha > 0),
  ua_por_ha       numeric(5,2) NOT NULL DEFAULT 1,
  capacidade_ua   numeric(8,2) GENERATED ALWAYS AS (area_ha * ua_por_ha) STORED,
  poligono_geojson jsonb,
  forrageira      text,
  status          text NOT NULL DEFAULT 'ativo'
                  CHECK (status IN ('ativo', 'descanso', 'interditado', 'em_formacao')),
  dias_descanso   integer,
  ultimo_pastejo  timestamptz,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE pastos IS 'Cadastro de pastos com geolocalização e cálculo de UA';

CREATE INDEX idx_pastos_fazenda ON pastos(fazenda_id);
CREATE INDEX idx_pastos_status  ON pastos(fazenda_id, status);

CREATE TABLE pastagem_lotes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  pasto_id        uuid NOT NULL REFERENCES pastos(id) ON DELETE RESTRICT,
  nome_lote       text,
  quantidade      integer NOT NULL CHECK (quantidade > 0),
  peso_medio_kg   numeric(8,2),
  data_entrada    timestamptz NOT NULL DEFAULT now(),
  data_saida      timestamptz,
  observacao      text,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_past_lotes_pasto    ON pastagem_lotes(pasto_id);
CREATE INDEX idx_past_lotes_ativo    ON pastagem_lotes(fazenda_id) WHERE data_saida IS NULL;

-- ############################################################
-- APP: MANEJO DE GADO
-- ############################################################

CREATE TABLE gado_lotes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  nome            text NOT NULL,
  categoria       text CHECK (categoria IN ('cria', 'recria', 'engorda', 'reprodução', 'descarte')),
  quantidade      integer NOT NULL DEFAULT 0,
  pasto_atual_id  uuid REFERENCES pastos(id),
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_gado_lotes_fazenda ON gado_lotes(fazenda_id);

CREATE TABLE gado_animais (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  lote_id         uuid REFERENCES gado_lotes(id),
  brinco          text,
  nome            text,
  sexo            text CHECK (sexo IN ('M', 'F')),
  raca            text,
  data_nascimento date,
  peso_atual_kg   numeric(8,2),
  status          text NOT NULL DEFAULT 'ativo'
                  CHECK (status IN ('ativo', 'vendido', 'morto', 'transferido')),
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_gado_animais_fazenda ON gado_animais(fazenda_id);
CREATE INDEX idx_gado_animais_lote    ON gado_animais(lote_id);

CREATE TABLE gado_pesagens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  animal_id       uuid REFERENCES gado_animais(id),
  lote_id         uuid REFERENCES gado_lotes(id),
  peso_kg         numeric(8,2) NOT NULL CHECK (peso_kg > 0),
  data            timestamptz NOT NULL DEFAULT now(),
  observacao      text,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_gado_pesagens_animal ON gado_pesagens(animal_id, data DESC);
CREATE INDEX idx_gado_pesagens_lote   ON gado_pesagens(lote_id, data DESC);

CREATE TABLE gado_vacinacoes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  lote_id         uuid REFERENCES gado_lotes(id),
  animal_id       uuid REFERENCES gado_animais(id),
  vacina          text NOT NULL,
  dose            text,
  data_aplicacao  timestamptz NOT NULL DEFAULT now(),
  proxima_dose    date,
  responsavel     uuid REFERENCES profiles(id),
  custo_total     numeric(12,2),
  observacao      text,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE gado_vacinacoes IS 'Vacina aplicada → gera lançamento SAIDA em Custo Produção · Sanidade';

CREATE INDEX idx_gado_vac_fazenda ON gado_vacinacoes(fazenda_id, data_aplicacao DESC);
CREATE INDEX idx_gado_vac_prox    ON gado_vacinacoes(proxima_dose) WHERE proxima_dose IS NOT NULL;

-- ############################################################
-- APP: OBRAS
-- ############################################################

CREATE TABLE obras (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  nome            text NOT NULL,
  tipo            text CHECK (tipo IN ('cerca', 'curral', 'galpao', 'poco', 'casa', 'estrada', 'represa', 'outro')),
  descricao       text,
  data_inicio     date,
  data_prevista   date,
  data_conclusao  date,
  status          text NOT NULL DEFAULT 'planejamento'
                  CHECK (status IN ('planejamento', 'em_andamento', 'pausada', 'concluida', 'cancelada')),
  orcamento       numeric(12,2),
  valor_gasto     numeric(12,2) NOT NULL DEFAULT 0,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_obras_fazenda ON obras(fazenda_id);
CREATE INDEX idx_obras_status  ON obras(fazenda_id, status);

CREATE TABLE obras_medicoes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  obra_id         uuid NOT NULL REFERENCES obras(id) ON DELETE RESTRICT,
  data            timestamptz NOT NULL DEFAULT now(),
  descricao       text NOT NULL,
  valor           numeric(12,2) NOT NULL CHECK (valor > 0),
  fornecedor      text,
  responsavel     uuid REFERENCES profiles(id),
  foto_url        text,
  aprovada        boolean NOT NULL DEFAULT false,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE obras_medicoes IS 'Medição aprovada → gera lançamento SAIDA em Capital';

CREATE INDEX idx_obras_med_obra ON obras_medicoes(obra_id, data DESC);

-- ############################################################
-- APP: FUNCIONÁRIOS
-- ############################################################

CREATE TABLE funcionarios (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  nome            text NOT NULL,
  cpf             text,
  cargo           text,
  salario_base    numeric(12,2),
  data_admissao   date,
  data_demissao   date,
  telefone        text,
  ativo           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_func_fazenda ON funcionarios(fazenda_id);
CREATE INDEX idx_func_ativos  ON funcionarios(fazenda_id) WHERE ativo = true;

CREATE TABLE folha_pagamento (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  funcionario_id  uuid NOT NULL REFERENCES funcionarios(id) ON DELETE RESTRICT,
  competencia     date NOT NULL,
  salario_bruto   numeric(12,2) NOT NULL,
  descontos       numeric(12,2) NOT NULL DEFAULT 0,
  valor_liquido   numeric(12,2) NOT NULL,
  encargos        numeric(12,2) NOT NULL DEFAULT 0,
  data_pagamento  timestamptz,
  status          text NOT NULL DEFAULT 'pendente'
                  CHECK (status IN ('pendente', 'pago', 'cancelado')),
  observacao      text,
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_folha_func_competencia UNIQUE (funcionario_id, competencia)
);

COMMENT ON TABLE folha_pagamento IS 'Folha fechada → gera lançamento SAIDA em Custo Fixo por funcionário';

CREATE INDEX idx_folha_fazenda ON folha_pagamento(fazenda_id, competencia DESC);

CREATE TABLE funcionarios_adiantamentos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  funcionario_id  uuid NOT NULL REFERENCES funcionarios(id) ON DELETE RESTRICT,
  valor           numeric(12,2) NOT NULL CHECK (valor > 0),
  data            timestamptz NOT NULL DEFAULT now(),
  motivo          text,
  descontado_em   uuid REFERENCES folha_pagamento(id),
  criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_adianta_func ON funcionarios_adiantamentos(funcionario_id, data DESC);

-- ############################################################
-- APP: ALUGUEL
-- ############################################################

CREATE TABLE imoveis (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  nome            text NOT NULL,
  endereco        text,
  tipo            text CHECK (tipo IN ('casa', 'comercial', 'terra', 'sala', 'galpao', 'outro')),
  valor_aluguel   numeric(12,2),
  ativo           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_imoveis_fazenda ON imoveis(fazenda_id);

CREATE TABLE contratos_aluguel (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  imovel_id       uuid NOT NULL REFERENCES imoveis(id) ON DELETE RESTRICT,
  inquilino_nome  text NOT NULL,
  inquilino_doc   text,
  inquilino_tel   text,
  data_inicio     date NOT NULL,
  data_fim        date,
  valor           numeric(12,2) NOT NULL,
  dia_vencimento  integer NOT NULL CHECK (dia_vencimento BETWEEN 1 AND 31),
  reajuste_tipo   text CHECK (reajuste_tipo IN ('igpm', 'ipca', 'fixo', NULL)),
  ativo           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_contratos_imovel ON contratos_aluguel(imovel_id);
CREATE INDEX idx_contratos_ativos ON contratos_aluguel(fazenda_id) WHERE ativo = true;

CREATE TABLE recebimentos_aluguel (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  contrato_id     uuid NOT NULL REFERENCES contratos_aluguel(id) ON DELETE RESTRICT,
  competencia     date NOT NULL,
  valor_previsto  numeric(12,2) NOT NULL,
  valor_recebido  numeric(12,2),
  data_recebimento timestamptz,
  status          text NOT NULL DEFAULT 'pendente'
                  CHECK (status IN ('pendente', 'recebido', 'atrasado', 'cancelado')),
  observacao      text,
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_receb_contrato_comp UNIQUE (contrato_id, competencia)
);

COMMENT ON TABLE recebimentos_aluguel IS 'Recebimento confirmado → gera lançamento ENTRADA em Receita Patrimônio';

CREATE INDEX idx_receb_fazenda ON recebimentos_aluguel(fazenda_id, competencia DESC);
CREATE INDEX idx_receb_status  ON recebimentos_aluguel(status) WHERE status IN ('pendente', 'atrasado');

-- ############################################################
-- APP: VIDA PESSOAL
-- ############################################################

CREATE TABLE gastos_pessoais (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  categoria       text NOT NULL DEFAULT 'Outros'
                  CHECK (categoria IN (
                    'Alimentação', 'Transporte', 'Moradia', 'Saúde',
                    'Lazer', 'Educação', 'Vestuário', 'Mercado',
                    'Uber', 'Assinaturas', 'Outros'
                  )),
  descricao       text,
  valor           numeric(12,2) NOT NULL CHECK (valor > 0),
  data            timestamptz NOT NULL DEFAULT now(),
  responsavel     uuid REFERENCES profiles(id),
  criado_em       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE gastos_pessoais IS 'Gasto pessoal → gera lançamento SAIDA em Pessoal';

CREATE INDEX idx_gastos_pessoais_fazenda ON gastos_pessoais(fazenda_id, data DESC);

-- ############################################################
-- APP: BOLSA / FII
-- ############################################################

CREATE TABLE investimentos_posicoes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  ticker          text NOT NULL,
  tipo            text NOT NULL CHECK (tipo IN ('acao', 'fii', 'etf', 'renda_fixa', 'cripto', 'outro')),
  quantidade      numeric(12,4) NOT NULL DEFAULT 0,
  custo_medio     numeric(12,4) NOT NULL DEFAULT 0,
  custo_total     numeric(14,2) GENERATED ALWAYS AS (quantidade * custo_medio) STORED,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_posicao_ticker UNIQUE (fazenda_id, ticker)
);

CREATE INDEX idx_invest_pos_fazenda ON investimentos_posicoes(fazenda_id);

CREATE TABLE investimentos_proventos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  posicao_id      uuid NOT NULL REFERENCES investimentos_posicoes(id) ON DELETE RESTRICT,
  tipo            text NOT NULL CHECK (tipo IN ('dividendo', 'jcp', 'rendimento', 'aluguel', 'amortizacao')),
  valor           numeric(12,2) NOT NULL CHECK (valor > 0),
  data            date NOT NULL,
  observacao      text,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE investimentos_proventos IS 'Provento recebido → gera lançamento ENTRADA em Receita Investimento';

CREATE INDEX idx_invest_prov_fazenda ON investimentos_proventos(fazenda_id, data DESC);
CREATE INDEX idx_invest_prov_posicao ON investimentos_proventos(posicao_id, data DESC);

CREATE TABLE investimentos_aportes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  posicao_id      uuid NOT NULL REFERENCES investimentos_posicoes(id) ON DELETE RESTRICT,
  tipo            text NOT NULL CHECK (tipo IN ('compra', 'venda')),
  quantidade      numeric(12,4) NOT NULL CHECK (quantidade > 0),
  preco_unitario  numeric(12,4) NOT NULL CHECK (preco_unitario > 0),
  valor_total     numeric(14,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED,
  data            date NOT NULL,
  corretora       text,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_invest_aporte_posicao ON investimentos_aportes(posicao_id, data DESC);

-- ############################################################
-- Triggers updated_at para tabelas dos apps
-- ############################################################

CREATE TRIGGER trg_almox_itens_updated
  BEFORE UPDATE ON almox_itens FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pastos_updated
  BEFORE UPDATE ON pastos FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gado_lotes_updated
  BEFORE UPDATE ON gado_lotes FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gado_animais_updated
  BEFORE UPDATE ON gado_animais FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_obras_updated
  BEFORE UPDATE ON obras FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_funcionarios_updated
  BEFORE UPDATE ON funcionarios FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_imoveis_updated
  BEFORE UPDATE ON imoveis FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_contratos_updated
  BEFORE UPDATE ON contratos_aluguel FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_invest_pos_updated
  BEFORE UPDATE ON investimentos_posicoes FOR EACH ROW EXECUTE FUNCTION set_updated_at();
