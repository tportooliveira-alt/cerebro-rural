# supabase/seed/

Dados de **demonstração e teste**. Esses scripts **NÃO** fazem parte da cadeia de migrations.

## Como usar

```bash
# Apenas em ambiente de desenvolvimento / staging:
psql $DATABASE_URL -f supabase/seed/0005_seed_financeiro.sql
psql $DATABASE_URL -f supabase/seed/0010_seed_pecuaria.sql
```

> **NUNCA** executar em produção — os seeds disparam triggers que criam lançamentos financeiros derivados.

## Pré-requisito

As migrations `0001` a `0009` já devem estar aplicadas.
