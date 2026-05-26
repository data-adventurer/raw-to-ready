# Session 06 — TBD: Continued Refactoring or Data Cleaning

> **Instructor note:** This session is intentionally flexible. Depending on how Sessions 4 and 5 go, this will either be:
>
> **Option A:** More time on model refactoring — if the group needs it, work through anything unfinished from Sessions 4–5, or extend with the stretch challenges.
>
> **Option B:** Introduction to data cleaning — CASE WHEN, COALESCE, and normalising the messy columns in the staging layer.
>
> Both options are included below. The data cleaning content will be needed before Session 7 regardless, so even if you run Option A today, Option B will happen in the next session.

---

## Option A — Refactoring continued

### Consolidating what we've built

By now you should have a working model chain from raw → staging → intermediate → mart.

Take stock of what exists:

```bash
dbt ls --select staging        # list all staging models
dbt ls --select intermediate   # list all intermediate models
dbt run                        # run everything
dbt test                       # run any tests (we'll add more in a later session)
```

### Stretch challenges from Sessions 4 & 5

If you haven't done these yet, pick one:

**From Session 4:**
- Solve the `credit_score` duplication — the cleaning logic appears 3 times in the `cust_summary` subquery. How would you refactor it so it only lives in one place? (Hint: a CTE or a staging model)

**From Session 5:**
- Build the "fill-forward" FX rates model that extends weekend rates from the last available weekday rate
- Add a `total_volume_usd` column to `int_transactions_enriched` using the unpivoted FX lookup

### DAG review

Pull up the dbt DAG (`dbt docs generate && dbt docs serve`) and review the lineage graph with the group.

Questions to discuss:
- Does the shape of the DAG make sense for the business logic?
- Are there any models that have too many upstream dependencies (a "god model")?
- Are there any duplicated join paths?

---

## Option B — Data Cleaning: CASE WHEN & COALESCE

### The problem

Open `RAW_TO_READY.RAW.raw_accounts` in Snowflake and run:

```sql
SELECT DISTINCT account_type, COUNT(*) as n
FROM RAW_TO_READY.RAW.raw_accounts
GROUP BY 1
ORDER BY 2 DESC;
```

You'll see something like:

```
account_type          | n
----------------------+----
checking              | 52
Checking              | 49
CHK                   | 47
CHECKING              | 45
checking account      | 41
SAV                   | 40
...
```

Eight different strings. All meaning the same four account types. This is the data cleaning problem.

---

### CASE WHEN — the Swiss Army knife of data cleaning

`CASE WHEN` is how you normalise values that should be the same but aren't:

```sql
SELECT
    account_id,
    account_type AS account_type_raw,  -- keep original for debugging
    CASE
        WHEN UPPER(TRIM(account_type)) IN ('CHK', 'CHECKING', 'CHECKING ACCOUNT') THEN 'Checking'
        WHEN UPPER(TRIM(account_type)) IN ('SAV', 'SAVINGS', 'SAVINGS ACCOUNT')   THEN 'Savings'
        WHEN UPPER(TRIM(account_type)) IN ('LOC', 'LINE OF CREDIT', 'CREDIT')     THEN 'Line of Credit'
        WHEN UPPER(TRIM(account_type)) IN ('CD', 'CERTIFICATE OF DEPOSIT',
                                           'CERT_DEPOSIT', 'CERTDEPOSIT')          THEN 'CD'
        ELSE 'Unknown'
    END AS account_type
FROM RAW_TO_READY.RAW.raw_accounts;
```

Key details:
- `UPPER(TRIM(...))` normalises before comparison — never compare mixed-case strings directly
- `IN (...)` handles multiple aliases in one clause
- `ELSE 'Unknown'` is a safety net — always include it so you can spot new aliases you haven't handled yet

---

### COALESCE — handling nulls and null disguises

The dataset uses several "null disguises" — values that should be NULL but aren't:

