-- ============================================================
-- Cérebro Rural — Migration 0006: Pecuária Avançada
-- Tabelas de reprodução, tratamentos, movimentações, GTA,
-- SISBOV, custos alocados e timeline
-- ============================================================

-- ############################################################
-- ESTAÇÕES REPRODUTIVAS
-- ############################################################

CREATE TABLE gado_estacoes_reprodutivas (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  nome            text NOT NULL,
  data_inicio     date NOT NULL,
  data_fim        date,
  tipo            text NOT NULL DEFAULT 'mista'
                  CHECK (tipo IN ('iatf', 'monta_natural', 'mista')),
  objetivo        text,
  total_matrizes  integer,
  ativa           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE gado_estacoes_reprodutivas IS 'Estação de monta/IATF — agrupa protocolos e eventos reprodutivos';

CREATE INDEX idx_gado_estacoes_fazenda ON gado_estacoes_reprodutivas(fazenda_id);
CREATE INDEX idx_gado_estacoes_ativas  ON gado_estacoes_reprodutivas(fazenda_id) WHERE ativa = true;

-- ############################################################
-- PROTOCOLOS REPRODUTIVOS
-- ############################################################

CREATE TABLE gado_protocolos_reprodutivos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  estacao_id      uuid REFERENCES gado_estacoes_reprodutivas(id) ON DELETE SET NULL,
  nome            text NOT NULL,
  tipo            text NOT NULL
                  CHECK (tipo IN ('iatf', 'monta_natural', 'inseminacao_convencional', 'te', 'outro')),
  descricao       text,
  data_inicio     date,
  data_fim        date,
  custo_total     numeric(14,2) DEFAULT 0,
  ativo           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_gado_protocolos_estacao ON gado_protocolos_reprodutivos(estacao_id);

-- ############################################################
-- EVENTOS REPRODUTIVOS (timeline reprodutiva)
-- ############################################################

CREATE TABLE gado_reproducao_eventos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  matriz_id       uuid NOT NULL REFERENCES gado_animais(id) ON DELETE RESTRICT,
  protocolo_id    uuid REFERENCES gado_protocolos_reprodutivos(id),
  estacao_id      uuid REFERENCES gado_estacoes_reprodutivas(id),
  tipo_evento     text NOT NULL
                  CHECK (tipo_evento IN (
                    'cobricao_natural', 'iatf', 'inseminacao',
                    'diagnostico_gestacao', 'confirmacao_prenhez',
                    'aborto', 'parto', 'desmama', 'outro'
                  )),
  data_evento     date NOT NULL,
  reprodutor_id   uuid REFERENCES gado_animais(id),
  semen_identificacao text,
  resultado_diagnostico text
                  CHECK (resultado_diagnostico IN ('prenhe', 'vazia', 'inconclusivo', NULL)),
  previsao_parto  date,
  cria_animal_id  uuid REFERENCES gado_animais(id),
  responsavel_id  uuid REFERENCES profiles(id),
  custo_total     numeric(12,2) DEFAULT 0,
  observacoes     text,
  client_mutation_id uuid UNIQUE,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE gado_reproducao_eventos IS 'Todo evento reprodutivo: cobertura → DG → parto → desmama';

CREATE INDEX idx_gado_reprod_matriz       ON gado_reproducao_eventos(matriz_id, data_evento DESC);
CREATE INDEX idx_gado_reprod_previsao     ON gado_reproducao_eventos(fazenda_id, previsao_parto)
  WHERE previsao_parto IS NOT NULL AND tipo_evento != 'parto';
CREATE INDEX idx_gado_reprod_estacao      ON gado_reproducao_eventos(estacao_id, data_evento);
CREATE INDEX idx_gado_reprod_tipo         ON gado_reproducao_eventos(fazenda_id, tipo_evento);

-- ############################################################
-- NASCIMENTOS
-- ############################################################

CREATE TABLE gado_nascimentos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  matriz_id       uuid REFERENCES gado_animais(id),
  reprodutor_id   uuid REFERENCES gado_animais(id),
  evento_parto_id uuid REFERENCES gado_reproducao_eventos(id),
  bezerro_animal_id uuid REFERENCES gado_animais(id),
  data_nascimento date NOT NULL,
  sexo            text CHECK (sexo IN ('M', 'F', 'indefinido')),
  peso_nascimento_kg numeric(10,3),
  tipo_parto      text CHECK (tipo_parto IN ('normal', 'assistido', 'cesarea', 'distocico')),
  resultado       text NOT NULL DEFAULT 'vivo'
                  CHECK (resultado IN ('vivo', 'natimorto', 'morte_neonatal', 'aborto')),
  dificuldade_parto boolean NOT NULL DEFAULT false,
  observacao      text,
  client_mutation_id uuid UNIQUE,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_gado_nasc_fazenda ON gado_nascimentos(fazenda_id, data_nascimento DESC);
CREATE INDEX idx_gado_nasc_matriz  ON gado_nascimentos(matriz_id, data_nascimento DESC);

-- ############################################################
-- TRATAMENTOS / MANEJOS SANITÁRIOS (expandido)
-- ############################################################

CREATE TABLE gado_tratamentos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  animal_id       uuid REFERENCES gado_animais(id),
  lote_id         uuid REFERENCES gado_lotes(id),
  tipo            text NOT NULL
                  CHECK (tipo IN (
                    'vacinacao', 'vermifugacao', 'antibiotico', 'anti_inflamatorio',
                    'carrapaticida', 'vitamina', 'mineral', 'cirurgia',
                    'curativo', 'exame', 'procedimento', 'outro'
                  )),
  produto         text NOT NULL,
  principio_ativo text,
  dosagem         text,
  unidade         text,
  via_aplicacao   text
                  CHECK (via_aplicacao IN (
                    'oral', 'subcutanea', 'intramuscular', 'topica',
                    'pour_on', 'intravenosa', NULL
                  )),
  data_aplicacao  date NOT NULL,
  proxima_dose    date,
  carencia_carne_dias integer NOT NULL DEFAULT 0,
  carencia_leite_dias integer NOT NULL DEFAULT 0,
  carencia_carne_ate date GENERATED ALWAYS AS (data_aplicacao + carencia_carne_dias) STORED,
  quantidade_animais integer DEFAULT 1,
  responsavel_id  uuid REFERENCES profiles(id),
  custo_total     numeric(12,2) DEFAULT 0,
  almoxarifado_movimento_id uuid REFERENCES almox_movimentos(id),
  observacao      text,
  anexos          jsonb DEFAULT '[]',
  origem_entrada  text NOT NULL DEFAULT 'manual'
                  CHECK (origem_entrada IN ('manual', 'csv', 'excel', 'ocr', 'api')),
  client_mutation_id uuid UNIQUE,
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_tratamento_alvo CHECK (lote_id IS NOT NULL OR animal_id IS NOT NULL)
);

