-- ============================================================
-- Cérebro Rural — Seed: dados de teste
-- Usar SOMENTE em ambiente de desenvolvimento / staging
-- ============================================================

-- NOTA: Este seed assume que já existe um auth.user criado via
-- Supabase Auth (signup). Substitua os UUIDs abaixo pelo seu
-- usuário real ao rodar pela primeira vez.

-- IDs fixos para facilitar testes (gerar novos em produção)
DO $$
DECLARE
  v_user_id   uuid := '00000000-0000-0000-0000-000000000001';
  v_fazenda   uuid := '00000000-0000-0000-0000-000000000010';
  v_fazenda2  uuid := '00000000-0000-0000-0000-000000000011';
BEGIN

-- ============================================================
-- Perfil do usuário de teste
-- ============================================================
INSERT INTO profiles (id, nome, telefone, papel) VALUES
  (v_user_id, 'Thiago Oliveira', '77999990000', 'dono')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Fazendas
-- ============================================================
INSERT INTO fazendas (id, nome, proprietario_id, cidade, estado, area_total_ha) VALUES
  (v_fazenda, 'Fazenda Lagoa', v_user_id, 'Vitória da Conquista', 'BA', 450.00),
  (v_fazenda2, 'Patrimônio Pessoal', v_user_id, 'Vitória da Conquista', 'BA', NULL)
ON CONFLICT (id) DO NOTHING;

-- Atribuir fazenda padrão
UPDATE profiles SET fazenda_padrao = v_fazenda WHERE id = v_user_id;

