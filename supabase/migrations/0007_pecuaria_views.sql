-- ============================================================
-- Cérebro Rural — Migration 0007: Views de indicadores pecuários
-- GMD, última pesagem, resumo por lote, indicadores reprodutivos,
-- custo por arroba, alertas sanitários
-- ============================================================

-- ############################################################
-- ÚLTIMA PESAGEM POR ANIMAL
-- ############################################################

CREATE OR REPLACE VIEW vw_gado_ultima_pesagem AS
SELECT DISTINCT ON (animal_id)
  id AS pesagem_id,
  animal_id,
  fazenda_id,
  lote_id,
  peso_kg,
  data,
  observacao
FROM gado_pesagens
WHERE animal_id IS NOT NULL
ORDER BY animal_id, data DESC;

COMMENT ON VIEW vw_gado_ultima_pesagem IS 'Última pesagem registrada por animal';

-- ############################################################
-- GMD (Ganho Médio Diário) POR ANIMAL
-- ############################################################

CREATE OR REPLACE VIEW vw_gado_gmd_animal AS
WITH pesagens_ordenadas AS (
  SELECT
    animal_id,
    fazenda_id,
    lote_id,
    peso_kg,
    data,
    LAG(peso_kg) OVER (PARTITION BY animal_id ORDER BY data) AS peso_anterior,
    LAG(data) OVER (PARTITION BY animal_id ORDER BY data) AS data_anterior
  FROM gado_pesagens
  WHERE animal_id IS NOT NULL
)
SELECT
  animal_id,
  fazenda_id,
  lote_id,
  data,
  peso_kg,
  peso_anterior,
  data_anterior,
  CASE
    WHEN data_anterior IS NOT NULL AND (data::date - data_anterior::date) > 0
    THEN ROUND(((peso_kg - peso_anterior)::numeric / (data::date - data_anterior::date)), 3)
    ELSE NULL
  END AS gmd_kg_dia,
  ROUND((peso_kg / 30.0)::numeric, 2) AS arrobas_estimadas,
  CASE
    WHEN data_anterior IS NOT NULL AND (data::date - data_anterior::date) > 0
    THEN (data::date - data_anterior::date)
    ELSE NULL
  END AS dias_entre_pesagens
FROM pesagens_ordenadas;

COMMENT ON VIEW vw_gado_gmd_animal IS 'GMD (ganho médio diário) calculado entre pesagens consecutivas';

-- ############################################################
-- RESUMO POR LOTE
-- ############################################################

CREATE OR REPLACE VIEW vw_gado_resumo_lotes AS
SELECT
  l.id AS lote_id,
  l.fazenda_id,
  l.nome,
  l.categoria,
  l.pasto_atual_id,
  p.nome AS pasto_nome,
  COUNT(a.id) FILTER (WHERE a.status = 'ativo') AS animais_ativos,
  COUNT(a.id) FILTER (WHERE a.status = 'vendido') AS animais_vendidos,
  COUNT(a.id) FILTER (WHERE a.status = 'morto') AS animais_mortos,
  ROUND(AVG(up.peso_kg)::numeric, 1) AS peso_medio_kg,
  ROUND(SUM(up.peso_kg)::numeric, 1) AS peso_total_kg,
  ROUND((SUM(up.peso_kg) / 30.0)::numeric, 1) AS arrobas_totais,
  ROUND(AVG(gmd.gmd_kg_dia)::numeric, 3) AS gmd_medio_lote,
  MIN(up.data) AS pesagem_mais_antiga,
  MAX(up.data) AS pesagem_mais_recente
FROM gado_lotes l
LEFT JOIN gado_animais a ON a.lote_id = l.id AND a.status = 'ativo'
LEFT JOIN vw_gado_ultima_pesagem up ON up.animal_id = a.id
LEFT JOIN LATERAL (
  SELECT gmd_kg_dia
  FROM vw_gado_gmd_animal g
  WHERE g.animal_id = a.id
  ORDER BY g.data DESC
  LIMIT 1
) gmd ON true
LEFT JOIN pastos p ON p.id = l.pasto_atual_id
GROUP BY l.id, l.fazenda_id, l.nome, l.categoria, l.pasto_atual_id, p.nome;

COMMENT ON VIEW vw_gado_resumo_lotes IS 'Resumo consolidado por lote: animais, peso, arrobas, GMD';

-- ############################################################
-- INDICADORES REPRODUTIVOS POR ESTAÇÃO
-- ############################################################