COMMENT ON TABLE gado_tratamentos IS 'Manejo sanitário unificado — vacinação, vermifugação, tratamentos, procedimentos';

CREATE INDEX idx_gado_trat_animal    ON gado_tratamentos(animal_id, data_aplicacao DESC);
CREATE INDEX idx_gado_trat_lote      ON gado_tratamentos(lote_id, data_aplicacao DESC);
CREATE INDEX idx_gado_trat_carencia  ON gado_tratamentos(fazenda_id, carencia_carne_ate)
  WHERE carencia_carne_ate > CURRENT_DATE;
CREATE INDEX idx_gado_trat_proxdose  ON gado_tratamentos(fazenda_id, proxima_dose)
  WHERE proxima_dose IS NOT NULL;

-- ############################################################
-- MOVIMENTAÇÕES ENTRE PASTOS
-- ############################################################

CREATE TABLE gado_movimentacoes_pasto (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  lote_id         uuid REFERENCES gado_lotes(id),
  animal_id       uuid REFERENCES gado_animais(id),
  pasto_origem_id uuid REFERENCES pastos(id),
  pasto_destino_id uuid NOT NULL REFERENCES pastos(id),
  data_movimentacao date NOT NULL,
  motivo          text CHECK (motivo IN (
    'rotacao', 'falta_forragem', 'manejo_sanitario',
    'apartacao', 'desmama', 'engorda', 'outro'
  )),
  quantidade_animais integer,
  responsavel_id  uuid REFERENCES profiles(id),
  observacao      text,
  client_mutation_id uuid UNIQUE,
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_mov_pasto_alvo CHECK (lote_id IS NOT NULL OR animal_id IS NOT NULL)
);

