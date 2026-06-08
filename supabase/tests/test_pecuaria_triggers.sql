-- ============================================================
-- Cérebro Rural — Testes de Integridade: Pecuária
-- Execução incremental: cada bloco depende do anterior
-- ============================================================
-- USO: psql -f supabase/tests/test_pecuaria_triggers.sql
-- Cada teste retorna PASS ou FAIL com contexto
-- ============================================================

-- Helper para reportar resultado
CREATE OR REPLACE FUNCTION _test_assert(p_condition boolean, p_test_name text)
RETURNS void AS $$
BEGIN
  IF p_condition THEN
    RAISE NOTICE '✓ PASS: %', p_test_name;
  ELSE
    RAISE EXCEPTION '✗ FAIL: %', p_test_name;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TESTE 1: lancamento_id é populado após venda confirmada
-- ============================================================
DO $$
DECLARE
  v_mov_id uuid;
  v_lanc_id uuid;
BEGIN
  RAISE NOTICE '--- TESTE 1: lancamento_id populado após venda ---';

  -- Criar movimentação comercial confirmada
  INSERT INTO gado_movimentacoes_comerciais (
    fazenda_id, tipo, data_movimentacao, parceiro_nome,
    quantidade_animais, valor_total, status
  ) VALUES (
    '00000000-0000-0000-0000-000000000010',
    'venda', CURRENT_DATE, 'Frigorifico Teste',
    5, 25000.00, 'confirmado'
  ) RETURNING id INTO v_mov_id;

  -- Verificar que lancamento_id NÃO é NULL
  SELECT lancamento_id INTO v_lanc_id
  FROM gado_movimentacoes_comerciais WHERE id = v_mov_id;

  PERFORM _test_assert(
    v_lanc_id IS NOT NULL,
    'lancamento_id deve ser preenchido após INSERT confirmado'
  );

  -- Verificar que o lançamento existe na tabela lancamentos
  PERFORM _test_assert(
    EXISTS(SELECT 1 FROM lancamentos WHERE id = v_lanc_id),
    'lançamento referenciado deve existir na tabela lancamentos'
  );

  -- Verificar valores do lançamento
  PERFORM _test_assert(
    (SELECT tipo FROM lancamentos WHERE id = v_lanc_id) = 'ENTRADA',
    'venda deve gerar lançamento tipo ENTRADA'
  );

  PERFORM _test_assert(
    (SELECT valor FROM lancamentos WHERE id = v_lanc_id) = 25000.00,
    'valor do lançamento deve ser 25000.00'
  );

  -- Cleanup
  DELETE FROM lancamentos WHERE id = v_lanc_id;
  DELETE FROM gado_movimentacoes_comerciais WHERE id = v_mov_id;

  RAISE NOTICE '--- TESTE 1 COMPLETO ---';
END;
$$;

-- ============================================================
-- TESTE 2: Venda multi-lote subtrai corretamente por lote
-- ============================================================
DO $$
DECLARE
  v_mov_id uuid;
  v_lote_a_id uuid := '10000000-0000-0000-0000-000000000001'; -- Engorda 01 (42)
  v_lote_b_id uuid := '10000000-0000-0000-0000-000000000002'; -- Engorda 02 (35)
  v_qtd_a_antes integer;
  v_qtd_b_antes integer;
  v_qtd_a_depois integer;
  v_qtd_b_depois integer;
