-- ============================================================
-- Cérebro Rural — Migration 0010: Seed Pecuária
-- Dados realistas para testar todo o módulo
-- ============================================================

DO $$
DECLARE
  v_user_id     uuid := '00000000-0000-0000-0000-000000000001';
  v_fazenda     uuid := '00000000-0000-0000-0000-000000000010';
  -- Lotes
  v_lote_eng1   uuid := '10000000-0000-0000-0000-000000000001';
  v_lote_eng2   uuid := '10000000-0000-0000-0000-000000000002';
  v_lote_recria uuid := '10000000-0000-0000-0000-000000000003';
  v_lote_cria   uuid := '10000000-0000-0000-0000-000000000004';
  v_lote_reprod uuid := '10000000-0000-0000-0000-000000000005';
  -- Pastos
  v_pasto1      uuid := '20000000-0000-0000-0000-000000000001';
  v_pasto2      uuid := '20000000-0000-0000-0000-000000000002';
  v_pasto3      uuid := '20000000-0000-0000-0000-000000000003';
  v_pasto4      uuid := '20000000-0000-0000-0000-000000000004';
  v_pasto5      uuid := '20000000-0000-0000-0000-000000000005';
  -- Animais individuais (10 rastreados)
  v_animal1     uuid := '30000000-0000-0000-0000-000000000001';
  v_animal2     uuid := '30000000-0000-0000-0000-000000000002';
  v_animal3     uuid := '30000000-0000-0000-0000-000000000003';
  v_animal4     uuid := '30000000-0000-0000-0000-000000000004';
  v_animal5     uuid := '30000000-0000-0000-0000-000000000005';
  v_animal6     uuid := '30000000-0000-0000-0000-000000000006';
  v_animal7     uuid := '30000000-0000-0000-0000-000000000007';
  v_animal8     uuid := '30000000-0000-0000-0000-000000000008';
  v_animal9     uuid := '30000000-0000-0000-0000-000000000009';
  v_animal10    uuid := '30000000-0000-0000-0000-000000000010';
  -- Estação reprodutiva
  v_estacao1    uuid := '40000000-0000-0000-0000-000000000001';
BEGIN

-- ============================================================
-- PASTOS
-- ============================================================
INSERT INTO pastos (id, fazenda_id, nome, area_ha, ua_por_ha, forrageira, status) VALUES
  (v_pasto1, v_fazenda, 'Pasto 1 - Braquiarão', 45.00, 1.2, 'Brachiaria brizantha', 'ativo'),
  (v_pasto2, v_fazenda, 'Pasto 2 - Mombaça', 38.00, 1.5, 'Panicum maximum cv. Mombaça', 'ativo'),
  (v_pasto3, v_fazenda, 'Pasto 3 - Marandu', 52.00, 1.0, 'Brachiaria brizantha cv. Marandu', 'descanso'),
  (v_pasto4, v_fazenda, 'Pasto 4 - Tifton', 25.00, 2.0, 'Cynodon spp. (Tifton 85)', 'ativo'),
  (v_pasto5, v_fazenda, 'Pasto 5 - Formação', 60.00, 0.0, 'Em formação (Brachiaria)', 'em_formacao')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- LOTES
-- ============================================================
INSERT INTO gado_lotes (id, fazenda_id, nome, categoria, quantidade, pasto_atual_id) VALUES
  (v_lote_eng1, v_fazenda, 'Engorda 01', 'engorda', 42, v_pasto1),
  (v_lote_eng2, v_fazenda, 'Engorda 02', 'engorda', 35, v_pasto2),
  (v_lote_recria, v_fazenda, 'Recria 01', 'recria', 28, v_pasto4),
  (v_lote_cria, v_fazenda, 'Cria 01', 'cria', 15, v_pasto3),
  (v_lote_reprod, v_fazenda, 'Matrizes', 'reprodução', 50, v_pasto1)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- ANIMAIS INDIVIDUAIS (10 com ficha completa)
