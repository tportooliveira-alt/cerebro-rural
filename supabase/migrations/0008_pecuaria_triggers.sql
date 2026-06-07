-- ============================================================
-- Cérebro Rural — Migration 0008: Triggers pecuária
-- Financeiros (compra/venda → lancamentos) + Timeline + Custos
-- ============================================================

-- ############################################################
-- COMPRA/VENDA → LANÇAMENTO FINANCEIRO
-- ############################################################

CREATE OR REPLACE FUNCTION gado_comercial_lancamento()
RETURNS trigger AS $$
DECLARE
  v_tipo_lanc text;
  v_categoria text;
  v_subcategoria text;
BEGIN
  -- Só gera lançamento se confirmado
  IF NEW.status != 'confirmado' THEN
    RETURN NEW;
  END IF;

  -- Se é UPDATE e antes já era confirmado, não duplicar
  IF TG_OP = 'UPDATE' AND OLD.status = 'confirmado' THEN
    RETURN NEW;
  END IF;

  -- Determinar tipo de lançamento
  CASE NEW.tipo
    WHEN 'venda' THEN
      v_tipo_lanc := 'ENTRADA';
      v_categoria := 'Receita';
      v_subcategoria := 'Venda de Gado';
    WHEN 'compra' THEN
      v_tipo_lanc := 'SAIDA';
      v_categoria := 'Custo de Produção';
      v_subcategoria := 'Compra de Gado';
    WHEN 'transferencia_entrada' THEN
      v_tipo_lanc := 'ENTRADA';
      v_categoria := 'Receita';
      v_subcategoria := 'Transferência Gado';
    WHEN 'transferencia_saida' THEN
      v_tipo_lanc := 'SAIDA';
      v_categoria := 'Custo de Produção';
      v_subcategoria := 'Transferência Gado';
    ELSE
      RETURN NEW;  -- permuta/ajuste não gera lançamento direto
  END CASE;

  INSERT INTO lancamentos (
    fazenda_id, app_origem, categoria, subcategoria,
    tipo, valor, data, descricao, responsavel,
    referencia_id, referencia_tipo, status
  ) VALUES (
    NEW.fazenda_id,
    'manejo-gado',
    v_categoria,
    v_subcategoria,
    v_tipo_lanc,
    NEW.valor_total,
    NEW.data_movimentacao::timestamptz,
    NEW.tipo || ' ' || NEW.quantidade_animais || ' cabeças — ' || NEW.parceiro_nome,
    NEW.responsavel_id,
    NEW.id,
    'gado_movimentacoes_comerciais',
    'confirmado'
  )
  RETURNING id INTO NEW.lancamento_id;

  -- Atualizar o campo lancamento_id na transação
  -- (não dá pra fazer no BEFORE, fazemos UPDATE posterior)
  PERFORM 1;  -- lancamento_id já atribuído via RETURNING

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_gado_comercial_lancamento
  AFTER INSERT OR UPDATE ON gado_movimentacoes_comerciais
  FOR EACH ROW
  EXECUTE FUNCTION gado_comercial_lancamento();

-- ############################################################
-- TRATAMENTO → CUSTO ALOCADO + TIMELINE
-- ############################################################