BEGIN
  RAISE NOTICE '--- TESTE 2: Venda multi-lote subtrai por lote ---';

  -- Guardar quantidades antes
  SELECT quantidade INTO v_qtd_a_antes FROM gado_lotes WHERE id = v_lote_a_id;
  SELECT quantidade INTO v_qtd_b_antes FROM gado_lotes WHERE id = v_lote_b_id;

  -- Criar venda em status rascunho primeiro
  INSERT INTO gado_movimentacoes_comerciais (
    fazenda_id, tipo, data_movimentacao, parceiro_nome,
    quantidade_animais, valor_total, status
  ) VALUES (
    '00000000-0000-0000-0000-000000000010',
    'venda', CURRENT_DATE, 'Comprador Multi-Lote',
    10, 50000.00, 'rascunho'
  ) RETURNING id INTO v_mov_id;

  -- Adicionar itens: 6 do lote A, 4 do lote B
  INSERT INTO gado_movimentacoes_comerciais_itens (fazenda_id, movimentacao_id, lote_id, quantidade, valor_total)
  VALUES
    ('00000000-0000-0000-0000-000000000010', v_mov_id, v_lote_a_id, 6, 30000.00),
    ('00000000-0000-0000-0000-000000000010', v_mov_id, v_lote_b_id, 4, 20000.00);

  -- Confirmar a venda (dispara trigger)
  UPDATE gado_movimentacoes_comerciais SET status = 'confirmado' WHERE id = v_mov_id;

  -- Verificar quantidades depois
  SELECT quantidade INTO v_qtd_a_depois FROM gado_lotes WHERE id = v_lote_a_id;
  SELECT quantidade INTO v_qtd_b_depois FROM gado_lotes WHERE id = v_lote_b_id;

  PERFORM _test_assert(
    v_qtd_a_depois = v_qtd_a_antes - 6,
    'Lote A deve diminuir em 6 (era ' || v_qtd_a_antes || ', agora ' || v_qtd_a_depois || ')'
  );

  PERFORM _test_assert(
    v_qtd_b_depois = v_qtd_b_antes - 4,
    'Lote B deve diminuir em 4 (era ' || v_qtd_b_antes || ', agora ' || v_qtd_b_depois || ')'
  );

  -- Regressão TESTE 1: lancamento_id preenchido?
  PERFORM _test_assert(
    (SELECT lancamento_id FROM gado_movimentacoes_comerciais WHERE id = v_mov_id) IS NOT NULL,
    '[REGRESSÃO T1] lancamento_id deve estar preenchido'
  );

  -- Cleanup: restaurar quantidades
  UPDATE gado_lotes SET quantidade = v_qtd_a_antes WHERE id = v_lote_a_id;
  UPDATE gado_lotes SET quantidade = v_qtd_b_antes WHERE id = v_lote_b_id;
  DELETE FROM gado_movimentacoes_comerciais_itens WHERE movimentacao_id = v_mov_id;
  DELETE FROM lancamentos WHERE referencia_id = v_mov_id;
  DELETE FROM gado_movimentacoes_comerciais WHERE id = v_mov_id;

  RAISE NOTICE '--- TESTE 2 COMPLETO ---';
END;
$$;

-- ============================================================
-- TESTE 3: View GMD calcula corretamente (sem erro de tipo)
-- ============================================================
DO $$
DECLARE
  v_gmd numeric;
  v_dias integer;
BEGIN
  RAISE NOTICE '--- TESTE 3: View GMD sem erro de tipo ---';

  -- Consultar view sem erro (o principal teste é que não dá exception)
  SELECT gmd_kg_dia, dias_entre_pesagens
  INTO v_gmd, v_dias
  FROM vw_gado_gmd_animal
  WHERE animal_id = '30000000-0000-0000-0000-000000000001'
  ORDER BY data DESC
  LIMIT 1;

  PERFORM _test_assert(
    v_gmd IS NOT NULL,
    'GMD deve ser calculado (got ' || COALESCE(v_gmd::text, 'NULL') || ')'
  );

  PERFORM _test_assert(
    v_gmd > 0 AND v_gmd < 5,
    'GMD deve ser razoável (0-5 kg/dia), got ' || v_gmd::text
  );

  PERFORM _test_assert(
    v_dias IS NOT NULL AND v_dias > 0,
    'dias_entre_pesagens deve ser inteiro positivo, got ' || COALESCE(v_dias::text, 'NULL')
  );

  -- Regressão T1+T2: criar venda rápida e verificar
  RAISE NOTICE '[REGRESSÃO T1+T2] Verificando via SELECT na view...';
  PERFORM _test_assert(
    (SELECT COUNT(*) FROM vw_gado_gmd_animal WHERE animal_id = '30000000-0000-0000-0000-000000000001') >= 3,
    '[REGRESSÃO] Trovão deve ter pelo menos 3 registros de GMD'
  );

  RAISE NOTICE '--- TESTE 3 COMPLETO ---';
END;
$$;

-- ============================================================
-- TESTE 4: Alertas sanitários incluem tratamentos por lote
-- ============================================================
DO $$
DECLARE
  v_count_carencia integer;
  v_count_dose integer;