-- ============================================================
-- 50 lançamentos de teste (variados, últimos 3 meses)
-- ============================================================
INSERT INTO lancamentos (fazenda_id, app_origem, categoria, subcategoria, tipo, valor, data, descricao, status) VALUES
  -- Almoxarifado: compras de insumos
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 1200.00, now() - interval '85 days', 'Compra de ração proteinada - 20 sacos', 'confirmado'),
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 480.00, now() - interval '82 days', 'Sal mineral - 8 sacos', 'confirmado'),
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 750.00, now() - interval '78 days', 'Vacinas Aftosa - 500 doses', 'confirmado'),
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 320.00, now() - interval '72 days', 'Vermífugo Ivermectina', 'confirmado'),
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 1850.00, now() - interval '65 days', 'Ração volumosa - 30 sacos', 'confirmado'),
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 560.00, now() - interval '55 days', 'EPI - luvas, botas, chapéu', 'confirmado'),
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 890.00, now() - interval '48 days', 'Ração bezerros - 15 sacos', 'confirmado'),
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 420.00, now() - interval '40 days', 'Sal mineral - 7 sacos', 'confirmado'),
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 2100.00, now() - interval '30 days', 'Combustível diesel - 700L', 'confirmado'),
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 340.00, now() - interval '20 days', 'Material de cerca - arame e grampos', 'confirmado'),

  -- Manejo de gado: vendas
  (v_fazenda, 'manejo-gado', 'Receita', 'Venda de Gado', 'ENTRADA', 48000.00, now() - interval '75 days', 'Venda 40 bois - lote engorda @320/arroba', 'confirmado'),
  (v_fazenda, 'manejo-gado', 'Receita', 'Venda de Gado', 'ENTRADA', 12800.00, now() - interval '45 days', 'Venda 10 novilhas - descarte', 'confirmado'),
  (v_fazenda, 'manejo-gado', 'Receita', 'Venda de Gado', 'ENTRADA', 36000.00, now() - interval '15 days', 'Venda 30 bois - lote confinamento', 'confirmado'),
  (v_fazenda, 'manejo-gado', 'Custo de Produção', 'Sanidade', 'SAIDA', 1500.00, now() - interval '70 days', 'Vacinação Aftosa - 300 cabeças', 'confirmado'),
  (v_fazenda, 'manejo-gado', 'Custo de Produção', 'Sanidade', 'SAIDA', 800.00, now() - interval '35 days', 'Vermifugação geral', 'confirmado'),

  -- Obras
  (v_fazenda, 'obras', 'Capital', 'Obra', 'SAIDA', 8500.00, now() - interval '80 days', 'Medição 1 - Curral novo (fundação)', 'confirmado'),
  (v_fazenda, 'obras', 'Capital', 'Obra', 'SAIDA', 12000.00, now() - interval '60 days', 'Medição 2 - Curral novo (estrutura)', 'confirmado'),
  (v_fazenda, 'obras', 'Capital', 'Obra', 'SAIDA', 4500.00, now() - interval '42 days', 'Cerca elétrica - Pasto 5', 'confirmado'),
  (v_fazenda, 'obras', 'Capital', 'Obra', 'SAIDA', 6800.00, now() - interval '25 days', 'Medição 3 - Curral novo (acabamento)', 'confirmado'),
  (v_fazenda, 'obras', 'Capital', 'Obra', 'SAIDA', 3200.00, now() - interval '10 days', 'Reparo estrada interna', 'confirmado'),

  -- Funcionários
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 4500.00, now() - interval '90 days', 'Folha março - José (vaqueiro)', 'confirmado'),
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 3800.00, now() - interval '90 days', 'Folha março - Pedro (tratorista)', 'confirmado'),
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 2500.00, now() - interval '90 days', 'Folha março - Maria (cozinheira)', 'confirmado'),
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 4500.00, now() - interval '60 days', 'Folha abril - José (vaqueiro)', 'confirmado'),
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 3800.00, now() - interval '60 days', 'Folha abril - Pedro (tratorista)', 'confirmado'),
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 2500.00, now() - interval '60 days', 'Folha abril - Maria (cozinheira)', 'confirmado'),
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 4500.00, now() - interval '30 days', 'Folha maio - José (vaqueiro)', 'confirmado'),
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 3800.00, now() - interval '30 days', 'Folha maio - Pedro (tratorista)', 'confirmado'),
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 2500.00, now() - interval '30 days', 'Folha maio - Maria (cozinheira)', 'confirmado'),
  (v_fazenda, 'funcionarios', 'Custo Fixo', 'Folha de Pagamento', 'SAIDA', 1000.00, now() - interval '50 days', 'Adiantamento José', 'confirmado'),

  -- Aluguel
  (v_fazenda2, 'aluguel', 'Receita', 'Receita Patrimônio', 'ENTRADA', 2800.00, now() - interval '85 days', 'Aluguel casa Rua A - março', 'confirmado'),
  (v_fazenda2, 'aluguel', 'Receita', 'Receita Patrimônio', 'ENTRADA', 2800.00, now() - interval '55 days', 'Aluguel casa Rua A - abril', 'confirmado'),
  (v_fazenda2, 'aluguel', 'Receita', 'Receita Patrimônio', 'ENTRADA', 2800.00, now() - interval '25 days', 'Aluguel casa Rua A - maio', 'confirmado'),
  (v_fazenda2, 'aluguel', 'Receita', 'Receita Patrimônio', 'ENTRADA', 1500.00, now() - interval '80 days', 'Aluguel sala comercial - março', 'confirmado'),
  (v_fazenda2, 'aluguel', 'Receita', 'Receita Patrimônio', 'ENTRADA', 1500.00, now() - interval '50 days', 'Aluguel sala comercial - abril', 'confirmado'),
  (v_fazenda2, 'aluguel', 'Receita', 'Receita Patrimônio', 'ENTRADA', 1500.00, now() - interval '20 days', 'Aluguel sala comercial - maio', 'confirmado'),

  -- Vida pessoal
  (v_fazenda2, 'vida-pessoal', 'Pessoal', 'Transporte', 'SAIDA', 45.00, now() - interval '5 days', 'Uber para aeroporto', 'confirmado'),
  (v_fazenda2, 'vida-pessoal', 'Pessoal', 'Alimentação', 'SAIDA', 142.00, now() - interval '8 days', 'Jantar Outback', 'confirmado'),
  (v_fazenda2, 'vida-pessoal', 'Pessoal', 'Mercado', 'SAIDA', 890.00, now() - interval '12 days', 'Supermercado mensal', 'confirmado'),
  (v_fazenda2, 'vida-pessoal', 'Pessoal', 'Saúde', 'SAIDA', 350.00, now() - interval '18 days', 'Consulta médica', 'confirmado'),
  (v_fazenda2, 'vida-pessoal', 'Pessoal', 'Lazer', 'SAIDA', 200.00, now() - interval '22 days', 'Ingresso show', 'confirmado'),

  -- Bolsa / FII
  (v_fazenda2, 'bolsa-fii', 'Receita', 'Receita Investimento', 'ENTRADA', 320.00, now() - interval '60 days', 'Dividendo BBAS3 - abril', 'confirmado'),
  (v_fazenda2, 'bolsa-fii', 'Receita', 'Receita Investimento', 'ENTRADA', 180.00, now() - interval '58 days', 'Rendimento XPLG11 - abril', 'confirmado'),
  (v_fazenda2, 'bolsa-fii', 'Receita', 'Receita Investimento', 'ENTRADA', 95.00, now() - interval '56 days', 'Rendimento MXRF11 - abril', 'confirmado'),
  (v_fazenda2, 'bolsa-fii', 'Receita', 'Receita Investimento', 'ENTRADA', 320.00, now() - interval '30 days', 'Dividendo BBAS3 - maio', 'confirmado'),
  (v_fazenda2, 'bolsa-fii', 'Receita', 'Receita Investimento', 'ENTRADA', 180.00, now() - interval '28 days', 'Rendimento XPLG11 - maio', 'confirmado'),
  (v_fazenda2, 'bolsa-fii', 'Receita', 'Receita Investimento', 'ENTRADA', 95.00, now() - interval '26 days', 'Rendimento MXRF11 - maio', 'confirmado'),

  -- Lançamentos pendentes (para testar filtro de status)
  (v_fazenda, 'almoxarifado', 'Custo de Produção', 'Insumo', 'SAIDA', 3500.00, now() - interval '2 days', 'Cotação ração - aguardando aprovação', 'pendente'),
  (v_fazenda, 'obras', 'Capital', 'Obra', 'SAIDA', 15000.00, now() - interval '1 day', 'Medição 4 Curral - pendente aprovação', 'pendente'),
  (v_fazenda2, 'aluguel', 'Receita', 'Receita Patrimônio', 'ENTRADA', 2800.00, now() - interval '3 days', 'Aluguel casa Rua A - junho (pendente)', 'pendente');

END;
$$;

-- ============================================================
-- Resumo esperado dos 50 lançamentos:
--
-- ENTRADAS (receitas):
--   Venda de Gado:         R$ 96.800 (3 vendas)
--   Receita Patrimônio:    R$ 15.700 (6 aluguéis + 1 pendente)
--   Receita Investimento:  R$  1.190 (6 proventos)
--   TOTAL ENTRADAS:        ~R$ 113.690
--
-- SAÍDAS (custos):
--   Custo de Produção:     R$ 11.210 (insumos + sanidade + 1 pendente)
--   Custo Fixo (folha):    R$ 34.400 (10 pagtos)
--   Capital (obras):       R$ 50.000 (5 medições + 1 pendente)
--   Pessoal:               R$  1.627 (5 gastos)
--   TOTAL SAÍDAS:          ~R$ 97.237
--
-- SALDO LÍQUIDO:           ~R$ +16.453
-- ============================================================