CREATE INDEX idx_gado_mov_pasto_fazenda ON gado_movimentacoes_pasto(fazenda_id, data_movimentacao DESC);
CREATE INDEX idx_gado_mov_pasto_lote    ON gado_movimentacoes_pasto(lote_id, data_movimentacao DESC);
CREATE INDEX idx_gado_mov_pasto_dest    ON gado_movimentacoes_pasto(pasto_destino_id);

-- ############################################################
-- GTA (Guia de Trânsito Animal)
-- ############################################################

CREATE TABLE gado_gtas (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  numero          text NOT NULL,
  serie           text,
  uf_emissora     char(2),
  finalidade      text NOT NULL
                  CHECK (finalidade IN (
                    'abate', 'engorda', 'reproducao', 'cria',
                    'leilao', 'exposicao', 'retorno', 'outro'
                  )),
  status          text NOT NULL DEFAULT 'emitida'
                  CHECK (status IN ('rascunho', 'emitida', 'vencida', 'utilizada', 'cancelada')),
  data_emissao    date NOT NULL,
  data_validade   date,
  propriedade_origem  text,
  municipio_origem    text,
  uf_origem       char(2),
  propriedade_destino text,
  municipio_destino   text,
  uf_destino      char(2),
  especie         text NOT NULL DEFAULT 'bovina',
  quantidade_animais integer NOT NULL CHECK (quantidade_animais > 0),
  arquivo_url     text,
  anexos          jsonb DEFAULT '[]',
  observacao      text,
  client_mutation_id uuid UNIQUE,
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_gta_numero UNIQUE (fazenda_id, numero)
);

COMMENT ON TABLE gado_gtas IS 'GTA digital — repositório inteligente (não emite automaticamente sem API governamental)';

CREATE INDEX idx_gado_gtas_validade ON gado_gtas(fazenda_id, status, data_validade);

-- Vínculo GTA ↔ animais
CREATE TABLE gado_gta_animais (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  gta_id          uuid NOT NULL REFERENCES gado_gtas(id) ON DELETE CASCADE,
  animal_id       uuid REFERENCES gado_animais(id),
  lote_id         uuid REFERENCES gado_lotes(id),
  quantidade_lote integer,
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_gta_alvo CHECK (animal_id IS NOT NULL OR lote_id IS NOT NULL)
);

CREATE INDEX idx_gado_gta_animais_gta ON gado_gta_animais(gta_id);

-- ############################################################
-- MOVIMENTAÇÕES COMERCIAIS (compra/venda)
-- ############################################################

