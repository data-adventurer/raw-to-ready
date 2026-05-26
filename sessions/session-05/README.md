# Session 05 — Advanced Refactoring: When the Split Isn't Obvious

## What we'll cover
- Queries where the "right" model boundaries aren't immediately clear
- Multi-hop dependencies (models that depend on models that depend on models)
- Currency conversion as a reusable pattern
- Recognising when a calculation belongs in staging vs intermediate vs marts
- Introducing macros as a preview (covered fully in a later session)

---

## Part 1 — When refactoring gets harder

Last session, the split points were relatively clear — each subquery had an obvious purpose and the category normalisation was the main DRY problem.

This session's query is harder. The logic is more entangled, the joins go across more tables, and several parts of it *could* be split in multiple valid ways. There isn't one right answer — but some answers are better than others.

---

## The query

This query was written to answer: *"How is each branch performing, adjusted for foreign-currency transactions? Show quarterly totals in USD alongside a risk flag for branches with high loan delinquency in their customer base."*

```sql
SELECT
    br.branch_id,
    br.branch_name,
    br.region,
    br.state,

    -- Quarterly transaction volumes (USD-converted)
    DATE_TRUNC('quarter', TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD'))  AS txn_quarter,
    COUNT(t.transaction_id)                                                 AS txn_count,

    -- Convert each transaction to USD using the rate on the transaction date.
    -- FX rates are stored WIDE (one column per currency). We pick the right
    -- column using a CASE expression — this is awkward and will need to change
    -- when a new currency is added.
    ROUND(SUM(
        ABS(t.amount) /
        CASE UPPER(TRIM(t.currency))
            WHEN 'EUR' THEN COALESCE(
                (SELECT fx.EUR FROM RAW_TO_READY.RAW.raw_exchange_rates fx
                 WHERE fx.rate_date = TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD')), 1)
            WHEN 'GBP' THEN COALESCE(
                (SELECT fx.GBP FROM RAW_TO_READY.RAW.raw_exchange_rates fx
                 WHERE fx.rate_date = TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD')), 1)
            WHEN 'CAD' THEN COALESCE(
                (SELECT fx.CAD FROM RAW_TO_READY.RAW.raw_exchange_rates fx
                 WHERE fx.rate_date = TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD')), 1)
            WHEN 'MXN' THEN COALESCE(
                (SELECT fx.MXN FROM RAW_TO_READY.RAW.raw_exchange_rates fx
                 WHERE fx.rate_date = TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD')), 1)
            ELSE 1  -- USD or unknown: no conversion
        END
    ), 2)                                                                   AS total_volume_usd,

    -- Delinquency signal: % of the branch's customers who have at least one
    -- delinquent loan. Used to flag branches with elevated credit risk.
    ROUND(
        COUNT(DISTINCT CASE
            WHEN UPPER(TRIM(l.loan_status)) IN ('DELINQUENT','DEFAULT','delinquent','default')
            THEN c.customer_id
        END) * 100.0
        / NULLIF(COUNT(DISTINCT c.customer_id), 0),
        1
    )                                                                       AS delinquent_customer_pct,

    CASE
        WHEN ROUND(
            COUNT(DISTINCT CASE
                WHEN UPPER(TRIM(l.loan_status)) IN ('DELINQUENT','DEFAULT','delinquent','default')
                THEN c.customer_id
            END) * 100.0
            / NULLIF(COUNT(DISTINCT c.customer_id), 0), 1
        ) > 15 THEN 'High risk'
        WHEN ROUND(
            COUNT(DISTINCT CASE
                WHEN UPPER(TRIM(l.loan_status)) IN ('DELINQUENT','DEFAULT','delinquent','default')
                THEN c.customer_id
            END) * 100.0
            / NULLIF(COUNT(DISTINCT c.customer_id), 0), 1
        ) > 5 THEN 'Elevated'
        ELSE 'Normal'
    END                                                                     AS risk_flag

FROM RAW_TO_READY.RAW.raw_branches br

JOIN RAW_TO_READY.RAW.raw_accounts a
    ON br.branch_id = a.branch_id

JOIN RAW_TO_READY.RAW.raw_transactions t
    ON a.account_id = t.account_id
    AND UPPER(TRIM(t.status)) IN ('COMPLETED','COMPLETE','C')

JOIN RAW_TO_READY.RAW.raw_customers c
    ON a.customer_id = c.customer_id

LEFT JOIN RAW_TO_READY.RAW.raw_loans l
    ON c.customer_id = l.customer_id

WHERE TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD') >= '2023-01-01'

GROUP BY
    br.branch_id,
    br.branch_name,
    br.region,
    br.state,
    DATE_TRUNC('quarter', TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD'))

ORDER BY
    br.region,
    br.branch_id,
    txn_quarter;
```

