-- ============================================================
-- Cérebro Rural — Migration 0001: Tabelas base
-- Fundação: profiles, fazendas, lancamentos, auditoria
-- ============================================================

-- Extensões necessárias (Supabase já habilita uuid-ossp, mas garantir)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- PROFILES (extensão do auth.users do Supabase)
-- ============================================================
CREATE TABLE profiles (
  id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nome            text,
  telefone        text,
  fazenda_padrao  uuid,  -- FK adicionada após criar fazendas
  papel           text NOT NULL DEFAULT 'dono'
                  CHECK (papel IN ('dono', 'gerente', 'peao', 'contador')),
  avatar_url      text,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE profiles IS 'Perfil do usuário — estende auth.users do Supabase';
COMMENT ON COLUMN profiles.papel IS 'dono = acesso total | gerente = lê tudo, escreve | peao = só app dele | contador = read-only financeiro';

-- ============================================================
-- FAZENDAS (agrupador financeiro / tenant)
-- ============================================================
CREATE TABLE fazendas (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome            text NOT NULL,
  proprietario_id uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  cidade          text,
  estado          text CHECK (char_length(estado) = 2),
  area_total_ha   numeric(10,2),
  ativa           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE fazendas IS 'Agrupador principal — pode ser fazenda, empresa, patrimônio pessoal';

CREATE INDEX idx_fazendas_proprietario ON fazendas(proprietario_id);

-- FK circular: profiles.fazenda_padrao → fazendas
ALTER TABLE profiles
  ADD CONSTRAINT fk_profiles_fazenda_padrao
  FOREIGN KEY (fazenda_padrao) REFERENCES fazendas(id) ON DELETE SET NULL;

-- ============================================================
-- LANCAMENTOS (conector universal — pilar do Cérebro)
-- ============================================================
CREATE TABLE lancamentos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id) ON DELETE RESTRICT,
  app_origem      text NOT NULL,
  categoria       text NOT NULL,
  subcategoria    text,
  tipo            text NOT NULL CHECK (tipo IN ('ENTRADA', 'SAIDA', 'TRANSFERENCIA')),
  valor           numeric(12,2) NOT NULL CHECK (valor >= 0),
  data            timestamptz NOT NULL,
  descricao       text,
  responsavel     uuid REFERENCES profiles(id),
  status          text NOT NULL DEFAULT 'confirmado'
                  CHECK (status IN ('confirmado', 'pendente', 'cancelado', 'rascunho')),
  referencia_id   uuid,
  referencia_tipo text,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE lancamentos IS 'Conector universal — toda transação de qualquer app converge aqui';
COMMENT ON COLUMN lancamentos.app_origem IS 'Qual micro-app gerou: almoxarifado, aluguel, obras, etc.';
COMMENT ON COLUMN lancamentos.categoria IS 'Custo de Produção | Receita | Custo Fixo | Capital | Pessoal';
COMMENT ON COLUMN lancamentos.referencia_id IS 'ID do registro de origem no app específico';
COMMENT ON COLUMN lancamentos.referencia_tipo IS 'Nome da tabela de origem (almox_movimentos, recebimentos_aluguel, etc.)';

CREATE INDEX idx_lanc_fazenda_data     ON lancamentos(fazenda_id, data DESC);
CREATE INDEX idx_lanc_categoria        ON lancamentos(fazenda_id, categoria);
CREATE INDEX idx_lanc_ref              ON lancamentos(referencia_tipo, referencia_id);
CREATE INDEX idx_lanc_app_origem       ON lancamentos(fazenda_id, app_origem);
CREATE INDEX idx_lanc_status           ON lancamentos(fazenda_id, status) WHERE status != 'cancelado';

-- ============================================================
-- AUDITORIA (log de todas as ações do engine/pipeline)
-- ============================================================
CREATE TABLE auditoria (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id      uuid NOT NULL,
  tenant_id       text NOT NULL,
  module          text NOT NULL,
  action          text NOT NULL,
  event           text NOT NULL,
  payload_resumido jsonb,
  user_id         uuid REFERENCES profiles(id),
  ip_address      inet,
  duracao_ms      integer,
  erro            text,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE auditoria IS 'Log imutável — toda passagem pelo pipeline de integridade grava aqui';
COMMENT ON COLUMN auditoria.event IS 'pipeline_start | step_ok | step_fail | execute_ok | execute_fail | commit';

CREATE INDEX idx_audit_tenant_ts   ON auditoria(tenant_id, criado_em DESC);
CREATE INDEX idx_audit_request     ON auditoria(request_id);
CREATE INDEX idx_audit_module      ON auditoria(module, action);

-- ============================================================
-- HELPER: função updated_at automática
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.atualizado_em = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers de updated_at nas tabelas que têm o campo
CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_fazendas_updated_at
  BEFORE UPDATE ON fazendas
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_lancamentos_updated_at
  BEFORE UPDATE ON lancamentos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- HELPER: auto-create profile on auth.users signup
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO profiles (id, nome)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nome', NEW.raw_user_meta_data->>'full_name', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