CREATE TABLE gado_movimentacoes_comerciais (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  tipo            text NOT NULL
                  CHECK (tipo IN ('compra', 'venda', 'permuta', 'transferencia_entrada', 'transferencia_saida', 'ajuste')),
  data_movimentacao date NOT NULL,
  parceiro_nome   text NOT NULL,
  parceiro_documento text,
  propriedade_parceiro text,
  municipio_parceiro text,
  uf_parceiro     char(2),
  nota_fiscal_numero text,
  gta_id          uuid REFERENCES gado_gtas(id),
  quantidade_animais integer NOT NULL CHECK (quantidade_animais > 0),
  peso_total_kg   numeric(14,3),
  rendimento_carcaca_percent numeric(5,2),
  valor_por_cabeca  numeric(14,2),
  valor_por_kg      numeric(14,4),
  valor_por_arroba  numeric(14,2),
  valor_animais     numeric(14,2) DEFAULT 0,
  valor_frete       numeric(14,2) DEFAULT 0,
  valor_comissao    numeric(14,2) DEFAULT 0,
  valor_impostos    numeric(14,2) DEFAULT 0,
  valor_descontos   numeric(14,2) DEFAULT 0,
  valor_total       numeric(14,2) NOT NULL,
  status          text NOT NULL DEFAULT 'confirmado'
                  CHECK (status IN ('rascunho', 'pendente_aprovacao', 'confirmado', 'cancelado')),
  calculadora_boi_simulacao_id uuid,
  lancamento_id   uuid REFERENCES lancamentos(id),
  observacao      text,
  anexos          jsonb DEFAULT '[]',
  responsavel_id  uuid REFERENCES profiles(id),
  client_mutation_id uuid UNIQUE,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE gado_movimentacoes_comerciais IS 'Compra/venda/permuta — gera lançamento financeiro obrigatório';

CREATE INDEX idx_gado_comercial_fazenda ON gado_movimentacoes_comerciais(fazenda_id, tipo, data_movimentacao DESC);
CREATE INDEX idx_gado_comercial_status  ON gado_movimentacoes_comerciais(fazenda_id, status);

-- Itens da transação (quais animais/lotes participaram)
CREATE TABLE gado_movimentacoes_comerciais_itens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  movimentacao_id uuid NOT NULL REFERENCES gado_movimentacoes_comerciais(id) ON DELETE CASCADE,
  animal_id       uuid REFERENCES gado_animais(id),
  lote_id         uuid REFERENCES gado_lotes(id),
  quantidade      integer NOT NULL DEFAULT 1,
  peso_kg         numeric(12,3),
  valor_unitario  numeric(14,2),
  valor_total     numeric(14,2),
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_item_comercial_alvo CHECK (animal_id IS NOT NULL OR lote_id IS NOT NULL)
);

CREATE INDEX idx_gado_comercial_itens_mov ON gado_movimentacoes_comerciais_itens(movimentacao_id);

-- ############################################################
-- SISBOV (Rastreabilidade)
-- ############################################################

CREATE TABLE gado_sisbov_registros (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  animal_id       uuid NOT NULL REFERENCES gado_animais(id) ON DELETE RESTRICT,
  codigo_sisbov   text NOT NULL,
  certificadora   text,
  protocolo       text,
  data_ingresso   date,
  status          text NOT NULL DEFAULT 'ativo'
                  CHECK (status IN ('ativo', 'pendente', 'suspenso', 'cancelado', 'baixado')),
  observacao      text,
  anexos          jsonb DEFAULT '[]',
  client_mutation_id uuid UNIQUE,
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_sisbov_animal UNIQUE (animal_id),
  CONSTRAINT uq_sisbov_codigo UNIQUE (fazenda_id, codigo_sisbov)
);

CREATE INDEX idx_gado_sisbov_fazenda ON gado_sisbov_registros(fazenda_id, status);

-- ############################################################
-- CALENDÁRIO SANITÁRIO — REGRAS (parametrizável por UF)
-- ############################################################