-- ============================================================
INSERT INTO gado_animais (id, fazenda_id, lote_id, brinco, nome, sexo, raca, data_nascimento, peso_atual_kg, status) VALUES
  (v_animal1, v_fazenda, v_lote_eng1, '001', 'Trovão', 'M', 'Nelore', '2022-03-15', 485.0, 'ativo'),
  (v_animal2, v_fazenda, v_lote_eng1, '002', 'Relâmpago', 'M', 'Nelore', '2022-04-20', 472.0, 'ativo'),
  (v_animal3, v_fazenda, v_lote_eng1, '003', 'Ventania', 'M', 'Nelore', '2022-05-10', 458.0, 'ativo'),
  (v_animal4, v_fazenda, v_lote_eng2, '004', 'Tempestade', 'M', 'Anelorado', '2022-06-01', 445.0, 'ativo'),
  (v_animal5, v_fazenda, v_lote_eng2, '005', 'Furacão', 'M', 'Nelore', '2022-07-18', 430.0, 'ativo'),
  (v_animal6, v_fazenda, v_lote_recria, '006', 'Estrela', 'F', 'Nelore', '2023-02-10', 320.0, 'ativo'),
  (v_animal7, v_fazenda, v_lote_recria, '007', 'Lua', 'F', 'Nelore', '2023-03-22', 305.0, 'ativo'),
  (v_animal8, v_fazenda, v_lote_reprod, '008', 'Princesa', 'F', 'Nelore', '2019-08-15', 520.0, 'ativo'),
  (v_animal9, v_fazenda, v_lote_reprod, '009', 'Rainha', 'F', 'Nelore', '2019-11-20', 535.0, 'ativo'),
  (v_animal10, v_fazenda, v_lote_reprod, '010', 'Imperatriz', 'F', 'Tabapuã', '2020-01-05', 510.0, 'ativo')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- PESAGENS (histórico de 3 meses — simula ganho de peso)
-- ============================================================
INSERT INTO gado_pesagens (fazenda_id, animal_id, lote_id, peso_kg, data) VALUES
  -- Trovão (001) - GMD ~0.9 kg/dia
  (v_fazenda, v_animal1, v_lote_eng1, 420.0, now() - interval '90 days'),
  (v_fazenda, v_animal1, v_lote_eng1, 447.0, now() - interval '60 days'),
  (v_fazenda, v_animal1, v_lote_eng1, 472.0, now() - interval '30 days'),
  (v_fazenda, v_animal1, v_lote_eng1, 485.0, now() - interval '5 days'),
  -- Relâmpago (002) - GMD ~0.85 kg/dia
  (v_fazenda, v_animal2, v_lote_eng1, 410.0, now() - interval '90 days'),
  (v_fazenda, v_animal2, v_lote_eng1, 435.0, now() - interval '60 days'),
  (v_fazenda, v_animal2, v_lote_eng1, 457.0, now() - interval '30 days'),
  (v_fazenda, v_animal2, v_lote_eng1, 472.0, now() - interval '5 days'),
  -- Ventania (003) - GMD ~0.75 kg/dia (abaixo da média)
  (v_fazenda, v_animal3, v_lote_eng1, 398.0, now() - interval '90 days'),
  (v_fazenda, v_animal3, v_lote_eng1, 418.0, now() - interval '60 days'),
  (v_fazenda, v_animal3, v_lote_eng1, 440.0, now() - interval '30 days'),
  (v_fazenda, v_animal3, v_lote_eng1, 458.0, now() - interval '5 days'),
  -- Tempestade (004) - GMD ~0.92 kg/dia
  (v_fazenda, v_animal4, v_lote_eng2, 365.0, now() - interval '90 days'),
  (v_fazenda, v_animal4, v_lote_eng2, 393.0, now() - interval '60 days'),
  (v_fazenda, v_animal4, v_lote_eng2, 420.0, now() - interval '30 days'),
  (v_fazenda, v_animal4, v_lote_eng2, 445.0, now() - interval '5 days'),
  -- Furacão (005) - GMD ~0.88 kg/dia
  (v_fazenda, v_animal5, v_lote_eng2, 352.0, now() - interval '90 days'),
  (v_fazenda, v_animal5, v_lote_eng2, 378.0, now() - interval '60 days'),
  (v_fazenda, v_animal5, v_lote_eng2, 405.0, now() - interval '30 days'),
  (v_fazenda, v_animal5, v_lote_eng2, 430.0, now() - interval '5 days'),
  -- Estrela (006) - recria
  (v_fazenda, v_animal6, v_lote_recria, 260.0, now() - interval '90 days'),
  (v_fazenda, v_animal6, v_lote_recria, 280.0, now() - interval '60 days'),
  (v_fazenda, v_animal6, v_lote_recria, 300.0, now() - interval '30 days'),
  (v_fazenda, v_animal6, v_lote_recria, 320.0, now() - interval '5 days'),
  -- Lua (007) - recria
  (v_fazenda, v_animal7, v_lote_recria, 248.0, now() - interval '90 days'),
  (v_fazenda, v_animal7, v_lote_recria, 268.0, now() - interval '60 days'),
  (v_fazenda, v_animal7, v_lote_recria, 288.0, now() - interval '30 days'),
  (v_fazenda, v_animal7, v_lote_recria, 305.0, now() - interval '5 days');