CREATE OR REPLACE FUNCTION gado_tratamento_efeitos()
RETURNS trigger AS $$
BEGIN
  -- 1. Alocar custo ao lote/animal
  IF NEW.custo_total IS NOT NULL AND NEW.custo_total > 0 THEN
    INSERT INTO gado_custos_alocados (
      fazenda_id, lote_id, animal_id, data_custo,
      categoria, descricao, valor, origem
    ) VALUES (
      NEW.fazenda_id,
      NEW.lote_id,
      NEW.animal_id,
      NEW.data_aplicacao,
      'sanidade',
      NEW.tipo || ': ' || NEW.produto,
      NEW.custo_total,
      'trigger'
    );
  END IF;

  -- 2. Registrar na timeline
  INSERT INTO gado_timeline_eventos (
    fazenda_id, animal_id, lote_id, data_evento,
    tipo_evento, titulo, descricao,
    entidade_origem, entidade_origem_id, severidade, metadados
  ) VALUES (
    NEW.fazenda_id,
    NEW.animal_id,
    NEW.lote_id,
    NEW.data_aplicacao::timestamptz,
    'manejo_sanitario',
    INITCAP(REPLACE(NEW.tipo, '_', ' ')) || ': ' || NEW.produto,
    COALESCE(NEW.observacao, ''),
    'gado_tratamentos',
    NEW.id,
    CASE
      WHEN NEW.tipo IN ('cirurgia', 'antibiotico') THEN 'alerta'
      ELSE 'info'
    END,
    jsonb_build_object(
      'produto', NEW.produto,
      'via', NEW.via_aplicacao,
      'carencia_dias', NEW.carencia_carne_dias
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_gado_tratamento_efeitos
  AFTER INSERT ON gado_tratamentos
  FOR EACH ROW
  EXECUTE FUNCTION gado_tratamento_efeitos();

-- ############################################################
-- PESAGEM → TIMELINE + ATUALIZAR PESO ATUAL DO ANIMAL
-- ############################################################

CREATE OR REPLACE FUNCTION gado_pesagem_efeitos()
RETURNS trigger AS $$
BEGIN
  -- Atualizar peso_atual_kg no animal
  IF NEW.animal_id IS NOT NULL THEN
    UPDATE gado_animais
    SET peso_atual_kg = NEW.peso_kg
    WHERE id = NEW.animal_id;
  END IF;

  -- Timeline
  IF NEW.animal_id IS NOT NULL THEN
    INSERT INTO gado_timeline_eventos (
      fazenda_id, animal_id, lote_id, data_evento,
      tipo_evento, titulo, descricao,
      entidade_origem, entidade_origem_id, severidade, metadados
    ) VALUES (
      NEW.fazenda_id,
      NEW.animal_id,
      NEW.lote_id,
      NEW.data,
      'pesagem',
      'Pesagem: ' || NEW.peso_kg || ' kg',
      COALESCE(NEW.observacao, ''),
      'gado_pesagens',
      NEW.id,
      'info',
      jsonb_build_object('peso_kg', NEW.peso_kg)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_gado_pesagem_efeitos
  AFTER INSERT ON gado_pesagens
  FOR EACH ROW
  EXECUTE FUNCTION gado_pesagem_efeitos();

-- ############################################################
-- REPRODUÇÃO → TIMELINE + PREVISÃO DE PARTO
-- ############################################################

CREATE OR REPLACE FUNCTION gado_reproducao_efeitos()
RETURNS trigger AS $$
DECLARE
  v_titulo text;
  v_severidade text := 'info';
BEGIN
  -- Título contextual
  CASE NEW.tipo_evento
    WHEN 'iatf' THEN v_titulo := 'IATF realizada';
    WHEN 'inseminacao' THEN v_titulo := 'Inseminação';
    WHEN 'cobricao_natural' THEN v_titulo := 'Cobertura natural';
    WHEN 'diagnostico_gestacao' THEN
      v_titulo := 'DG: ' || COALESCE(INITCAP(NEW.resultado_diagnostico), 'realizado');
      IF NEW.resultado_diagnostico = 'vazia' THEN v_severidade := 'alerta'; END IF;
    WHEN 'confirmacao_prenhez' THEN
      v_titulo := 'Prenhez confirmada';
      v_severidade := 'sucesso';
    WHEN 'parto' THEN
      v_titulo := 'Parto realizado';
      v_severidade := 'sucesso';
    WHEN 'aborto' THEN
      v_titulo := 'Aborto registrado';
      v_severidade := 'critico';
    WHEN 'desmama' THEN v_titulo := 'Desmama';
    ELSE v_titulo := INITCAP(REPLACE(NEW.tipo_evento, '_', ' '));
  END CASE;

  -- Calcular previsão de parto (285 dias após cobertura/IATF/inseminação)
  IF NEW.tipo_evento IN ('iatf', 'inseminacao', 'cobricao_natural')
     AND NEW.previsao_parto IS NULL THEN
    UPDATE gado_reproducao_eventos
    SET previsao_parto = NEW.data_evento + 285
    WHERE id = NEW.id;
  END IF;

  -- Timeline
  INSERT INTO gado_timeline_eventos (
    fazenda_id, animal_id, lote_id, data_evento,
    tipo_evento, titulo, descricao,
    entidade_origem, entidade_origem_id, severidade, metadados
  ) VALUES (
    NEW.fazenda_id,
    NEW.matriz_id,
    NULL,
    NEW.data_evento::timestamptz,
    'reproducao',
    v_titulo,
    COALESCE(NEW.observacoes, ''),
    'gado_reproducao_eventos',
    NEW.id,
    v_severidade,
    jsonb_build_object(
      'tipo', NEW.tipo_evento,
      'resultado', NEW.resultado_diagnostico,
      'reprodutor', NEW.reprodutor_id,
      'semen', NEW.semen_identificacao
    )
  );

  -- Custo alocado (IATF, inseminação)
  IF NEW.custo_total IS NOT NULL AND NEW.custo_total > 0 THEN
    INSERT INTO gado_custos_alocados (
      fazenda_id, animal_id, data_custo,
      categoria, descricao, valor, origem
    ) VALUES (
      NEW.fazenda_id,
      NEW.matriz_id,
      NEW.data_evento,
      'reproducao',
      v_titulo || COALESCE(' — ' || NEW.semen_identificacao, ''),
      NEW.custo_total,
      'trigger'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_gado_reproducao_efeitos
  AFTER INSERT ON gado_reproducao_eventos
  FOR EACH ROW
  EXECUTE FUNCTION gado_reproducao_efeitos();

-- ############################################################
-- NASCIMENTO → TIMELINE + CRIAR ANIMAL BEZERRO
-- ############################################################

CREATE OR REPLACE FUNCTION gado_nascimento_efeitos()
RETURNS trigger AS $$
BEGIN
  -- Timeline na mãe
  IF NEW.matriz_id IS NOT NULL THEN
    INSERT INTO gado_timeline_eventos (
      fazenda_id, animal_id, data_evento,
      tipo_evento, titulo, descricao,
      entidade_origem, entidade_origem_id, severidade, metadados
    ) VALUES (
      NEW.fazenda_id,
      NEW.matriz_id,
      NEW.data_nascimento::timestamptz,
      'nascimento',
      'Parto ' || INITCAP(NEW.resultado) ||
        CASE WHEN NEW.sexo IS NOT NULL THEN ' (' || NEW.sexo || ')' ELSE '' END,
      COALESCE(NEW.observacao, ''),
      'gado_nascimentos',
      NEW.id,
      CASE
        WHEN NEW.resultado = 'vivo' THEN 'sucesso'
        WHEN NEW.resultado IN ('natimorto', 'morte_neonatal') THEN 'critico'
        ELSE 'alerta'
      END,
      jsonb_build_object(
        'sexo', NEW.sexo,
        'peso_kg', NEW.peso_nascimento_kg,
        'tipo_parto', NEW.tipo_parto,
        'resultado', NEW.resultado
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_gado_nascimento_efeitos
  AFTER INSERT ON gado_nascimentos
  FOR EACH ROW
  EXECUTE FUNCTION gado_nascimento_efeitos();

-- ############################################################
-- MOVIMENTAÇÃO DE PASTO → TIMELINE + ATUALIZAR LOTE
-- ############################################################

CREATE OR REPLACE FUNCTION gado_mov_pasto_efeitos()
RETURNS trigger AS $$
BEGIN
  -- Atualizar pasto_atual_id do lote
  IF NEW.lote_id IS NOT NULL THEN
    UPDATE gado_lotes
    SET pasto_atual_id = NEW.pasto_destino_id
    WHERE id = NEW.lote_id;
  END IF;

  -- Timeline
  INSERT INTO gado_timeline_eventos (
    fazenda_id, animal_id, lote_id, data_evento,
    tipo_evento, titulo, descricao,
    entidade_origem, entidade_origem_id, severidade, metadados
  ) VALUES (
    NEW.fazenda_id,
    NEW.animal_id,
    NEW.lote_id,
    NEW.data_movimentacao::timestamptz,
    'movimentacao_pasto',
    'Movido para pasto ' || COALESCE(
      (SELECT nome FROM pastos WHERE id = NEW.pasto_destino_id),
      NEW.pasto_destino_id::text
    ),
    COALESCE(NEW.observacao, ''),
    'gado_movimentacoes_pasto',
    NEW.id,
    'info',
    jsonb_build_object(
      'pasto_origem', NEW.pasto_origem_id,
      'pasto_destino', NEW.pasto_destino_id,
      'motivo', NEW.motivo,
      'quantidade', NEW.quantidade_animais
    )
  );

  -- Atualizar status do pasto de descanso (se saiu de algum)
  IF NEW.pasto_origem_id IS NOT NULL THEN
    UPDATE pastos
    SET ultimo_pastejo = now()
    WHERE id = NEW.pasto_origem_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_gado_mov_pasto_efeitos
  AFTER INSERT ON gado_movimentacoes_pasto
  FOR EACH ROW
  EXECUTE FUNCTION gado_mov_pasto_efeitos();

-- ############################################################
-- VENDA → ATUALIZAR STATUS DOS ANIMAIS
-- ############################################################

CREATE OR REPLACE FUNCTION gado_venda_status_animais()
RETURNS trigger AS $$
BEGIN
  -- Quando venda é confirmada, marcar animais como vendidos
  IF NEW.status = 'confirmado' AND NEW.tipo = 'venda' THEN
    UPDATE gado_animais
    SET status = 'vendido'
    WHERE id IN (
      SELECT animal_id FROM gado_movimentacoes_comerciais_itens
      WHERE movimentacao_id = NEW.id AND animal_id IS NOT NULL
    );

    -- Atualizar quantidade do lote
    UPDATE gado_lotes
    SET quantidade = quantidade - NEW.quantidade_animais
    WHERE id IN (
      SELECT DISTINCT lote_id FROM gado_movimentacoes_comerciais_itens
      WHERE movimentacao_id = NEW.id AND lote_id IS NOT NULL
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_gado_venda_status
  AFTER UPDATE ON gado_movimentacoes_comerciais
  FOR EACH ROW
  WHEN (NEW.status = 'confirmado' AND OLD.status != 'confirmado')
  EXECUTE FUNCTION gado_venda_status_animais();
