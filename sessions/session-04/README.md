# Session 04 — Refactoring SQL into Models: CTEs as Building Blocks

## What we'll cover
- Why long SQL queries are a problem at scale
- How CTEs map to dbt models
- Identifying natural "split points" in a complex query
- Refactoring a real query into a layered model structure

---

## Part 1 — The problem with long queries

Imagine a colleague hands you this query. It was written six months ago, it runs, and nobody is quite sure how it works anymore.

Your job: understand it, then break it into clean, testable dbt models.

---

## The query

This query was written to answer: *"For each customer, what was their transaction behaviour in 2023 vs 2024, and how does their credit score relate to their activity level?"*

```sql
SELECT
    cust_summary.customer_id,
    cust_summary.first_name,
    cust_summary.last_name,
    cust_summary.state,
    cust_summary.credit_score,
    cust_summary.credit_tier,
    cust_summary.total_accounts,
    cust_summary.active_accounts,
    txn_2023.txn_count_2023,
    txn_2023.total_amount_2023,
    txn_2023.avg_amount_2023,
    txn_2023.distinct_categories_2023,
    txn_2024.txn_count_2024,
    txn_2024.total_amount_2024,
    txn_2024.avg_amount_2024,
    txn_2024.distinct_categories_2024,
    ROUND(
        (txn_2024.total_amount_2024 - txn_2023.total_amount_2023)
        / NULLIF(ABS(txn_2023.total_amount_2023), 0) * 100,
        2
    ) AS yoy_change_pct,
    CASE
        WHEN txn_2024.total_amount_2024 > txn_2023.total_amount_2023 THEN 'Growing'
        WHEN txn_2024.total_amount_2024 < txn_2023.total_amount_2023 THEN 'Declining'
        ELSE 'Flat'
    END AS customer_trend
FROM (
    SELECT
        c.customer_id,
        INITCAP(TRIM(c.first_name))  AS first_name,
        INITCAP(TRIM(c.last_name))   AS last_name,
        c.state,
        TRY_CAST(
            NULLIF(NULLIF(c.credit_score, 'N/A'), 'null')
            AS INTEGER
        ) AS credit_score,
        CASE
            WHEN TRY_CAST(NULLIF(NULLIF(c.credit_score, 'N/A'), 'null') AS INTEGER) >= 750 THEN 'Prime'
            WHEN TRY_CAST(NULLIF(NULLIF(c.credit_score, 'N/A'), 'null') AS INTEGER) >= 670 THEN 'Near-prime'
            WHEN TRY_CAST(NULLIF(NULLIF(c.credit_score, 'N/A'), 'null') AS INTEGER) IS NOT NULL THEN 'Subprime'
            ELSE 'Unknown'
        END AS credit_tier,
        COUNT(DISTINCT a.account_id)                                               AS total_accounts,
        COUNT(DISTINCT CASE WHEN UPPER(TRIM(a.account_status)) IN ('ACTIVE','A','1','OPEN')
                            THEN a.account_id END)                                 AS active_accounts
    FROM RAW_TO_READY.RAW.raw_customers c
    LEFT JOIN RAW_TO_READY.RAW.raw_accounts a
        ON c.customer_id = a.customer_id
    WHERE UPPER(TRIM(c.is_active)) IN ('1','TRUE','YES','Y')
    GROUP BY 1, 2, 3, 4, 5, 6
) cust_summary
LEFT JOIN (
    SELECT
        a.customer_id,
        COUNT(t.transaction_id)                        AS txn_count_2023,
        ROUND(SUM(t.amount), 2)                        AS total_amount_2023,
        ROUND(AVG(t.amount), 2)                        AS avg_amount_2023,
        COUNT(DISTINCT
            CASE
                WHEN LOWER(t.category) IN ('food & dining','food','dining','restaurants','f&d') THEN 'Food & Dining'
                WHEN LOWER(t.category) IN ('transfer','xfer','wire transfer','wire')            THEN 'Transfer'
                WHEN LOWER(t.category) IN ('atm','atm withdrawal','cash','atm cash')            THEN 'ATM Withdrawal'
                WHEN LOWER(t.category) IN ('utilities','util','bills','utility')                THEN 'Utilities'
                WHEN LOWER(t.category) IN ('payroll','direct deposit','dd','salary')            THEN 'Payroll'
                WHEN LOWER(t.category) IN ('shopping','retail','purchase')                      THEN 'Shopping'
                WHEN LOWER(t.category) IN ('healthcare','medical','health')                     THEN 'Healthcare'
                WHEN LOWER(t.category) IN ('travel','airline','hotel')                          THEN 'Travel'
                ELSE 'Other'
            END
        )                                              AS distinct_categories_2023
    FROM RAW_TO_READY.RAW.raw_transactions t
    JOIN RAW_TO_READY.RAW.raw_accounts a
        ON t.account_id = a.account_id
    WHERE UPPER(TRIM(t.status)) IN ('COMPLETED','COMPLETE','C')
      AND TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD') >= '2023-01-01'
      AND TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD') <  '2024-01-01'
    GROUP BY 1
) txn_2023
    ON cust_summary.customer_id = txn_2023.customer_id
LEFT JOIN (
    SELECT
        a.customer_id,
        COUNT(t.transaction_id)                        AS txn_count_2024,
        ROUND(SUM(t.amount), 2)                        AS total_amount_2024,
        ROUND(AVG(t.amount), 2)                        AS avg_amount_2024,
        COUNT(DISTINCT
            CASE
                WHEN LOWER(t.category) IN ('food & dining','food','dining','restaurants','f&d') THEN 'Food & Dining'
                WHEN LOWER(t.category) IN ('transfer','xfer','wire transfer','wire')            THEN 'Transfer'
                WHEN LOWER(t.category) IN ('atm','atm withdrawal','cash','atm cash')            THEN 'ATM Withdrawal'
                WHEN LOWER(t.category) IN ('utilities','util','bills','utility')                THEN 'Utilities'
                WHEN LOWER(t.category) IN ('payroll','direct deposit','dd','salary')            THEN 'Payroll'
                WHEN LOWER(t.category) IN ('shopping','retail','purchase')                      THEN 'Shopping'
                WHEN LOWER(t.category) IN ('healthcare','medical','health')                     THEN 'Healthcare'
                WHEN LOWER(t.category) IN ('travel','airline','hotel')                          THEN 'Travel'
                ELSE 'Other'
            END
        )                                              AS distinct_categories_2024
    FROM RAW_TO_READY.RAW.raw_transactions t
    JOIN RAW_TO_READY.RAW.raw_accounts a
        ON t.account_id = a.account_id
    WHERE UPPER(TRIM(t.status)) IN ('COMPLETED','COMPLETE','C')
      AND TRY_TO_DATE(t.transaction_date, 'YYYY-MM-DD') >= '2024-01-01'
    GROUP BY 1
) txn_2024
    ON cust_summary.customer_id = txn_2024.customer_id
ORDER BY
    cust_summary.credit_score DESC NULLS LAST,
    txn_2024.total_amount_2024 DESC NULLS LAST;
```

