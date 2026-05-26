-- models/staging/stg_customers.sql
--
-- STAGING MODEL: customers
-- Source: {{ source('raw_banking', 'raw_customers') }}
--
-- PURPOSE
-- 1:1 with the source table — one row per customer_id (after deduplication).
-- Light cleaning only: rename columns, cast types, normalise formats.
-- No joins, no business logic, no aggregations at this layer.
--
-- KNOWN DATA ISSUES (to fix in this model)
--   • ~15 duplicate customer_id rows — keep most recent join_date
--   • first_name / last_name: mixed case (JOHN, john, John)
--   • email: null disguised as 'N/A', 'null', 'unknown', ''
--   • phone: 5 different formats — strip to 10 digits
--   • date_of_birth / join_date: 4 date formats mixed
--   • country: 5 representations of USA
--   • is_active: boolean stored as '1'/'0'/'Yes'/'No'/'True'/'False' etc.
--   • credit_score: sometimes stored as 'N/A' or 'null'
--
-- ─────────────────────────────────────────────────────────────
-- SESSION 3 CHALLENGE: Complete the TODOs below.
-- ─────────────────────────────────────────────────────────────

with source as (

    select * from {{ source('raw_banking', 'raw_customers') }}

),

cleaned as (

    select

        -- Primary key
        customer_id,

        -- Name normalisation
        -- TODO: apply INITCAP and TRIM to first_name and last_name
        first_name,
        last_name,

        -- TODO: derive a clean full_name from first_name + last_name
        -- (don't trust the full_name column in the source — it's inconsistent)
        null as full_name,

        -- Contact details
        -- TODO: normalise email — convert null disguises to actual NULL
        email,

        -- TODO: strip phone to 10 digits using REGEXP_REPLACE
        phone as phone_digits,

        -- Dates
        -- TODO: parse date_of_birth — it arrives in 4 different formats
        -- Hint: TRY_TO_DATE with multiple format strings and COALESCE
        date_of_birth,
        join_date,

        -- Geography
        -- TODO: normalise country to 'USA'
        -- (source has: 'US', 'USA', 'United States', 'U.S.', 'us')
        country,

        state,

        -- Metrics
        -- TODO: safely cast credit_score to INTEGER
        -- (some rows have 'N/A' or 'null' — use TRY_CAST)
        credit_score,

        -- TODO: normalise is_active to a boolean
        -- (source has: '1','0','True','False','Yes','No','Y','N','TRUE','FALSE')
        is_active

    from source

),

deduplicated as (

    -- TODO: remove duplicate customer_id rows.
    -- Keep the record with the most recent join_date.
    -- Hint: ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY join_date DESC)
    select *
    from cleaned

)

select * from deduplicated

-- ─────────────────────────────────────────────────────────────
-- WHERE TO LOOK
--   Snowflake string functions:  https://docs.snowflake.com/en/sql-reference/functions-string
--   TRY_TO_DATE:                 https://docs.snowflake.com/en/sql-reference/functions/try_to_date
--   TRY_CAST:                    https://docs.snowflake.com/en/sql-reference/functions/try_cast
--   Window functions:            https://docs.snowflake.com/en/sql-reference/functions-analytic
-- ─────────────────────────────────────────────────────────────
