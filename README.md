# raw-to-ready 🏦

A hands-on SQL and dbt training program using a fictional bank dataset. You'll build a production-style data pipeline from raw, messy source data all the way to a Tableau-ready financial reporting layer — using Snowflake and dbt Core.

---

## What you'll build

By the end of this program you will have built a full dbt project that:
- Ingests raw banking data (customers, accounts, transactions, loans, branches) into Snowflake
- Cleans and standardises messy, inconsistent source data
- Structures models into staging → intermediate → marts layers
- Produces clean, tested, documented datasets ready for Tableau dashboards

---

## Prerequisites

- A Snowflake account (free trial is fine — [sign up here](https://signup.snowflake.com/))
- Python 3.8+ installed locally
- A code editor (VS Code recommended)
- Basic SQL familiarity — you don't need to be an expert, but you should be comfortable writing SELECT statements

---

## Tech stack

| Tool | Purpose |
|---|---|
| Snowflake | Cloud data warehouse |
| dbt Core | Transformation framework |
| dbt-utils | Helper macros package |
| Git | Version control |

---

## How to use this repo

1. **Fork** this repository to your own GitHub account
2. **Clone** your fork locally
3. Follow the setup instructions in `sessions/session-01/README.md`
4. Work through each session in order — each one builds on the last
5. The `dbt_project/` folder is your working area. Model files start empty (or with hints) — that's intentional

> **Note:** This repo contains challenges only. Solutions are not included. If you're working through this as part of a guided cohort, solution branches will be shared by your instructor after each session.

---

## Repository structure

```
raw-to-ready/
├── data/
│   └── raw/                  ← Source CSV files — load these into Snowflake
├── dbt_project/
│   ├── dbt_project.yml       ← dbt project configuration
│   ├── profiles.yml.example  ← Connection template (never commit real credentials)
│   ├── packages.yml          ← dbt package dependencies
│   ├── models/
│   │   ├── staging/          ← Your work starts here
│   │   ├── intermediate/     ← Unlocked in Session 3
│   │   └── marts/            ← Unlocked in Session 7+
│   └── macros/               ← Custom Jinja macros (Session 5+)
└── sessions/
    ├── session-01/README.md
    ├── session-02/README.md
    └── ...
```

---

## Sessions overview

| Session | Topic |
|---|---|
| 01 | Environment setup, loading data, your first dbt model |
| 02 | YAML, Jinja & dbt-utils — documenting your sources |
| 03 | Building the staging layer — your first transformations |
| 04 | Refactoring SQL into models — CTEs as building blocks |
| 05 | Advanced refactoring — complex queries and model dependencies |
| 06 | Data cleaning — CASE WHEN, COALESCE, and normalisation |

---

## The dataset

Seven raw CSV files representing a fictional bank's operational data. The data is intentionally messy — inconsistent formats, mixed data types, duplicate records, and ambiguous values. Cleaning it is part of the learning.

| File | Description |
|---|---|
| `raw_customers.csv` | Customer profiles |
| `raw_accounts.csv` | Bank accounts |
| `raw_transactions.csv` | Transaction history (5,000 rows) |
| `raw_branches.csv` | Branch locations and quarterly metrics |
| `raw_loans.csv` | Loan records |
| `raw_exchange_rates.csv` | Daily FX rates |
| `raw_account_snapshots.csv` | Monthly account balance snapshots |

---

## Getting help

Stuck? Check the session README for hints before reaching out. Each README includes a "Where to look" section pointing you to the relevant dbt docs.
