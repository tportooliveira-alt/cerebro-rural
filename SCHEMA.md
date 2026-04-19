# Schema do banco — Cérebro Rural

Banco: **Supabase (Postgres)**

---

## Tabelas compartilhadas

### `fazendas`
```sql
id              uuid PK DEFAULT gen_random_uuid()
nome            text NOT NULL
proprietario_id uuid FK → users(id)
cidade          text
estado          text
area_total_ha   numeric(10,2)
criado_em       timestamptz DEFAULT now()
```

### `users` (extensão do auth.users do Supabase)
```sql
id              uuid PK (auth.users.id)
nome            text
telefone        text
fazenda_padrao  uuid FK → fazendas(id)
papel           text  -- 'dono' | 'gerente' | 'peao' | 'contador'
```

### `lancamentos` (CONECTOR UNIVERSAL)
```sql
id              uuid PK DEFAULT gen_random_uuid()
fazenda_id      uuid NOT NULL FK → fazendas(id)
app_origem      text NOT NULL
categoria       text NOT NULL
subcategoria    text
tipo            text NOT NULL CHECK (tipo IN ('ENTRADA','SAIDA','TRANSFERENCIA'))
valor           numeric(12,2) NOT NULL
data            timestamptz NOT NULL
descricao       text
responsavel     uuid FK → users(id)
status          text DEFAULT 'confirmado'
referencia_id   uuid
referencia_tipo text
criado_em       timestamptz DEFAULT now()
atualizado_em   timestamptz DEFAULT now()

INDEX idx_lanc_fazenda_data ON (fazenda_id, data DESC)
INDEX idx_lanc_categoria    ON (fazenda_id, categoria)
INDEX idx_lanc_ref          ON (referencia_tipo, referencia_id)
```

---

## Tabelas do app Almoxarifado

### `almox_itens`
```sql
id              uuid PK
fazenda_id      uuid FK → fazendas(id)
nome            text NOT NULL
categoria       text  -- 'Ração' | 'Vacina' | 'Sal' | 'Ferramenta' | 'EPI' | ...
unidade         text  -- 'kg' | 'un' | 'L' | 'saco'
saldo           numeric(10,3) DEFAULT 0
saldo_minimo    numeric(10,3)
custo_medio     numeric(12,2)
ativo           boolean DEFAULT true
```

### `almox_movimentos`
```sql
id              uuid PK
fazenda_id      uuid FK
item_id         uuid FK → almox_itens(id)
tipo            text  -- 'ENTRADA' | 'SAIDA' | 'AJUSTE'
quantidade      numeric(10,3)
valor_unitario  numeric(12,2)
data            timestamptz
responsavel     uuid FK → users(id)
observacao      text
-- Gera automaticamente um registro em `lancamentos` via trigger
```

---

## Tabelas do app Pastagem

### `pastos`
```sql
id              uuid PK
fazenda_id      uuid FK
nome            text NOT NULL
area_ha         numeric(8,2) NOT NULL
ua_por_ha       numeric(5,2) DEFAULT 1
poligono_geojson jsonb
forrageira      text
status          text DEFAULT 'ativo'  -- 'ativo' | 'descanso' | 'interditado'
```

### `pastagem_lotes`
```sql
id              uuid PK
pasto_id        uuid FK → pastos(id)
quantidade      integer
peso_medio_kg   numeric(8,2)
data_entrada    timestamptz
data_saida      timestamptz
```

---

## Tabelas do app Obras

### `obras`
```sql
id              uuid PK
fazenda_id      uuid FK
nome            text
tipo            text  -- 'cerca' | 'curral' | 'galpao' | 'poço' | ...
data_inicio     date
data_prevista   date
status          text  -- 'planejamento' | 'em_andamento' | 'concluida'
orcamento       numeric(12,2)
```

### `obras_medicoes`
```sql
id              uuid PK
obra_id         uuid FK → obras(id)
data            timestamptz
descricao       text
valor           numeric(12,2)
fornecedor      text
-- Gera lançamento automático
```

---

## Tabelas do app Funcionários

### `funcionarios`
```sql
id              uuid PK
fazenda_id      uuid FK
nome            text NOT NULL
cpf             text
cargo           text
salario_base    numeric(12,2)
data_admissao   date
ativo           boolean DEFAULT true
```

### `folha_pagamento`
```sql
id              uuid PK
funcionario_id  uuid FK
competencia     date  -- primeiro dia do mês
valor_liquido   numeric(12,2)
encargos        numeric(12,2)
data_pagamento  timestamptz
-- Gera lançamento automático
```

---

## Tabelas do app Aluguel

### `imoveis`
```sql
id              uuid PK
fazenda_id      uuid FK  -- agrupador financeiro, mesmo que não seja fazenda
nome            text
endereco        text
tipo            text  -- 'casa' | 'comercial' | 'terra' | ...
valor_aluguel   numeric(12,2)
```

### `contratos_aluguel`
```sql
id              uuid PK
imovel_id       uuid FK
inquilino_nome  text
inquilino_doc   text
data_inicio     date
data_fim        date
valor           numeric(12,2)
dia_vencimento  integer
ativo           boolean DEFAULT true
```

### `recebimentos_aluguel`
```sql
id              uuid PK
contrato_id     uuid FK
competencia     date
valor_previsto  numeric(12,2)
valor_recebido  numeric(12,2)
data_recebimento timestamptz
status          text  -- 'pendente' | 'recebido' | 'atrasado'
-- Gera lançamento automático ao confirmar recebimento
```

---

## Trigger universal

Toda tabela que gera movimentação financeira deve ter um trigger que cria automaticamente o registro em `lancamentos`:

```sql
CREATE OR REPLACE FUNCTION criar_lancamento_automatico()
RETURNS trigger AS $$
BEGIN
  INSERT INTO lancamentos (
    fazenda_id, app_origem, categoria, subcategoria,
    tipo, valor, data, descricao, responsavel,
    referencia_id, referencia_tipo
  ) VALUES (
    NEW.fazenda_id,
    TG_ARGV[0],      -- app_origem passado como argumento
    TG_ARGV[1],      -- categoria
    TG_ARGV[2],      -- subcategoria
    TG_ARGV[3],      -- tipo (ENTRADA/SAIDA)
    NEW.valor,
    NEW.data,
    NEW.descricao,
    NEW.responsavel,
    NEW.id,
    TG_TABLE_NAME
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## Row Level Security (RLS)

**Toda tabela precisa de RLS.** Template:

```sql
ALTER TABLE <tabela> ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Produtor só vê sua fazenda"
ON <tabela>
FOR ALL
USING (fazenda_id IN (
  SELECT fazenda_padrao FROM users WHERE id = auth.uid()
));
```
