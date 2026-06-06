-- ============================================================
-- Cérebro Rural — Migration 0004: Row Level Security (RLS)
-- TODA tabela com RLS — filtro por fazenda vinculada ao usuário
-- ============================================================

-- ============================================================
-- HELPER: função que retorna as fazendas do usuário logado
-- ============================================================

CREATE OR REPLACE FUNCTION user_fazendas()
RETURNS SETOF uuid AS $$
  -- Retorna fazendas onde o user é proprietário OU fazenda_padrao do perfil
  SELECT id FROM fazendas WHERE proprietario_id = auth.uid()
  UNION
  SELECT fazenda_padrao FROM profiles WHERE id = auth.uid() AND fazenda_padrao IS NOT NULL;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION user_fazendas() IS 'Retorna IDs das fazendas acessíveis pelo usuário logado (proprietário + fazenda padrão)';

-- ============================================================
-- PROFILES
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê próprio perfil"
  ON profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Usuário edita próprio perfil"
  ON profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Dono vê perfis de quem compartilha a mesma fazenda
CREATE POLICY "Dono vê perfis da fazenda"
  ON profiles FOR SELECT
  USING (
    fazenda_padrao IN (SELECT user_fazendas())
  );

-- ============================================================
-- FAZENDAS
-- ============================================================

ALTER TABLE fazendas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Proprietário vê suas fazendas"
  ON fazendas FOR SELECT
  USING (proprietario_id = auth.uid());

CREATE POLICY "Proprietário cria fazenda"
  ON fazendas FOR INSERT
  WITH CHECK (proprietario_id = auth.uid());

CREATE POLICY "Proprietário edita sua fazenda"
  ON fazendas FOR UPDATE
  USING (proprietario_id = auth.uid())
  WITH CHECK (proprietario_id = auth.uid());

CREATE POLICY "Proprietário deleta sua fazenda"
  ON fazendas FOR DELETE
  USING (proprietario_id = auth.uid());

-- ============================================================
-- LANCAMENTOS
-- ============================================================

ALTER TABLE lancamentos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê lançamentos da sua fazenda"
  ON lancamentos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Usuário cria lançamento na sua fazenda"
  ON lancamentos FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Usuário edita lançamento da sua fazenda"
  ON lancamentos FOR UPDATE
  USING (fazenda_id IN (SELECT user_fazendas()))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Dono deleta lançamento"
  ON lancamentos FOR DELETE
  USING (
    fazenda_id IN (SELECT user_fazendas())
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'
    )
  );

-- ============================================================
-- AUDITORIA
-- ============================================================

ALTER TABLE auditoria ENABLE ROW LEVEL SECURITY;

-- Auditoria é append-only; só donos leem
CREATE POLICY "Dono vê auditoria do seu tenant"
  ON auditoria FOR SELECT
  USING (
    tenant_id IN (
      SELECT id::text FROM fazendas WHERE proprietario_id = auth.uid()
    )
  );

-- Inserção via SECURITY DEFINER (triggers internos), não via client
CREATE POLICY "Sistema insere auditoria"
  ON auditoria FOR INSERT
  WITH CHECK (true);  -- controlado pelo SECURITY DEFINER da function

-- ============================================================
-- ALMOXARIFADO — almox_itens
-- ============================================================

ALTER TABLE almox_itens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê itens da sua fazenda"
  ON almox_itens FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ cria item"
  ON almox_itens FOR INSERT
  WITH CHECK (
    fazenda_id IN (SELECT user_fazendas())
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')
    )
  );

CREATE POLICY "Gerente+ edita item"
  ON almox_itens FOR UPDATE
  USING (fazenda_id IN (SELECT user_fazendas()))
  WITH CHECK (
    fazenda_id IN (SELECT user_fazendas())
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')
    )
  );

CREATE POLICY "Dono deleta item"
  ON almox_itens FOR DELETE
  USING (
    fazenda_id IN (SELECT user_fazendas())
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono')
  );

-- ============================================================
-- ALMOXARIFADO — almox_fornecedores
-- ============================================================

ALTER TABLE almox_fornecedores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê fornecedores da fazenda"
  ON almox_fornecedores FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia fornecedores"
  ON almox_fornecedores FOR ALL
  USING (
    fazenda_id IN (SELECT user_fazendas())
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente'))
  )
  WITH CHECK (
    fazenda_id IN (SELECT user_fazendas())
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente'))
  );

-- ============================================================
-- ALMOXARIFADO — almox_setores
-- ============================================================

ALTER TABLE almox_setores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê setores da fazenda"
  ON almox_setores FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia setores"
  ON almox_setores FOR ALL
  USING (
    fazenda_id IN (SELECT user_fazendas())
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente'))
  )
  WITH CHECK (
    fazenda_id IN (SELECT user_fazendas())
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente'))
  );

-- ============================================================
-- ALMOXARIFADO — almox_movimentos
-- ============================================================

ALTER TABLE almox_movimentos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê movimentos da fazenda"
  ON almox_movimentos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