```sql
-- These should all be NULL:
SELECT email FROM raw_customers WHERE email IN ('N/A', 'null', 'NULL', 'unknown', 'na', 'NA', '');
```

The pattern to clean them:

```sql
-- Step 1: NULLIF converts a specific value to NULL
NULLIF(email, 'N/A')         -- 'N/A' → NULL, anything else unchanged

-- Step 2: Chain them for multiple disguises
NULLIF(NULLIF(NULLIF(NULLIF(LOWER(TRIM(email)), 'n/a'), 'null'), 'na'), '')
-- reads: lowercase and trim, then null out 'n/a', then 'null', then 'na', then ''

-- Step 3: COALESCE picks the first non-null value
COALESCE(cleaned_email, 'no-email@placeholder.com')
-- if the email is NULL, use a fallback
```

---

### Challenge

**Task 1: Complete `stg_accounts.sql`**

Add the normalisation logic for:
- `account_type` — 8 aliases → 4 canonical values
- `account_status` — 6 aliases → 3 canonical values (`Active`, `Closed`, `Inactive`)
- `interest_rate` — 3 formats → always a decimal between 0 and 1
  - `'5.5%'` → `0.055`
  - `'5.5'` → `0.055`
  - `'0.055'` → `0.055`
  - Hint: check if the value contains `%` first, then whether it's > 1

```sql
-- Skeleton for interest_rate normalisation
CASE
    WHEN interest_rate LIKE '%\%%' ESCAPE '\'
        THEN TRY_CAST(REPLACE(interest_rate, '%', '') AS FLOAT) / 100
    WHEN TRY_CAST(interest_rate AS FLOAT) > 1
        THEN TRY_CAST(interest_rate AS FLOAT) / 100
    ELSE
        TRY_CAST(interest_rate AS FLOAT)
END AS interest_rate
```

**Task 2: Complete `stg_transactions.sql`**

Normalise `category` — it has 5–8 aliases per category. Write the `CASE WHEN` to map them all to canonical values:
`Food & Dining`, `Transfer`, `ATM Withdrawal`, `Utilities`, `Payroll`, `Shopping`, `Healthcare`, `Travel`, `Other`

Also normalise `status` and `transaction_type`.

**Task 3: Verify with a query**

After running your updated models:

```bash
dbt run --select stg_accounts stg_transactions
```

```sql
-- Check: should now be exactly 4 distinct values
SELECT DISTINCT account_type FROM RAW_TO_READY.DEV.stg_accounts;

-- Check: should now be exactly 9 distinct values
SELECT DISTINCT category FROM RAW_TO_READY.DEV.stg_transactions;

-- Check: interest_rate should always be between 0 and 0.2
SELECT
    MIN(interest_rate) as min_rate,
    MAX(interest_rate) as max_rate,
    COUNT(CASE WHEN interest_rate > 1 THEN 1 END) as bad_rows  -- should be 0
FROM RAW_TO_READY.DEV.stg_accounts;
```

**Task 4 (stretch): The `ELSE 'Unknown'` audit**

Run this after cleaning:

```sql
SELECT account_type, COUNT(*) FROM RAW_TO_READY.DEV.stg_accounts WHERE account_type = 'Unknown' GROUP BY 1;
SELECT category, COUNT(*) FROM RAW_TO_READY.DEV.stg_transactions WHERE category = 'Other' GROUP BY 1;
```

If you get unexpected rows in `Unknown` or `Other`, that means there are aliases in the raw data you haven't handled yet. Find them and fix your `CASE` statements.

---

## Where to look
- [CASE WHEN in Snowflake](https://docs.snowflake.com/en/sql-reference/functions/case)
- [COALESCE](https://docs.snowflake.com/en/sql-reference/functions/coalesce)
- [NULLIF](https://docs.snowflake.com/en/sql-reference/functions/nullif)
- [dbt docs generate](https://docs.getdbt.com/reference/commands/cmd-docs)