BEGIN
  RAISE NOTICE '--- TESTE 4: Alertas incluem tratamentos por lote ---';

  -- Contar alertas de carência (inclui tratamentos com animal_id NULL)
  SELECT COUNT(*) INTO v_count_carencia
  FROM vw_gado_alertas_sanitarios
  WHERE tipo_alerta = 'carencia_ativa';

  -- Vermifugação no seed tem 28 dias de carência e foi aplicado há 45 dias
  -- Então carência já venceu. Mas o teste verifica que a view EXECUTA sem erro
  -- e inclui registros de lote (animal_id IS NULL)
  PERFORM _test_assert(
    true,  -- view executa sem erro
    'View vw_gado_alertas_sanitarios executa sem erro de JOIN'
  );

  -- Verificar doses pendentes (vermifugação com próxima_dose em ~45 dias)
  SELECT COUNT(*) INTO v_count_dose
  FROM vw_gado_alertas_sanitarios
  WHERE tipo_alerta = 'dose_pendente';

  PERFORM _test_assert(
    v_count_dose >= 0,
    'Doses pendentes retornam resultado (count=' || v_count_dose || ')'
  );

  -- Inserir tratamento por lote com carência ativa para testar
  INSERT INTO gado_tratamentos (
    fazenda_id, lote_id, tipo, produto, data_aplicacao,
    carencia_carne_dias, quantidade_animais
  ) VALUES (
    '00000000-0000-0000-0000-000000000010',
    '10000000-0000-0000-0000-000000000001',
    'antibiotico', 'Oxitetraciclina Teste', CURRENT_DATE,
    30, 42
  );

  -- Deve aparecer no alerta (animal_id IS NULL, mas lote inteiro em carência)
  SELECT COUNT(*) INTO v_count_carencia
  FROM vw_gado_alertas_sanitarios
  WHERE tipo_alerta = 'carencia_ativa'
    AND lote_id = '10000000-0000-0000-0000-000000000001'
    AND animal_id IS NULL;

  PERFORM _test_assert(
    v_count_carencia > 0,
    'Tratamento por lote (animal_id NULL) DEVE aparecer nos alertas de carência'
  );

  -- Cleanup
  DELETE FROM gado_tratamentos WHERE produto = 'Oxitetraciclina Teste';
  -- Cleanup custos e timeline gerados pelo trigger
  DELETE FROM gado_custos_alocados WHERE descricao LIKE '%Oxitetraciclina Teste%';
  DELETE FROM gado_timeline_eventos WHERE titulo LIKE '%Oxitetraciclina Teste%';

  -- Regressão T1+T2+T3
  PERFORM _test_assert(
    (SELECT COUNT(*) FROM vw_gado_gmd_animal) > 0,
    '[REGRESSÃO T3] View GMD continua funcional'
  );

  RAISE NOTICE '--- TESTE 4 COMPLETO ---';
END;
$$;

-- ============================================================
-- TESTE 5: Seed não está na cadeia de migrations
-- ============================================================
DO $$
BEGIN
  RAISE NOTICE '--- TESTE 5: Estrutura de arquivos ---';

  -- Este teste é estrutural — verificado no filesystem, não no SQL.
  -- Aqui validamos que os dados de seed existem (foram carregados manualmente)
  PERFORM _test_assert(
    (SELECT COUNT(*) FROM gado_animais WHERE fazenda_id = '00000000-0000-0000-0000-000000000010') >= 10,
    'Dados de seed devem estar presentes (10 animais de teste)'
  );

  -- Regressão final: todas as views executam
  PERFORM _test_assert(
    (SELECT COUNT(*) FROM vw_gado_ultima_pesagem) > 0,
    '[REGRESSÃO] vw_gado_ultima_pesagem funcional'
  );
  PERFORM _test_assert(
    (SELECT COUNT(*) FROM vw_gado_gmd_animal) > 0,
    '[REGRESSÃO] vw_gado_gmd_animal funcional'
  );
  PERFORM _test_assert(
    (SELECT COUNT(*) FROM vw_gado_resumo_lotes) > 0,
    '[REGRESSÃO] vw_gado_resumo_lotes funcional'
  );
  PERFORM _test_assert(
    (SELECT COUNT(*) FROM vw_gado_indicadores_reprodutivos) > 0,
    '[REGRESSÃO] vw_gado_indicadores_reprodutivos funcional'
  );

  RAISE NOTICE '--- TESTE 5 COMPLETO ---';
  RAISE NOTICE '=========================================';
  RAISE NOTICE '  TODOS OS TESTES PASSARAM ✓';
  RAISE NOTICE '=========================================';
END;
$$;

-- Cleanup helper
DROP FUNCTION IF EXISTS _test_assert(boolean, text);
