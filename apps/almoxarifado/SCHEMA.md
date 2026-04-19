# Almoxarifado — Schema do banco

Tabelas exclusivas do módulo Almoxarifado no Supabase.
Prefixo: `almox_`

---

## `almox_itens`

```sql
CREATE TABLE almox_itens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id),
  nome            text NOT NULL,
  codigo_interno  text,
  categoria       text NOT NULL,
  unidade         text NOT NULL,
  marca           text,
  saldo           numeric(12,3) DEFAULT 0,
  saldo_minimo    numeric(12,3) DEFAULT 0,
  custo_medio     numeric(12,2) DEFAULT 0,
  localizacao     text,
  foto_url        text,
  validade        date,
  ativo           boolean DEFAULT true,
  criado_em       timestamptz DEFAULT now(),
  atualizado_em   timestamptz DEFAULT now()
);

CREATE INDEX idx_almox_itens_fazenda ON almox_itens(fazenda_id);
CREATE INDEX idx_almox_itens_categoria ON almox_itens(fazenda_id, categoria);
CREATE INDEX idx_almox_itens_saldo_baixo ON almox_itens(fazenda_id)
  WHERE saldo < saldo_minimo AND ativo = true;
```

---

## `almox_setores`

```sql
CREATE TABLE almox_setores (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id    uuid NOT NULL REFERENCES fazendas(id),
  nome          text NOT NULL,
  tipo          text, -- 'pasto' | 'curral' | 'obra' | 'casa' | 'geral'
  referencia_id uuid, -- quando vier de outro app (ex: pasto_id do módulo Pastagem)
  ativo         boolean DEFAULT true,
  criado_em     timestamptz DEFAULT now()
);
```

**Setores padrão criados na instalação:**
- Uso geral
- Curral
- Casa sede
- Galpão de máquinas
- Manutenção
- Consumo próprio

---

## `almox_fornecedores`

```sql
CREATE TABLE almox_fornecedores (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id  uuid NOT NULL REFERENCES fazendas(id),
  nome        text NOT NULL,
  documento   text, -- CNPJ ou CPF
  telefone    text,
  endereco    text,
  observacoes text,
  ativo       boolean DEFAULT true,
  criado_em   timestamptz DEFAULT now()
);
```

---

## `almox_entradas`

Registra cada nota de entrada (pode ter múltiplos itens).

```sql
CREATE TABLE almox_entradas (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid NOT NULL REFERENCES fazendas(id),
  data            timestamptz NOT NULL,
  fornecedor_id   uuid REFERENCES almox_fornecedores(id),
  numero_nota     text,
  foto_nota_url   text,
  valor_total     numeric(12,2) NOT NULL,
  forma_pagamento text, -- 'dinheiro' | 'pix' | 'boleto' | 'cartao' | 'prazo'
  parcelas        integer DEFAULT 1,
  recebido_por    uuid REFERENCES users(id),
  observacoes     text,
  status          text DEFAULT 'confirmado', -- 'confirmado' | 'cancelado'
  criado_em       timestamptz DEFAULT now()
);

CREATE INDEX idx_almox_entradas_fazenda_data ON almox_entradas(fazenda_id, data DESC);
```

---

## `almox_entrada_itens`

Itens de cada entrada.

```sql
CREATE TABLE almox_entrada_itens (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entrada_id     uuid NOT NULL REFERENCES almox_entradas(id) ON DELETE CASCADE,
  item_id        uuid NOT NULL REFERENCES almox_itens(id),
  quantidade     numeric(12,3) NOT NULL,
  valor_unitario numeric(12,2) NOT NULL,
  valor_total    numeric(12,2) GENERATED ALWAYS AS (quantidade * valor_unitario) STORED
);
```

---

## `almox_saidas`

Cada retirada individual.

```sql
CREATE TABLE almox_saidas (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id     uuid NOT NULL REFERENCES fazendas(id),
  data           timestamptz NOT NULL,
  item_id        uuid NOT NULL REFERENCES almox_itens(id),
  quantidade     numeric(12,3) NOT NULL,
  custo_unitario numeric(12,2) NOT NULL, -- snapshot do custo_medio no momento
  custo_total    numeric(12,2) GENERATED ALWAYS AS (quantidade * custo_unitario) STORED,
  setor_id       uuid NOT NULL REFERENCES almox_setores(id),
  retirado_por   uuid REFERENCES users(id),
  liberado_por   uuid REFERENCES users(id),
  motivo         text NOT NULL,
  observacoes    text,
  status         text DEFAULT 'confirmado',
  criado_em      timestamptz DEFAULT now()
);

CREATE INDEX idx_almox_saidas_fazenda_data ON almox_saidas(fazenda_id, data DESC);
CREATE INDEX idx_almox_saidas_setor ON almox_saidas(fazenda_id, setor_id);
CREATE INDEX idx_almox_saidas_item ON almox_saidas(item_id);
```

