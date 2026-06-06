-- ============================================================
-- Cérebro Rural — Migration 0003: Trigger universal + triggers por app
-- Toda tabela que gera movimentação financeira escreve em lancamentos
-- ============================================================

-- ============================================================
-- TRIGGER UNIVERSAL: criar_lancamento_automatico()
-- Argumentos (passados via TG_ARGV):
--   [0] app_origem
--   [1] categoria
--   [2] subcategoria
--   [3] tipo (ENTRADA / SAIDA)
-- Campos esperados no NEW: fazenda_id, valor (ou valor_total), data, id
-- Campos opcionais: descricao, responsavel, observacao
-- ============================================================

CREATE OR REPLACE FUNCTION criar_lancamento_automatico()
RETURNS trigger AS $$
DECLARE
  v_valor      numeric(12,2);
  v_data       timestamptz;
  v_descricao  text;
  v_responsavel uuid;
BEGIN
  -- Determinar valor (tenta valor_total, depois valor, depois valor_liquido)
  v_valor := COALESCE(
    CASE WHEN TG_TABLE_NAME = 'almox_movimentos' THEN
      COALESCE(NEW.valor_total, NEW.valor_unitario * NEW.quantidade)
    ELSE NULL END,
    CASE WHEN TG_TABLE_NAME = 'folha_pagamento' THEN NEW.valor_liquido + NEW.encargos
    ELSE NULL END,
    CASE WHEN TG_TABLE_NAME = 'investimentos_aportes' THEN NEW.quantidade * NEW.preco_unitario
    ELSE NULL END
  );

  -- Fallback para campo genérico "valor"
  IF v_valor IS NULL THEN
    BEGIN
      EXECUTE format('SELECT ($1).%I', 'valor') INTO v_valor USING NEW;
    EXCEPTION WHEN OTHERS THEN
      v_valor := 0;
    END;
  END IF;

  -- Se valor é zero ou nulo, não gerar lançamento
  IF v_valor IS NULL OR v_valor <= 0 THEN
    RETURN NEW;
  END IF;

  -- Determinar data
  BEGIN
    EXECUTE format('SELECT ($1).%I', 'data') INTO v_data USING NEW;
  EXCEPTION WHEN OTHERS THEN
    v_data := now();
  END;
  IF v_data IS NULL THEN
    v_data := now();
  END IF;

  -- Determinar descrição
  BEGIN
    EXECUTE format('SELECT COALESCE(($1).%I, ($1).%I, '''')', 'descricao', 'observacao') INTO v_descricao USING NEW;
  EXCEPTION WHEN OTHERS THEN
    v_descricao := TG_TABLE_NAME || ' #' || NEW.id::text;
  END;

  -- Determinar responsável
  BEGIN
    EXECUTE format('SELECT ($1).%I', 'responsavel') INTO v_responsavel USING NEW;
  EXCEPTION WHEN OTHERS THEN
    v_responsavel := NULL;
  END;

  INSERT INTO lancamentos (
    fazenda_id,
    app_origem,
    categoria,
    subcategoria,
    tipo,
    valor,
    data,
    descricao,
    responsavel,
    referencia_id,
    referencia_tipo
  ) VALUES (
    NEW.fazenda_id,
    TG_ARGV[0],       -- app_origem
    TG_ARGV[1],       -- categoria
    TG_ARGV[2],       -- subcategoria
    TG_ARGV[3],       -- tipo (ENTRADA/SAIDA)
    v_valor,
    v_data,
    v_descricao,
    v_responsavel,
    NEW.id,
    TG_TABLE_NAME
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- ALMOXARIFADO — Entrada gera SAIDA no caixa (compra = gasto)
-- ============================================================

-- Entrada de mercadoria → SAIDA financeira (pagou pelo insumo)
CREATE TRIGGER trg_almox_entrada_lancamento
  AFTER INSERT ON almox_movimentos
  FOR EACH ROW
  WHEN (NEW.tipo = 'ENTRADA' AND NEW.valor_unitario IS NOT NULL AND NEW.valor_unitario > 0)
  EXECUTE FUNCTION criar_lancamento_automatico(
    'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA'
  );

-- Saída de mercadoria → registra consumo interno (não gera lançamento financeiro direto,
-- mas alimenta relatório de custo por setor). Lançamento = custo pelo custo médio.
-- NOTA: Descomentar abaixo se quiser gerar lançamento de consumo:
-- CREATE TRIGGER trg_almox_saida_lancamento
--   AFTER INSERT ON almox_movimentos
--   FOR EACH ROW
--   WHEN (NEW.tipo = 'SAIDA')
--   EXECUTE FUNCTION criar_lancamento_automatico(
--     'almoxarifado', 'Custo de Produção', 'Consumo Interno', 'SAIDA'
--   );

-- ============================================================
-- ALMOXARIFADO — Atualizar saldo e custo médio
-- ============================================================

CREATE OR REPLACE FUNCTION almox_atualizar_saldo()
RETURNS trigger AS $$
DECLARE
  v_saldo_atual   numeric(10,3);
  v_custo_atual   numeric(12,2);
  v_novo_saldo    numeric(10,3);
  v_novo_custo    numeric(12,2);
BEGIN
  SELECT saldo, custo_medio INTO v_saldo_atual, v_custo_atual
  FROM almox_itens WHERE id = NEW.item_id FOR UPDATE;

  CASE NEW.tipo
    WHEN 'ENTRADA' THEN
      v_novo_saldo := v_saldo_atual + NEW.quantidade;
      -- Custo médio ponderado
      IF NEW.valor_unitario IS NOT NULL AND NEW.valor_unitario > 0 THEN
        v_novo_custo := (
          (v_saldo_atual * COALESCE(v_custo_atual, 0)) +
          (NEW.quantidade * NEW.valor_unitario)
        ) / NULLIF(v_novo_saldo, 0);
      ELSE
        v_novo_custo := v_custo_atual;
      END IF;

    WHEN 'SAIDA' THEN
      v_novo_saldo := v_saldo_atual - NEW.quantidade;
      v_novo_custo := v_custo_atual;  -- custo médio não muda na saída

    WHEN 'AJUSTE' THEN
      v_novo_saldo := NEW.quantidade;  -- ajuste = saldo físico conferido
      v_novo_custo := v_custo_atual;

    WHEN 'TRANSFERENCIA' THEN
      v_novo_saldo := v_saldo_atual;   -- transferência não altera saldo total
      v_novo_custo := v_custo_atual;
  END CASE;

  UPDATE almox_itens
  SET saldo = COALESCE(v_novo_saldo, 0),
      custo_medio = COALESCE(v_novo_custo, 0)
  WHERE id = NEW.item_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_almox_saldo
  AFTER INSERT ON almox_movimentos
  FOR EACH ROW
  EXECUTE FUNCTION almox_atualizar_saldo();

-- ============================================================
-- OBRAS — Medição aprovada → lançamento SAIDA em Capital
-- ============================================================

CREATE TRIGGER trg_obras_medicao_lancamento
  AFTER INSERT OR UPDATE ON obras_medicoes
  FOR EACH ROW
  WHEN (NEW.aprovada = true)
  EXECUTE FUNCTION criar_lancamento_automatico(
    'obras', 'Capital', 'Obra', 'SAIDA'
  );

-- Atualizar valor_gasto da obra ao aprovar medição
CREATE OR REPLACE FUNCTION obras_atualizar_gasto()
RETURNS trigger AS $$
BEGIN
  IF NEW.aprovada = true AND (OLD IS NULL OR OLD.aprovada = false) THEN
    UPDATE obras
    SET valor_gasto = valor_gasto + NEW.valor
    WHERE id = NEW.obra_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_obras_gasto
  AFTER INSERT OR UPDATE ON obras_medicoes
  FOR EACH ROW
  EXECUTE FUNCTION obras_atualizar_gasto();

-- ============================================================
-- FUNCIONÁRIOS — Folha paga → lançamento SAIDA em Custo Fixo
-- ============================================================

CREATE TRIGGER trg_folha_lancamento
  AFTER INSERT OR UPDATE ON folha_pagamento
  FOR EACH ROW
  WHEN (NEW.status = 'pago')
  EXECUTE FUNCTION criar_lancamento_automatico(
    'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA'
  );

-- ============================================================
-- ALUGUEL — Recebimento confirmado → lançamento ENTRADA
-- ============================================================

CREATE TRIGGER trg_aluguel_lancamento
  AFTER INSERT OR UPDATE ON recebimentos_aluguel
  FOR EACH ROW
  WHEN (NEW.status = 'recebido')
  EXECUTE FUNCTION criar_lancamento_automatico(
    'aluguel', 'Receita', 'Receita Patrimônio', 'ENTRADA'
  );

-- ============================================================
-- VIDA PESSOAL — Gasto → lançamento SAIDA em Pessoal
-- ============================================================

CREATE TRIGGER trg_gasto_pessoal_lancamento
  AFTER INSERT ON gastos_pessoais
  FOR EACH ROW
  EXECUTE FUNCTION criar_lancamento_automatico(
    'vida-pessoal', 'Pessoal', 'Gasto Pessoal', 'SAIDA'
  );

-- ============================================================
-- BOLSA/FII — Provento recebido → lançamento ENTRADA
-- ============================================================

CREATE TRIGGER trg_provento_lancamento
  AFTER INSERT ON investimentos_proventos
  FOR EACH ROW
  EXECUTE FUNCTION criar_lancamento_automatico(
    'bolsa-fii', 'Receita', 'Receita Investimento', 'ENTRADA'
  );

-- ============================================================
-- MANEJO DE GADO — Vacinação → lançamento SAIDA em Custo Produção
-- ============================================================

CREATE TRIGGER trg_vacinacao_lancamento
  AFTER INSERT ON gado_vacinacoes
  FOR EACH ROW
  WHEN (NEW.custo_total IS NOT NULL AND NEW.custo_total > 0)
  EXECUTE FUNCTION criar_lancamento_automatico(
    'manejo-gado', 'Custo de Produção', 'Sanidade', 'SAIDA'
  );