---

## Part 2 — Read it first

Before refactoring anything, make sure you understand what the query does.

Work through these questions:

1. What does one row in the output represent?
2. How many logical "sections" does this query have? Where do they start and end?
3. What is the `txn_2023` subquery doing? What about `txn_2024`? How are they different?
4. Where is the same logic copy-pasted? (Hint: look at the `CASE` statement for category normalisation)
5. What would break if someone added a new status alias to the source data (e.g. `'DONE'`)? How many places would you need to update?
6. The `credit_score` cleaning logic appears **three times** in the outer subquery. Is that a problem? How would you fix it?

---

## Challenge

### Step 1: Refactor the subqueries into CTEs

Rewrite the query so the three subqueries (`cust_summary`, `txn_2023`, `txn_2024`) become named CTEs:

```sql
with customer_base as (
    -- the cust_summary subquery goes here
),

transactions_2023 as (
    -- the txn_2023 subquery goes here
),

transactions_2024 as (
    -- the txn_2024 subquery goes here
),

final as (
    -- the outer SELECT joins them together
)

select * from final
```

Run it in Snowflake and confirm it produces the same output as the original.

### Step 2: Identify which CTEs should become dbt models

Not every CTE needs to be its own model — but some should be. Ask yourself:
- Would any other query ever need this logic?
- Is it reusable across multiple downstream models?
- Does it represent a distinct "thing" in the business (a customer profile, a transaction summary)?

For each CTE, decide: **model** or **stays as a CTE**?

### Step 3: Build the models

Based on your decision in Step 2, create the dbt models in `models/intermediate/`.

Each model should:
- Use `{{ ref(...) }}` to reference staging models, not raw table paths
- Have a comment at the top describing its grain and purpose
- Not duplicate the category normalisation logic — use a single `CASE` statement in one place and reference it

### Step 4 (stretch): Where should the YoY calculation live?

The `yoy_change_pct` and `customer_trend` columns are derived from the 2023 and 2024 summaries. Should they live in the same model as the join, or in a separate one? Why?

---

## Hint: Spotting the split points

When reading a long query, look for these signals that a subquery or CTE should become its own model:

| Signal | What to do |
|---|---|
| The same subquery appears more than once | Extract to a model, `ref()` it twice |
| A subquery joins multiple tables and aggregates | Strong candidate for its own intermediate model |
| A subquery would be useful for other reports too | Definitely a model |
| A subquery is a simple filter or rename | Probably fine as a CTE |

---

## Where to look
- [dbt best practices — when to use CTEs vs models](https://docs.getdbt.com/best-practices/how-we-structure/3-intermediate)
- [dbt DAG and ref()](https://docs.getdbt.com/docs/build/sql-models#understanding-parent-child-relationships)