-- ============================================================
-- TRATAMENTOS / MANEJOS SANITÁRIOS
-- ============================================================
INSERT INTO gado_tratamentos (fazenda_id, animal_id, lote_id, tipo, produto, principio_ativo, via_aplicacao, data_aplicacao, proxima_dose, carencia_carne_dias, quantidade_animais, custo_total) VALUES
  -- Vacinação Aftosa (lote inteiro)
  (v_fazenda, NULL, v_lote_eng1, 'vacinacao', 'Vacina Aftosa Vallée', 'Vírus inativado', 'subcutanea', (now() - interval '60 days')::date, (now() + interval '120 days')::date, 0, 42, 630.00),
  (v_fazenda, NULL, v_lote_eng2, 'vacinacao', 'Vacina Aftosa Vallée', 'Vírus inativado', 'subcutanea', (now() - interval '60 days')::date, (now() + interval '120 days')::date, 0, 35, 525.00),
  (v_fazenda, NULL, v_lote_recria, 'vacinacao', 'Vacina Aftosa Vallée', 'Vírus inativado', 'subcutanea', (now() - interval '60 days')::date, (now() + interval '120 days')::date, 0, 28, 420.00),
  -- Vermifugação
  (v_fazenda, NULL, v_lote_eng1, 'vermifugacao', 'Ivomec Gold', 'Ivermectina 3.15%', 'subcutanea', (now() - interval '45 days')::date, (now() + interval '45 days')::date, 28, 42, 840.00),
  (v_fazenda, NULL, v_lote_recria, 'vermifugacao', 'Ivomec Gold', 'Ivermectina 3.15%', 'subcutanea', (now() - interval '45 days')::date, (now() + interval '45 days')::date, 28, 28, 560.00),
  -- Tratamento individual (Trovão com bicheira)
  (v_fazenda, v_animal1, v_lote_eng1, 'curativo', 'Lepecid Spray', 'Clorpirifós', 'topica', (now() - interval '20 days')::date, NULL, 0, 1, 25.00),
  -- Vitamina ADE no lote de recria
  (v_fazenda, NULL, v_lote_recria, 'vitamina', 'ADE Injetável Zoetis', 'Vitaminas A, D, E', 'intramuscular', (now() - interval '30 days')::date, (now() + interval '60 days')::date, 0, 28, 280.00);

-- ============================================================
-- ESTAÇÃO REPRODUTIVA + EVENTOS
-- ============================================================
INSERT INTO gado_estacoes_reprodutivas (id, fazenda_id, nome, data_inicio, data_fim, tipo, total_matrizes, ativa) VALUES
  (v_estacao1, v_fazenda, 'Estação 2025/1', (now() - interval '120 days')::date, (now() + interval '60 days')::date, 'iatf', 50, true)
ON CONFLICT (id) DO NOTHING;

