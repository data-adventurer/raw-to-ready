-- models/staging/stg_accounts.sql
--
-- STAGING MODEL: accounts
-- Source: {{ source('raw_banking', 'raw_accounts') }}
--
-- KNOWN DATA ISSUES
--   • account_type: 8+ aliases (CHK, Checking, checking account, ...)
--   • account_status: 6+ aliases (Active, ACTIVE, A, 1, Open, ...)
--   • balance: stored as string with $ and commas e.g. '$12,345.67'
--   • interest_rate: stored as decimal (0.055), percentage string ('5.5%'),
--     or plain number ('5.5') — all meaning the same rate
--   • open_date: same 4-format date issue as customers
--   • currency: multiple representations of USD
--
-- ─────────────────────────────────────────────────────────────
-- SESSION 3 CHALLENGE: Build this staging model.
-- See stg_customers.sql as a reference for structure and approach.
-- ─────────────────────────────────────────────────────────────

with source as (

    select * from {{ source('raw_banking', 'raw_accounts') }}

)

-- TODO: add your cleaning logic here

select * from source
