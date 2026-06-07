-- ============================================================
-- Cérebro Rural — Migration 0009: RLS Pecuária Avançada
-- Todas as 12 tabelas novas + regras por papel
-- ============================================================

-- ############################################################
-- ESTAÇÕES REPRODUTIVAS
-- ############################################################

ALTER TABLE gado_estacoes_reprodutivas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê estações da fazenda"
  ON gado_estacoes_reprodutivas FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia estações"
  ON gado_estacoes_reprodutivas FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ############################################################
-- PROTOCOLOS REPRODUTIVOS
-- ############################################################

ALTER TABLE gado_protocolos_reprodutivos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê protocolos da fazenda"
  ON gado_protocolos_reprodutivos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia protocolos"
  ON gado_protocolos_reprodutivos FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ############################################################
-- EVENTOS REPRODUTIVOS
-- ############################################################

ALTER TABLE gado_reproducao_eventos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê eventos reprodutivos"
  ON gado_reproducao_eventos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ registra eventos reprodutivos"
  ON gado_reproducao_eventos FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

CREATE POLICY "Gerente+ edita eventos reprodutivos"
  ON gado_reproducao_eventos FOR UPDATE
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ############################################################
-- NASCIMENTOS
-- ############################################################

ALTER TABLE gado_nascimentos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê nascimentos"
  ON gado_nascimentos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ registra nascimento"
  ON gado_nascimentos FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ############################################################
-- TRATAMENTOS
-- ############################################################

ALTER TABLE gado_tratamentos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê tratamentos"
  ON gado_tratamentos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

-- Peão pode registrar vacinação e vermifugação; gerente+ pode tudo
CREATE POLICY "Peão registra vacinação/vermifugação"
  ON gado_tratamentos FOR INSERT
  WITH CHECK (
    fazenda_id IN (SELECT user_fazendas())
    AND (
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente'))
      OR (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'peao')
        AND tipo IN ('vacinacao', 'vermifugacao', 'vitamina', 'mineral')
      )
    )
  );

-- ############################################################
-- MOVIMENTAÇÕES DE PASTO
-- ############################################################

ALTER TABLE gado_movimentacoes_pasto ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê movimentações"
  ON gado_movimentacoes_pasto FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ move animais"
  ON gado_movimentacoes_pasto FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ############################################################
-- GTAs
-- ############################################################

ALTER TABLE gado_gtas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê GTAs"
  ON gado_gtas FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia GTAs"
  ON gado_gtas FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

ALTER TABLE gado_gta_animais ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê animais da GTA"
  ON gado_gta_animais FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ vincula animais à GTA"
  ON gado_gta_animais FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ############################################################
-- MOVIMENTAÇÕES COMERCIAIS (compra/venda)
-- ############################################################

ALTER TABLE gado_movimentacoes_comerciais ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Gerente+ vê transações comerciais"
  ON gado_movimentacoes_comerciais FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- Gerente pode criar rascunho/pendente; dono confirma
CREATE POLICY "Gerente+ cria transação (rascunho/pendente)"
  ON gado_movimentacoes_comerciais FOR INSERT
  WITH CHECK (
    fazenda_id IN (SELECT user_fazendas())
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente'))
    AND (
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono')
      OR status IN ('rascunho', 'pendente_aprovacao')
    )
  );

CREATE POLICY "Dono confirma/edita transação"
  ON gado_movimentacoes_comerciais FOR UPDATE
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

ALTER TABLE gado_movimentacoes_comerciais_itens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Gerente+ vê itens comerciais"
  ON gado_movimentacoes_comerciais_itens FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

CREATE POLICY "Gerente+ gerencia itens comerciais"
  ON gado_movimentacoes_comerciais_itens FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ############################################################
-- SISBOV
-- ############################################################

ALTER TABLE gado_sisbov_registros ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Dono vê SISBOV"
  ON gado_sisbov_registros FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'));

CREATE POLICY "Dono gerencia SISBOV"
  ON gado_sisbov_registros FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ############################################################
-- CALENDÁRIO SANITÁRIO — REGRAS (leitura geral, edição por dono)
-- ############################################################

ALTER TABLE gado_calendario_sanitario_regras ENABLE ROW LEVEL SECURITY;

-- Regras são globais (por UF), todos podem ler
CREATE POLICY "Todos leem regras sanitárias"
  ON gado_calendario_sanitario_regras FOR SELECT
  USING (true);

-- Só admin/dono pode criar/editar regras
CREATE POLICY "Dono gerencia regras sanitárias"
  ON gado_calendario_sanitario_regras FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'))
  WITH CHECK (true);

-- Eventos do calendário
ALTER TABLE gado_calendario_sanitario_eventos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê eventos do calendário"
  ON gado_calendario_sanitario_eventos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia eventos do calendário"
  ON gado_calendario_sanitario_eventos FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ############################################################
-- CUSTOS ALOCADOS
-- ############################################################

ALTER TABLE gado_custos_alocados ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Gerente+ vê custos"
  ON gado_custos_alocados FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

CREATE POLICY "Sistema/gerente+ insere custos"
  ON gado_custos_alocados FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ############################################################
-- TIMELINE (leitura por todos, escrita por triggers)
-- ############################################################

ALTER TABLE gado_timeline_eventos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê timeline"
  ON gado_timeline_eventos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

-- Inserção via SECURITY DEFINER (triggers), mas permitir insert normal também
CREATE POLICY "Sistema insere timeline"
  ON gado_timeline_eventos FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));