-- Eventos reprodutivos (3 matrizes com histórico)
INSERT INTO gado_reproducao_eventos (fazenda_id, matriz_id, estacao_id, tipo_evento, data_evento, semen_identificacao, resultado_diagnostico, previsao_parto, custo_total) VALUES
  -- Princesa (008): IATF → DG prenhe → aguardando parto
  (v_fazenda, v_animal8, v_estacao1, 'iatf', (now() - interval '100 days')::date, 'CFM 6040 (Nelore)', NULL, (now() + interval '185 days')::date, 45.00),
  (v_fazenda, v_animal8, v_estacao1, 'diagnostico_gestacao', (now() - interval '70 days')::date, NULL, 'prenhe', (now() + interval '185 days')::date, 30.00),
  -- Rainha (009): IATF → DG vazia → re-inseminada → DG prenhe
  (v_fazenda, v_animal9, v_estacao1, 'iatf', (now() - interval '100 days')::date, 'CFM 6040 (Nelore)', NULL, NULL, 45.00),
  (v_fazenda, v_animal9, v_estacao1, 'diagnostico_gestacao', (now() - interval '70 days')::date, NULL, 'vazia', NULL, 30.00),
  (v_fazenda, v_animal9, v_estacao1, 'iatf', (now() - interval '65 days')::date, 'REM Penhor (Angus)', NULL, (now() + interval '220 days')::date, 55.00),
  (v_fazenda, v_animal9, v_estacao1, 'diagnostico_gestacao', (now() - interval '35 days')::date, NULL, 'prenhe', (now() + interval '220 days')::date, 30.00),
  -- Imperatriz (010): IATF → DG vazia (candidata a descarte)
  (v_fazenda, v_animal10, v_estacao1, 'iatf', (now() - interval '100 days')::date, 'CFM 6040 (Nelore)', NULL, NULL, 45.00),
  (v_fazenda, v_animal10, v_estacao1, 'diagnostico_gestacao', (now() - interval '70 days')::date, NULL, 'vazia', NULL, 30.00);

-- ============================================================
-- MOVIMENTAÇÃO DE PASTO
-- ============================================================
INSERT INTO gado_movimentacoes_pasto (fazenda_id, lote_id, pasto_origem_id, pasto_destino_id, data_movimentacao, motivo, quantidade_animais) VALUES
  (v_fazenda, v_lote_eng1, v_pasto2, v_pasto1, (now() - interval '15 days')::date, 'rotacao', 42),
  (v_fazenda, v_lote_recria, v_pasto3, v_pasto4, (now() - interval '25 days')::date, 'falta_forragem', 28);

-- ============================================================
-- CUSTOS ALOCADOS (simular custos por categoria)
-- ============================================================
INSERT INTO gado_custos_alocados (fazenda_id, lote_id, data_custo, categoria, descricao, valor, origem) VALUES
  -- Engorda 01
  (v_fazenda, v_lote_eng1, (now() - interval '90 days')::date, 'compra', 'Compra 42 bezerros', 88200.00, 'manual'),
  (v_fazenda, v_lote_eng1, (now() - interval '60 days')::date, 'sanidade', 'Vacinação + vermifugação', 1470.00, 'trigger'),
  (v_fazenda, v_lote_eng1, (now() - interval '45 days')::date, 'alimentacao', 'Ração proteinada (90 dias)', 5400.00, 'manual'),
  (v_fazenda, v_lote_eng1, (now() - interval '30 days')::date, 'pastagem', 'Custo de ocupação pasto', 1800.00, 'manual'),
  (v_fazenda, v_lote_eng1, (now() - interval '30 days')::date, 'mao_obra', 'Rateio vaqueiro (90 dias)', 4500.00, 'manual'),
  -- Engorda 02
  (v_fazenda, v_lote_eng2, (now() - interval '80 days')::date, 'compra', 'Compra 35 garrotes', 63000.00, 'manual'),
  (v_fazenda, v_lote_eng2, (now() - interval '60 days')::date, 'sanidade', 'Vacinação Aftosa', 525.00, 'trigger'),
  (v_fazenda, v_lote_eng2, (now() - interval '40 days')::date, 'alimentacao', 'Sal mineral (60 dias)', 2100.00, 'manual'),
  (v_fazenda, v_lote_eng2, (now() - interval '30 days')::date, 'pastagem', 'Custo de ocupação pasto', 1520.00, 'manual'),
  -- Recria 01
  (v_fazenda, v_lote_recria, (now() - interval '60 days')::date, 'sanidade', 'Vacinação + vitamina', 700.00, 'trigger'),
  (v_fazenda, v_lote_recria, (now() - interval '30 days')::date, 'alimentacao', 'Ração bezerros', 2800.00, 'manual');