---

## Part 2 — Read it first

Work through these questions before writing any SQL:

1. What does one row in the output represent? (What is the grain?)
2. List every table this query touches. Draw the join chain on paper.
3. The FX conversion uses **correlated subqueries** inside a `CASE`. What's wrong with this approach — both logically and for performance?
4. The `delinquent_customer_pct` calculation and the `risk_flag` `CASE` statement both contain the same delinquency count logic. How many times is it written?
5. The FX rate is fetched by matching `rate_date` to the transaction date. But `raw_exchange_rates` only has weekday rates. What happens to weekend transactions? Is this handled?
6. Should the FX conversion logic live in a staging model, an intermediate model, or a macro? What are the tradeoffs of each?

---

## Challenge

This refactoring is harder — there's no single right answer. Think through the layers before writing any code.

### Step 1: Map the dependencies

Before splitting, map out what depends on what. Fill in a diagram like this:

```
[raw_branches]  [raw_accounts]  [raw_transactions]  [raw_exchange_rates]
      |                |                |                     |
      ?                ?                ?                     ?
                       ...
                       |
               [final output]
```

Which staging models already exist? Which intermediate models would you need to create?

### Step 2: Fix the FX conversion first

The correlated subquery approach for FX is the worst part of this query. Your job is to replace it with a proper JOIN.

The problem: `raw_exchange_rates` is **wide** (one column per currency). To join it properly, you first need to **unpivot** it into a long format — one row per date per currency.

Create `models/intermediate/int_exchange_rates_unpivoted.sql`:

```
Input (wide):
rate_date   | EUR  | GBP  | CAD  | MXN
2023-01-03  | 0.92 | 0.79 | 1.36 | 17.2

Output (long):
rate_date   | currency | rate
2023-01-03  | EUR      | 0.92
2023-01-03  | GBP      | 0.79
2023-01-03  | CAD      | 1.36
2023-01-03  | MXN      | 17.2
```

In Snowflake, you can use `UNPIVOT`:
```sql
select rate_date, currency, rate
from {{ ref('stg_exchange_rates') }}
unpivot (rate for currency in (EUR, GBP, JPY, CAD, MXN, AUD, BRL, CHF))
```

Once you have `int_exchange_rates_unpivoted`, you can replace the correlated subqueries with a clean LEFT JOIN.

### Step 3: Handle the delinquency logic

The delinquency calculation is duplicated inside the same query (in `delinquent_customer_pct` and `risk_flag`). Think about:

- Can this be resolved with a CTE inside the model?
- Or does the customer-level delinquency flag belong in its own model (e.g. `int_customer_loan_status`)?

Hint: if the risk flag would be useful on a customer dimension table too (not just this branch report), it probably belongs in its own model.

### Step 4: Build the full model chain

Create the intermediate models you identified, then build the final mart model:
`models/marts/rpt_branch_quarterly_performance.sql`

This should use only `{{ ref(...) }}` — no raw table paths.

Run the full chain:
```bash
dbt run --select +rpt_branch_quarterly_performance
```

The `+` prefix tells dbt to run all upstream dependencies too.

### Step 5 (stretch): The weekend FX gap

Transactions on weekends have no FX rate. When you LEFT JOIN `int_exchange_rates_unpivoted`, weekend non-USD transactions get `rate = NULL`, which means the conversion falls back to 1 (i.e. treated as USD).

How would you fix this properly? Think about:
- `LAST_VALUE` or `LAG` window functions on the rates table
- A "fill forward" intermediate model that extends rates to cover weekends

You don't need to build it — sketch the SQL and be ready to discuss the tradeoff.

---

## Model boundary cheat sheet

Use this as a guide when you're not sure where logic belongs:

| Situation | Where it goes |
|---|---|
| Renaming, casting, null handling | Staging |
| Joining two staging models | Intermediate |
| FX conversion (needs a lookup) | Intermediate |
| Aggregating to a business grain | Intermediate or mart |
| A calculation used in 3+ models | Extract to a macro |
| Final reporting dataset | Mart |

---

## Where to look
- [UNPIVOT in Snowflake](https://docs.snowflake.com/en/sql-reference/constructs/unpivot)
- [dbt model selection syntax](https://docs.getdbt.com/reference/node-selection/syntax) — the `+` prefix
- [dbt best practices — marts](https://docs.getdbt.com/best-practices/how-we-structure/4-marts)