CREATE OR REPLACE VIEW vw_gado_indicadores_reprodutivos AS
WITH eventos AS (
  SELECT
    estacao_id,
    fazenda_id,
    tipo_evento,
    resultado_diagnostico,
    COUNT(*) AS total
  FROM gado_reproducao_eventos
  WHERE estacao_id IS NOT NULL
  GROUP BY estacao_id, fazenda_id, tipo_evento, resultado_diagnostico
)
SELECT
  e.id AS estacao_id,
  e.fazenda_id,
  e.nome AS estacao_nome,
  e.tipo,
  e.data_inicio,
  e.data_fim,
  e.total_matrizes,
  -- Inseminadas/cobertas
  COALESCE(SUM(ev.total) FILTER (WHERE ev.tipo_evento IN ('iatf', 'inseminacao', 'cobricao_natural')), 0) AS total_inseminadas,
  -- Prenhas confirmadas
  COALESCE(SUM(ev.total) FILTER (WHERE ev.resultado_diagnostico = 'prenhe'), 0) AS total_prenhas,
  -- Vazias
  COALESCE(SUM(ev.total) FILTER (WHERE ev.resultado_diagnostico = 'vazia'), 0) AS total_vazias,
  -- Partos
  COALESCE(SUM(ev.total) FILTER (WHERE ev.tipo_evento = 'parto'), 0) AS total_partos,
  -- Abortos
  COALESCE(SUM(ev.total) FILTER (WHERE ev.tipo_evento = 'aborto'), 0) AS total_abortos,
  -- Desmamas
  COALESCE(SUM(ev.total) FILTER (WHERE ev.tipo_evento = 'desmama'), 0) AS total_desmamas,
  -- Taxa de prenhez (%)
  CASE
    WHEN SUM(ev.total) FILTER (WHERE ev.tipo_evento = 'diagnostico_gestacao') > 0
    THEN ROUND(
      (SUM(ev.total) FILTER (WHERE ev.resultado_diagnostico = 'prenhe')::numeric /
       SUM(ev.total) FILTER (WHERE ev.tipo_evento = 'diagnostico_gestacao')) * 100, 1
    )
    ELSE NULL
  END AS taxa_prenhez_percent,
  -- Taxa de parição (%)
  CASE
    WHEN COALESCE(e.total_matrizes, 0) > 0
    THEN ROUND(
      (SUM(ev.total) FILTER (WHERE ev.tipo_evento = 'parto')::numeric / e.total_matrizes) * 100, 1
    )
    ELSE NULL
  END AS taxa_paricao_percent
FROM gado_estacoes_reprodutivas e
LEFT JOIN eventos ev ON ev.estacao_id = e.id
GROUP BY e.id, e.fazenda_id, e.nome, e.tipo, e.data_inicio, e.data_fim, e.total_matrizes;

COMMENT ON VIEW vw_gado_indicadores_reprodutivos IS 'Taxa de prenhez, parição, abortos por estação reprodutiva';

-- ############################################################
-- CUSTO POR ARROBA POR LOTE
-- ############################################################

CREATE OR REPLACE VIEW vw_gado_custo_arroba AS
SELECT
  c.fazenda_id,
  c.lote_id,
  l.nome AS lote_nome,
  l.categoria,
  SUM(c.valor) AS custo_total,
  SUM(c.valor) FILTER (WHERE c.categoria = 'sanidade') AS custo_sanidade,
  SUM(c.valor) FILTER (WHERE c.categoria = 'alimentacao') AS custo_alimentacao,
  SUM(c.valor) FILTER (WHERE c.categoria = 'pastagem') AS custo_pastagem,
  SUM(c.valor) FILTER (WHERE c.categoria = 'mao_obra') AS custo_mao_obra,
  SUM(c.valor) FILTER (WHERE c.categoria = 'compra') AS custo_compra,
  SUM(c.valor) FILTER (WHERE c.categoria = 'frete') AS custo_frete,
  SUM(c.valor) FILTER (WHERE c.categoria = 'comissao') AS custo_comissao,
  SUM(c.valor) FILTER (WHERE c.categoria = 'reproducao') AS custo_reproducao,
  SUM(c.valor) FILTER (WHERE c.categoria = 'outro') AS custo_outros,
  rl.arrobas_totais,
  CASE
    WHEN COALESCE(rl.arrobas_totais, 0) > 0
    THEN ROUND((SUM(c.valor) / rl.arrobas_totais)::numeric, 2)
    ELSE NULL
  END AS custo_por_arroba