CREATE TABLE gado_calendario_sanitario_regras (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uf              char(2),
  nome            text NOT NULL,
  descricao       text,
  obrigatorio     boolean NOT NULL DEFAULT false,
  mes_inicio      integer CHECK (mes_inicio BETWEEN 1 AND 12),
  mes_fim         integer CHECK (mes_fim BETWEEN 1 AND 12),
  categoria_animal text,
  sexo            text CHECK (sexo IN ('M', 'F', 'todos', NULL)),
  idade_min_meses integer,
  idade_max_meses integer,
  recorrencia     text NOT NULL DEFAULT 'anual'
                  CHECK (recorrencia IN ('anual', 'semestral', 'unica', 'conforme_necessidade')),
  fonte_normativa text,
  ativo           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE gado_calendario_sanitario_regras IS 'Regras obrigatórias por UF — parametrizável via admin, nunca hardcoded';

CREATE INDEX idx_gado_cal_regras_uf ON gado_calendario_sanitario_regras(uf) WHERE ativo = true;

-- Eventos sanitários programados/realizados
CREATE TABLE gado_calendario_sanitario_eventos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  regra_id        uuid REFERENCES gado_calendario_sanitario_regras(id),
  lote_id         uuid REFERENCES gado_lotes(id),
  nome            text NOT NULL,
  competencia_ano integer NOT NULL,
  data_inicio     date,
  data_limite     date,
  data_realizacao date,
  status          text NOT NULL DEFAULT 'pendente'
                  CHECK (status IN ('pendente', 'programado', 'realizado', 'vencido', 'dispensado')),
  tratamento_id   uuid REFERENCES gado_tratamentos(id),
  responsavel_id  uuid REFERENCES profiles(id),
  observacao      text,
  client_mutation_id uuid UNIQUE,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_gado_cal_eventos_status ON gado_calendario_sanitario_eventos(fazenda_id, status, data_limite);
CREATE INDEX idx_gado_cal_eventos_ano    ON gado_calendario_sanitario_eventos(fazenda_id, competencia_ano);

-- ############################################################
-- CUSTOS ALOCADOS (custo por arroba)
-- ############################################################

CREATE TABLE gado_custos_alocados (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  lote_id         uuid REFERENCES gado_lotes(id),
  animal_id       uuid REFERENCES gado_animais(id),
  data_custo      date NOT NULL,
  categoria       text NOT NULL
                  CHECK (categoria IN (
                    'sanidade', 'alimentacao', 'pastagem', 'mao_obra',
                    'compra', 'frete', 'comissao', 'reproducao', 'outro'
                  )),
  descricao       text NOT NULL,
  valor           numeric(14,2) NOT NULL CHECK (valor > 0),
  lancamento_id   uuid REFERENCES lancamentos(id),
  almoxarifado_movimento_id uuid REFERENCES almox_movimentos(id),
  funcionario_id  uuid REFERENCES funcionarios(id),
  origem          text NOT NULL DEFAULT 'manual'
                  CHECK (origem IN ('manual', 'trigger', 'importacao')),
  client_mutation_id uuid UNIQUE,
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_custo_alvo CHECK (lote_id IS NOT NULL OR animal_id IS NOT NULL)
);

COMMENT ON TABLE gado_custos_alocados IS 'Custos atribuídos a lotes/animais — alimenta cálculo de custo por arroba';

CREATE INDEX idx_gado_custos_lote    ON gado_custos_alocados(lote_id, data_custo DESC);
CREATE INDEX idx_gado_custos_animal  ON gado_custos_alocados(animal_id, data_custo DESC);
CREATE INDEX idx_gado_custos_cat     ON gado_custos_alocados(fazenda_id, categoria);

-- ############################################################
-- TIMELINE UNIFICADA (ficha do animal)
-- ############################################################

CREATE TABLE gado_timeline_eventos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  animal_id       uuid REFERENCES gado_animais(id),
  lote_id         uuid REFERENCES gado_lotes(id),
  data_evento     timestamptz NOT NULL,
  tipo_evento     text NOT NULL,
  titulo          text NOT NULL,
  descricao       text,
  entidade_origem text NOT NULL,
  entidade_origem_id uuid NOT NULL,
  severidade      text NOT NULL DEFAULT 'info'
                  CHECK (severidade IN ('info', 'sucesso', 'alerta', 'critico')),
  metadados       jsonb DEFAULT '{}',
  criado_em       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_timeline_alvo CHECK (animal_id IS NOT NULL OR lote_id IS NOT NULL)
);

COMMENT ON TABLE gado_timeline_eventos IS 'Timeline unificada — toda ação vira evento na ficha do animal/lote';

CREATE INDEX idx_gado_timeline_animal ON gado_timeline_eventos(animal_id, data_evento DESC);
CREATE INDEX idx_gado_timeline_lote   ON gado_timeline_eventos(lote_id, data_evento DESC);
CREATE INDEX idx_gado_timeline_tipo   ON gado_timeline_eventos(fazenda_id, tipo_evento);

-- ############################################################
-- Triggers updated_at
-- ############################################################

CREATE TRIGGER trg_gado_estacoes_updated
  BEFORE UPDATE ON gado_estacoes_reprodutivas FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gado_protocolos_updated
  BEFORE UPDATE ON gado_protocolos_reprodutivos FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gado_reprod_eventos_updated
  BEFORE UPDATE ON gado_reproducao_eventos FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gado_mov_comercial_updated
  BEFORE UPDATE ON gado_movimentacoes_comerciais FOR EACH ROW EXECUTE FUNCTION set_updated_at();
