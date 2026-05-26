# Session 01 — Environment Setup & Your First Model

## What we'll cover
- Setting up Snowflake (warehouse, database, schema, roles)
- Loading the raw CSV files into Snowflake
- Installing dbt Core and connecting it to Snowflake
- Understanding what a dbt project looks like
- Creating and running your first dbt model

---

## Part 1 — Snowflake setup

### 1.1 Create a free Snowflake trial
Sign up at [https://signup.snowflake.com](https://signup.snowflake.com).
Choose **AWS** as your cloud provider and the region closest to you.

### 1.2 Create your database objects
Run the following SQL in a Snowflake worksheet.
You can also do this through the UI — screenshots will be provided in class.

```sql
-- Create a dedicated database
CREATE DATABASE RAW_TO_READY;

-- Create schemas
CREATE SCHEMA RAW_TO_READY.RAW;        -- raw source data lands here
CREATE SCHEMA RAW_TO_READY.DEV;        -- your personal dev workspace

-- Create a virtual warehouse (compute)
CREATE WAREHOUSE COMPUTE_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

-- Create a role for transformations (optional but good practice)
CREATE ROLE TRANSFORMER;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE TRANSFORMER;
GRANT ALL ON DATABASE RAW_TO_READY TO ROLE TRANSFORMER;
GRANT ALL ON ALL SCHEMAS IN DATABASE RAW_TO_READY TO ROLE TRANSFORMER;
GRANT ROLE TRANSFORMER TO USER YOUR_USERNAME;   -- replace with your username
```

### 1.3 Load the CSV files into Snowflake

You have two options:

**Option A — Snowflake UI (recommended for first time)**

1. In Snowflake, go to **Data → Databases → RAW_TO_READY → RAW**
2. Click **Create Table from File** (or use the Load Data wizard)
3. Upload each CSV from `data/raw/` in this repo
4. Repeat for all 7 files
5. *(Screenshots will be added here)*

**Option B — SQL (SnowSQL or worksheet)**

```sql
-- Example for customers — repeat for each table
USE SCHEMA RAW_TO_READY.RAW;

CREATE OR REPLACE TABLE raw_customers (
    customer_id       NUMBER,
    first_name        VARCHAR,
    last_name         VARCHAR,
    full_name         VARCHAR,
    email             VARCHAR,
    phone             VARCHAR,
    date_of_birth     VARCHAR,    -- VARCHAR intentional: 4 date formats
    join_date         VARCHAR,    -- VARCHAR intentional: 4 date formats
    state             VARCHAR,
    country           VARCHAR,
    credit_score      VARCHAR,    -- VARCHAR intentional: contains 'N/A'
    is_active         VARCHAR     -- VARCHAR intentional: mixed boolean formats
);

-- Then use a stage to load from CSV:
-- CREATE STAGE my_stage;
-- PUT file:///path/to/raw_customers.csv @my_stage;
-- COPY INTO raw_customers FROM @my_stage/raw_customers.csv
--     FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

> **Why VARCHAR?** Notice that `date_of_birth`, `credit_score`, and `is_active` are loaded as `VARCHAR` rather than their "natural" types. This is intentional — the data is messy and we'll handle type casting in our dbt models. Loading as VARCHAR prevents errors during ingestion.

### 1.4 Verify your data loaded

```sql
SELECT COUNT(*) FROM RAW_TO_READY.RAW.raw_customers;     -- expect ~215
SELECT COUNT(*) FROM RAW_TO_READY.RAW.raw_transactions;  -- expect 5000
SELECT * FROM RAW_TO_READY.RAW.raw_customers LIMIT 5;
```

---

## Part 2 — dbt setup

### 2.1 Install dbt Core + Snowflake adapter

```bash
pip install dbt-snowflake
dbt --version   # verify installation
```

### 2.2 Set up your connection profile

dbt stores connection credentials in `~/.dbt/profiles.yml` (outside the repo — never commit credentials).

```bash
cp dbt_project/profiles.yml.example ~/.dbt/profiles.yml
```

Open `~/.dbt/profiles.yml` and fill in your Snowflake details.

### 2.3 Test your connection

```bash
cd dbt_project
dbt debug
```

You should see: `All checks passed!`

### 2.4 Install packages

```bash
dbt deps
```

This installs `dbt-utils` as defined in `packages.yml`.

---

## Part 3 — Your first dbt model

### 3.1 Understand the project structure

Open `dbt_project/` in your editor and take a look around:
- `dbt_project.yml` — project configuration
- `models/staging/` — where we'll work today
- `models/staging/_sources.yml` — tells dbt where the raw data lives

### 3.2 Create your first model

Create a new file: `models/staging/stg_transactions_first_look.sql`

```sql
-- Your first dbt model — a simple select to verify the pipeline works
select
    transaction_id,
    account_id,
    amount,
    transaction_date,
    category,
    status
from {{ source('raw_banking', 'raw_transactions') }}
limit 100
```

### 3.3 Run it

```bash
dbt run --select stg_transactions_first_look
```

Check the output in Snowflake:
```sql
SELECT * FROM RAW_TO_READY.DEV.stg_transactions_first_look LIMIT 10;
```

### 3.4 Look at the data

Spend a few minutes exploring. What do you notice about the data?

```sql
-- What does the amount column look like?
SELECT DISTINCT status FROM RAW_TO_READY.DEV.stg_transactions_first_look;

-- How many distinct categories are there?
SELECT category, COUNT(*) as row_count
FROM RAW_TO_READY.DEV.stg_transactions_first_look
GROUP BY 1
ORDER BY 2 DESC;
```

> **Observation:** You should see something odd about the `status` and `category` columns. Make a note of it — we'll fix this in later sessions.

---

## Challenge

**Before next session:**

1. Load all 7 CSV files into Snowflake (if you haven't already)
2. Make sure `dbt debug` passes cleanly
3. Run the `stg_transactions_first_look` model successfully
4. Run this query and note what you find — bring your observations to the next session:

```sql
-- How many unique values does status have?
SELECT DISTINCT status, COUNT(*) as count
FROM RAW_TO_READY.RAW.raw_transactions
GROUP BY 1 ORDER BY 2 DESC;

-- What's the range of amount values? Any surprises?
SELECT
    MIN(amount) as min_amount,
    MAX(amount) as max_amount,
    COUNT(CASE WHEN amount < 0 THEN 1 END) as negative_count
FROM RAW_TO_READY.RAW.raw_transactions;
```

---

## Where to look
- [dbt Core installation](https://docs.getdbt.com/docs/core/installation-overview)
- [Snowflake connection profile](https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup)
- [Your first dbt model](https://docs.getdbt.com/docs/build/sql-models)
- [source() function](https://docs.getdbt.com/reference/dbt-jinja-functions/source)