---

## `almox_ajustes`

Ajustes de inventário.

```sql
CREATE TABLE almox_ajustes (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id     uuid NOT NULL REFERENCES fazendas(id),
  data           timestamptz NOT NULL,
  item_id        uuid NOT NULL REFERENCES almox_itens(id),
  saldo_anterior numeric(12,3) NOT NULL,
  saldo_fisico   numeric(12,3) NOT NULL,
  diferenca      numeric(12,3) GENERATED ALWAYS AS (saldo_fisico - saldo_anterior) STORED,
  motivo         text NOT NULL,
  responsavel    uuid REFERENCES users(id),
  observacoes    text,
  criado_em      timestamptz DEFAULT now()
);
```

---

## `almox_transferencias`

Transferência entre setores (sem mexer no saldo total).

```sql
CREATE TABLE almox_transferencias (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id     uuid NOT NULL REFERENCES fazendas(id),
  data           timestamptz NOT NULL,
  item_id        uuid NOT NULL REFERENCES almox_itens(id),
  quantidade     numeric(12,3) NOT NULL,
  setor_origem   uuid NOT NULL REFERENCES almox_setores(id),
  setor_destino  uuid NOT NULL REFERENCES almox_setores(id),
  motivo         text,
  responsavel    uuid REFERENCES users(id),
  criado_em      timestamptz DEFAULT now()
);
```

---

## Triggers automáticos

### Atualização de saldo e custo médio em entradas

```sql
CREATE OR REPLACE FUNCTION atualizar_saldo_entrada()
RETURNS trigger AS $$
DECLARE
  saldo_atual numeric;
  custo_atual numeric;
BEGIN
  SELECT saldo, custo_medio INTO saldo_atual, custo_atual
  FROM almox_itens WHERE id = NEW.item_id;

  -- Custo médio ponderado
  UPDATE almox_itens SET
    saldo = saldo_atual + NEW.quantidade,
    custo_medio = CASE
      WHEN (saldo_atual + NEW.quantidade) > 0
      THEN ((saldo_atual * custo_atual) + (NEW.quantidade * NEW.valor_unitario))
           / (saldo_atual + NEW.quantidade)
      ELSE NEW.valor_unitario
    END,
    atualizado_em = now()
  WHERE id = NEW.item_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_entrada_saldo
AFTER INSERT ON almox_entrada_itens
FOR EACH ROW EXECUTE FUNCTION atualizar_saldo_entrada();
```

### Atualização de saldo em saídas

```sql
CREATE OR REPLACE FUNCTION atualizar_saldo_saida()
RETURNS trigger AS $$
BEGIN
  UPDATE almox_itens SET
    saldo = saldo - NEW.quantidade,
    atualizado_em = now()
  WHERE id = NEW.item_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_saida_saldo
AFTER INSERT ON almox_saidas
FOR EACH ROW EXECUTE FUNCTION atualizar_saldo_saida();
```

---

## RLS (Row Level Security)

Todas as tabelas precisam ter RLS ativo:

```sql
ALTER TABLE almox_itens           ENABLE ROW LEVEL SECURITY;
ALTER TABLE almox_setores         ENABLE ROW LEVEL SECURITY;
ALTER TABLE almox_fornecedores    ENABLE ROW LEVEL SECURITY;
ALTER TABLE almox_entradas        ENABLE ROW LEVEL SECURITY;
ALTER TABLE almox_entrada_itens   ENABLE ROW LEVEL SECURITY;
ALTER TABLE almox_saidas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE almox_ajustes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE almox_transferencias  ENABLE ROW LEVEL SECURITY;

-- Política padrão: só enxerga dados da própria fazenda
CREATE POLICY almox_itens_fazenda ON almox_itens
  FOR ALL USING (fazenda_id IN (
    SELECT fazenda_padrao FROM users WHERE id = auth.uid()
  ));
-- Replicar a mesma política para todas as outras tabelas
```