-- ============================================================
-- CALENDÁRIO SANITÁRIO — REGRAS DA BAHIA
-- ============================================================
INSERT INTO gado_calendario_sanitario_regras (uf, nome, descricao, obrigatorio, mes_inicio, mes_fim, categoria_animal, sexo, idade_min_meses, idade_max_meses, recorrencia, fonte_normativa) VALUES
  ('BA', 'Febre Aftosa - 1ª Etapa', 'Vacinação obrigatória contra Febre Aftosa - 1ª campanha', true, 5, 5, NULL, 'todos', NULL, NULL, 'semestral', 'ADAB/BA'),
  ('BA', 'Febre Aftosa - 2ª Etapa', 'Vacinação obrigatória contra Febre Aftosa - 2ª campanha (animais até 24 meses)', true, 11, 11, NULL, 'todos', 0, 24, 'semestral', 'ADAB/BA'),
  ('BA', 'Brucelose - B19', 'Vacinação de fêmeas 3-8 meses contra Brucelose', true, NULL, NULL, 'cria', 'F', 3, 8, 'unica', 'PNCEBT/MAPA'),
  ('BA', 'Raiva Bovina', 'Vacinação em áreas endêmicas', true, NULL, NULL, NULL, 'todos', 3, NULL, 'anual', 'ADAB/BA'),
  ('BA', 'Clostridiose', 'Recomendado em áreas úmidas/alagadiças', false, NULL, NULL, NULL, 'todos', 3, NULL, 'anual', 'Recomendação técnica');

-- Eventos programados para 2025
INSERT INTO gado_calendario_sanitario_eventos (fazenda_id, regra_id, lote_id, nome, competencia_ano, data_inicio, data_limite, status) VALUES
  (v_fazenda, (SELECT id FROM gado_calendario_sanitario_regras WHERE nome = 'Febre Aftosa - 1ª Etapa' LIMIT 1), v_lote_eng1, 'Aftosa 1ª Etapa - Engorda 01', 2025, '2025-05-01', '2025-05-31', 'realizado'),
  (v_fazenda, (SELECT id FROM gado_calendario_sanitario_regras WHERE nome = 'Febre Aftosa - 1ª Etapa' LIMIT 1), v_lote_eng2, 'Aftosa 1ª Etapa - Engorda 02', 2025, '2025-05-01', '2025-05-31', 'realizado'),
  (v_fazenda, (SELECT id FROM gado_calendario_sanitario_regras WHERE nome = 'Febre Aftosa - 2ª Etapa' LIMIT 1), v_lote_recria, 'Aftosa 2ª Etapa - Recria 01', 2025, '2025-11-01', '2025-11-30', 'pendente'),
  (v_fazenda, (SELECT id FROM gado_calendario_sanitario_regras WHERE nome = 'Brucelose - B19' LIMIT 1), v_lote_cria, 'Brucelose B19 - Bezerras Cria 01', 2025, NULL, NULL, 'programado');

-- ============================================================
-- GTA DE EXEMPLO
-- ============================================================
INSERT INTO gado_gtas (fazenda_id, numero, serie, uf_emissora, finalidade, status, data_emissao, data_validade, propriedade_origem, municipio_origem, uf_origem, propriedade_destino, municipio_destino, uf_destino, quantidade_animais) VALUES
  (v_fazenda, '2025-001234', 'A', 'BA', 'engorda', 'utilizada', (now() - interval '90 days')::date, (now() - interval '60 days')::date, 'Fazenda São José', 'Poções', 'BA', 'Fazenda Lagoa', 'Vitória da Conquista', 'BA', 42);

END;
$$;

-- ============================================================
-- Resumo do seed de pecuária:
--
-- 5 pastos (Braquiarão, Mombaça, Marandu, Tifton, Formação)
-- 5 lotes (Engorda 01/02, Recria 01, Cria 01, Matrizes)
-- 10 animais com ficha individual
-- 28 pesagens (histórico de 90 dias, 4 pesagens cada)
-- 7 tratamentos sanitários (aftosa, ivermectina, vitamina, curativo)
-- 1 estação reprodutiva com 8 eventos (IATF, DG, re-inseminação)
-- 2 movimentações de pasto
-- 11 custos alocados (compra, sanidade, alimentação, pastagem, mão de obra)
-- 5 regras sanitárias da Bahia
-- 4 eventos do calendário sanitário (2025)
-- 1 GTA de entrada
-- ============================================================
