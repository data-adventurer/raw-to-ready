# Session 02 — YAML, Jinja & Documenting Your Sources

## What we'll cover
- What YAML is and how dbt uses it
- The difference between `source()` and `ref()`
- Using `dbt-utils` to auto-generate source YAML
- Adding column-level documentation and data types
- Minor type casting and field renaming in staging models
- dbt best practices for source models

---

## Part 1 — YAML in dbt

dbt uses YAML files to define metadata about your project — sources, models, tests, and documentation all live in `.yml` files alongside your SQL.

Open `models/staging/_sources.yml`. This file tells dbt:
- Where your raw data lives (database, schema, table name)
- What the columns mean
- What tests to run

Notice that `raw_customers` is fully documented, but the other tables have `TODO` comments. That's your challenge for today.

---

## Part 2 — Jinja basics

dbt models aren't plain SQL — they're **Jinja templates** that compile to SQL before being run.

You already used Jinja in Session 1:
```sql
select * from {{ source('raw_banking', 'raw_transactions') }}
```

The `{{ ... }}` syntax is Jinja. dbt compiles this to the actual Snowflake table path at run time.

Two functions you'll use constantly:

| Function | What it does |
|---|---|
| `{{ source('schema_name', 'table_name') }}` | Refers to a raw source table defined in `_sources.yml` |
| `{{ ref('model_name') }}` | Refers to another dbt model — creates the dependency graph |

> **Rule of thumb:** Use `source()` only in staging models. Every other model should use `ref()` to reference other models, never raw table names directly.

---

## Part 3 — Auto-generating YAML with dbt-utils codegen

Writing YAML by hand is tedious. `dbt-utils` has a macro that does it for you.

### 3.1 Generate source YAML for a table

Run this in a dbt operation (or paste it into a temporary analysis file):

```bash
dbt run-operation generate_source \
  --args '{"schema_name": "RAW", "database_name": "RAW_TO_READY", "table_names": ["raw_accounts"]}'
```

This outputs YAML you can paste directly into `_sources.yml`.

### 3.2 Generate model YAML for an existing model

Once you have a model, generate its YAML documentation:

```bash
dbt run-operation generate_model_yaml \
  --args '{"model_names": ["stg_customers"]}'
```

> **Tip:** The generated YAML is a starting point — you'll still want to add meaningful `description` values. The column names and types are filled in for you.

---

## Part 4 — dbt best practices for staging models

A well-structured staging model follows these conventions:

```sql
-- 1. One CTE per logical step
with source as (
    select * from {{ source('raw_banking', 'raw_table') }}
),

renamed as (
    select
        -- Rename columns to snake_case, consistent naming
        -- Cast to correct types
        -- No business logic yet
    from source
)

select * from renamed
```

**Conventions to follow:**
- One staging model per source table
- Prefix with `stg_` 
- Rename to snake_case (source columns may be mixed case)
- Cast obvious types (numeric IDs, dates that are clean)
- No joins, no aggregations, no business logic
- Column names should be self-documenting

---

## Part 5 — Worked example: stg_customers

Open `models/staging/stg_customers.sql`. This model is partially scaffolded — it shows the structure and has `TODO` comments where you need to fill in the logic.

**Run the current (incomplete) version:**
```bash
dbt run --select stg_customers
```

It will run, but the output won't be clean yet — that's expected.

---

## Challenge

**Task 1: Complete the source documentation**

Open `models/staging/_sources.yml` and add column-level documentation for all tables that have `# TODO` comments:
- `raw_accounts`
- `raw_transactions`
- `raw_branches`
- `raw_loans`
- `raw_exchange_rates`
- `raw_account_snapshots`

Use the `generate_source` macro to get the column names, then add descriptions based on what you observed in Session 1.

**Task 2: Build stg_accounts**

Open `models/staging/stg_accounts.sql` and build the staging model. Use `stg_customers.sql` as a reference.

Focus on:
- Renaming columns consistently
- Casting `balance` from string to numeric
  - Hint: `TRY_CAST(REPLACE(REPLACE(balance, '$', ''), ',', '') AS NUMERIC(18,2))`
- Casting `open_date` to a date type
- Leave `account_type`, `account_status`, and `interest_rate` as VARCHAR for now — we'll normalise those in Session 6

**Task 3 (stretch): Run and validate**

```bash
dbt run --select staging
```

Then check your output in Snowflake:
```sql
-- Verify balance is now numeric
SELECT
    account_id,
    balance,   -- should be a number now, not a string
    account_type
FROM RAW_TO_READY.DEV.stg_accounts
LIMIT 10;
```

---

## Where to look
- [dbt sources](https://docs.getdbt.com/docs/build/sources)
- [dbt-utils codegen](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/)
- [dbt best practices — staging models](https://docs.getdbt.com/best-practices/how-we-structure/2-staging)
- [Jinja in dbt](https://docs.getdbt.com/docs/build/jinja-macros)
