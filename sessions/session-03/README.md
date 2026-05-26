# Session 03 — The Staging Layer & Building for Reporting

## What we'll cover
- Completing the staging layer across all 7 sources
- Understanding the business context — what are we actually reporting on?
- Thinking backwards from the dashboard: what metrics matter?
- Introducing the intermediate layer
- Building your first intermediate model

---

## Part 1 — The business context

Before writing any SQL, it's worth asking: **what are we building towards?**

You're a data engineer at a regional bank. The finance and operations teams need a Tableau dashboard that answers questions like:

> *"How much did we transact last quarter, and is that up or down from the same quarter last year?"*

> *"Which branches are growing, and which are declining?"*

> *"What's the breakdown of transaction types by customer segment?"*

> *"How are our loan portfolios performing — how much is current vs delinquent?"*

These questions tell us what we need to build. Let's work backwards.

---

## Part 2 — What metrics do we need?

Think through each question and identify the raw ingredients:

### Transaction performance
| Metric | Source tables needed |
|---|---|
| Total transaction volume (USD) | transactions, exchange_rates |
| Transaction count | transactions |
| Average transaction value | transactions |
| Volume by category | transactions |
| Volume by month / quarter | transactions |
| YoY / MoM growth | transactions (with window functions later) |

### Branch performance
| Metric | Source tables needed |
|---|---|
| Transactions per branch | transactions, accounts, branches |
| New accounts per branch per quarter | branches (wide → unpivoted later) |
| Branch volume by region | branches |

### Customer profile
| Metric | Source tables needed |
|---|---|
| Active vs inactive customers | customers |
| Customers by state | customers |
| Average credit score by segment | customers |
| Customer acquisition over time | customers |

### Loan portfolio
| Metric | Source tables needed |
|---|---|
| Total outstanding balance | loans |
| Loan status breakdown | loans |
| Delinquency rate | loans |

> **Discussion question:** What other questions would a bank's finance team want to answer? What data are we missing?

---

## Part 3 — Complete the staging layer

By the end of this session, all 7 staging models should run cleanly.

Open each of the following and complete the `TODO` sections:
- `stg_customers.sql` — partially scaffolded (your reference)
- `stg_accounts.sql` — started in Session 2 challenge
- `stg_transactions.sql`
- `stg_branches.sql` — pass-through only for now
- `stg_loans.sql`
- `stg_exchange_rates.sql` — pass-through only for now
- `stg_account_snapshots.sql`

Run all staging models:
```bash
dbt run --select staging
```

---

## Part 4 — Introducing the intermediate layer

Staging models are 1:1 with source tables — clean, but not yet joined or enriched.

The **intermediate layer** is where business logic lives:
- Joining staging models together
- Enriching data (e.g. converting currencies to USD)
- Creating reusable building blocks for the marts layer

### Naming convention
Intermediate models are prefixed with `int_`. Examples:
- `int_transactions_enriched` — transactions joined to accounts and customers
- `int_customer_summary` — one row per customer with aggregate metrics

---

## Challenge

**Task 1: Complete the staging layer**

Get all 7 staging models running with `dbt run --select staging`.

For each model, make sure:
- Column names are clean and consistent
- Obvious type casts are applied (e.g. numeric IDs, clean dates)
- The model selects from `{{ source(...) }}`, not a raw table path

**Task 2: Build your first intermediate model**

Create `models/intermediate/int_transactions_enriched.sql`.

This model should join transactions to accounts and customers so each row has:

```
transaction_id
transaction_date
amount
category
status
account_id
account_type
customer_id
customer_first_name
customer_last_name
customer_state
```

Use `{{ ref('stg_transactions') }}`, `{{ ref('stg_accounts') }}`, and `{{ ref('stg_customers') }}`.

```bash
dbt run --select int_transactions_enriched
```

**Task 3 (stretch): Think about the grain**

The "grain" of a model is what one row represents. Before writing SQL, always ask: *what does one row in this model mean?*

- What is the grain of `int_transactions_enriched`? 
- What would the grain of a `int_customer_monthly_summary` model be?
- Write the SQL for `int_customer_monthly_summary` — one row per customer per month, with total transaction amount and count.

---

## Where to look
- [dbt best practices — intermediate models](https://docs.getdbt.com/best-practices/how-we-structure/3-intermediate)
- [ref() function](https://docs.getdbt.com/reference/dbt-jinja-functions/ref)
- [Model DAG in dbt docs](https://docs.getdbt.com/docs/collaborate/explore-projects)