FROM gado_custos_alocados c
JOIN gado_lotes l ON l.id = c.lote_id
LEFT JOIN vw_gado_resumo_lotes rl ON rl.lote_id = c.lote_id
WHERE c.lote_id IS NOT NULL
GROUP BY c.fazenda_id, c.lote_id, l.nome, l.categoria, rl.arrobas_totais;

COMMENT ON VIEW vw_gado_custo_arroba IS 'Custo por arroba por lote — breakdown por categoria de custo';

-- ############################################################
-- ALERTAS SANITÁRIOS (carências ativas + doses pendentes)
-- ############################################################

CREATE OR REPLACE VIEW vw_gado_alertas_sanitarios AS
SELECT
  t.fazenda_id,
  t.animal_id,
  a.brinco,
  a.nome AS animal_nome,
  t.lote_id,
  l.nome AS lote_nome,
  'carencia_ativa' AS tipo_alerta,
  t.produto,
  t.carencia_carne_ate AS data_alerta,
  t.carencia_carne_dias || ' dias de carência (carne)' AS mensagem,
  'critico' AS severidade
FROM gado_tratamentos t
LEFT JOIN gado_animais a ON a.id = t.animal_id
LEFT JOIN gado_lotes l ON l.id = t.lote_id
WHERE t.carencia_carne_ate >= CURRENT_DATE
  AND (t.animal_id IS NULL OR a.status = 'ativo')

UNION ALL

SELECT
  t.fazenda_id,
  t.animal_id,
  a.brinco,
  a.nome AS animal_nome,
  t.lote_id,
  l.nome AS lote_nome,
  'dose_pendente' AS tipo_alerta,
  t.produto,
  t.proxima_dose AS data_alerta,
  'Próxima dose em ' || (t.proxima_dose - CURRENT_DATE) || ' dias' AS mensagem,
  CASE
    WHEN t.proxima_dose < CURRENT_DATE THEN 'critico'
    WHEN t.proxima_dose <= CURRENT_DATE + 7 THEN 'alerta'
    ELSE 'info'
  END AS severidade
FROM gado_tratamentos t
LEFT JOIN gado_animais a ON a.id = t.animal_id
LEFT JOIN gado_lotes l ON l.id = t.lote_id
WHERE t.proxima_dose IS NOT NULL
  AND t.proxima_dose <= CURRENT_DATE + 30
  AND (t.animal_id IS NULL OR a.status = 'ativo');

COMMENT ON VIEW vw_gado_alertas_sanitarios IS 'Alertas: animais em carência + doses pendentes nos próximos 30 dias';

-- ############################################################
-- MORTALIDADE / DESFRUTE ANUAL
-- ############################################################

CREATE OR REPLACE VIEW vw_gado_indicadores_rebanho AS
SELECT
  a.fazenda_id,
  EXTRACT(YEAR FROM COALESCE(a.atualizado_em, a.criado_em))::integer AS ano,
  COUNT(*) FILTER (WHERE a.status = 'ativo') AS rebanho_atual,
  COUNT(*) FILTER (WHERE a.status = 'vendido') AS vendidos,
  COUNT(*) FILTER (WHERE a.status = 'morto') AS mortos,
  -- Taxa de mortalidade
  CASE
    WHEN COUNT(*) > 0
    THEN ROUND((COUNT(*) FILTER (WHERE a.status = 'morto')::numeric / COUNT(*)) * 100, 2)
    ELSE 0
  END AS taxa_mortalidade_percent,
  -- Desfrute (vendidos / rebanho inicial estimado)
  CASE
    WHEN COUNT(*) > 0
    THEN ROUND((COUNT(*) FILTER (WHERE a.status = 'vendido')::numeric / COUNT(*)) * 100, 2)
    ELSE 0
  END AS taxa_desfrute_percent,
  -- Nascimentos no período
  (SELECT COUNT(*) FROM gado_nascimentos n
   WHERE n.fazenda_id = a.fazenda_id
   AND EXTRACT(YEAR FROM n.data_nascimento) = EXTRACT(YEAR FROM COALESCE(a.atualizado_em, a.criado_em))
   AND n.resultado = 'vivo') AS nascimentos_vivos
FROM gado_animais a
GROUP BY a.fazenda_id, EXTRACT(YEAR FROM COALESCE(a.atualizado_em, a.criado_em));

COMMENT ON VIEW vw_gado_indicadores_rebanho IS 'Indicadores anuais: mortalidade, desfrute, nascimentos';