-- Peão pode registrar SAIDA, gerente+ pode tudo
CREATE POLICY "Peão registra saída"
  ON almox_movimentos FOR INSERT
  WITH CHECK (
    fazenda_id IN (SELECT user_fazendas())
    AND (
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente'))
      OR (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'peao')
        AND tipo = 'SAIDA'
      )
    )
  );

-- ============================================================
-- PASTAGEM — pastos
-- ============================================================

ALTER TABLE pastos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê pastos da fazenda"
  ON pastos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia pastos"
  ON pastos FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ============================================================
-- PASTAGEM — pastagem_lotes
-- ============================================================

ALTER TABLE pastagem_lotes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê lotes nos pastos da fazenda"
  ON pastagem_lotes FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia lotes"
  ON pastagem_lotes FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ============================================================
-- MANEJO DE GADO — gado_lotes
-- ============================================================

ALTER TABLE gado_lotes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê lotes de gado"
  ON gado_lotes FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia lotes gado"
  ON gado_lotes FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ============================================================
-- MANEJO DE GADO — gado_animais
-- ============================================================

ALTER TABLE gado_animais ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê animais"
  ON gado_animais FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia animais"
  ON gado_animais FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ============================================================
-- MANEJO DE GADO — gado_pesagens
-- ============================================================

ALTER TABLE gado_pesagens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê pesagens"
  ON gado_pesagens FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Todos registram pesagem"
  ON gado_pesagens FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ============================================================
-- MANEJO DE GADO — gado_vacinacoes
-- ============================================================

ALTER TABLE gado_vacinacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê vacinações"
  ON gado_vacinacoes FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ registra vacinação"
  ON gado_vacinacoes FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ============================================================
-- OBRAS — obras
-- ============================================================

ALTER TABLE obras ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê obras"
  ON obras FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ gerencia obras"
  ON obras FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ============================================================
-- OBRAS — obras_medicoes
-- ============================================================

ALTER TABLE obras_medicoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê medições"
  ON obras_medicoes FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Gerente+ registra medição"
  ON obras_medicoes FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

CREATE POLICY "Dono aprova medição"
  ON obras_medicoes FOR UPDATE
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ============================================================
-- FUNCIONÁRIOS — funcionarios
-- ============================================================

ALTER TABLE funcionarios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Gerente+ vê funcionários"
  ON funcionarios FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

CREATE POLICY "Gerente+ gerencia funcionários"
  ON funcionarios FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ============================================================
-- FUNCIONÁRIOS — folha_pagamento
-- ============================================================

ALTER TABLE folha_pagamento ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Dono vê folha"
  ON folha_pagamento FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

CREATE POLICY "Dono gerencia folha"
  ON folha_pagamento FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ============================================================
-- FUNCIONÁRIOS — adiantamentos
-- ============================================================

ALTER TABLE funcionarios_adiantamentos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Gerente+ vê adiantamentos"
  ON funcionarios_adiantamentos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

CREATE POLICY "Gerente+ registra adiantamento"
  ON funcionarios_adiantamentos FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel IN ('dono', 'gerente')));

-- ============================================================
-- ALUGUEL — imoveis
-- ============================================================

ALTER TABLE imoveis ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê imóveis"
  ON imoveis FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Dono gerencia imóveis"
  ON imoveis FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ============================================================
-- ALUGUEL — contratos_aluguel
-- ============================================================

ALTER TABLE contratos_aluguel ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê contratos"
  ON contratos_aluguel FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Dono gerencia contratos"
  ON contratos_aluguel FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ============================================================
-- ALUGUEL — recebimentos_aluguel
-- ============================================================

ALTER TABLE recebimentos_aluguel ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê recebimentos"
  ON recebimentos_aluguel FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Dono gerencia recebimentos"
  ON recebimentos_aluguel FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ============================================================
-- VIDA PESSOAL — gastos_pessoais
-- ============================================================

ALTER TABLE gastos_pessoais ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê gastos pessoais"
  ON gastos_pessoais FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Usuário registra gasto pessoal"
  ON gastos_pessoais FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

CREATE POLICY "Dono deleta gasto pessoal"
  ON gastos_pessoais FOR DELETE
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'));

-- ============================================================
-- BOLSA/FII — investimentos_posicoes
-- ============================================================

ALTER TABLE investimentos_posicoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Dono vê posições"
  ON investimentos_posicoes FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'));

CREATE POLICY "Dono gerencia posições"
  ON investimentos_posicoes FOR ALL
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'))
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()));

-- ============================================================
-- BOLSA/FII — investimentos_proventos
-- ============================================================

ALTER TABLE investimentos_proventos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Dono vê proventos"
  ON investimentos_proventos FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'));

CREATE POLICY "Dono registra provento"
  ON investimentos_proventos FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'));

-- ============================================================
-- BOLSA/FII — investimentos_aportes
-- ============================================================

ALTER TABLE investimentos_aportes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Dono vê aportes"
  ON investimentos_aportes FOR SELECT
  USING (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'));

CREATE POLICY "Dono registra aporte"
  ON investimentos_aportes FOR INSERT
  WITH CHECK (fazenda_id IN (SELECT user_fazendas()) AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND papel = 'dono'));
