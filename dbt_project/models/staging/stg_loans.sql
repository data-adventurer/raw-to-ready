-- models/staging/stg_loans.sql
--
-- STAGING MODEL: loans
-- Source: {{ source('raw_banking', 'raw_loans') }}
--
-- KNOWN DATA ISSUES
--   • loan_type: multiple aliases (Personal, personal, PERSONAL, ...)
--   • loan_status: multiple aliases (Current, current, CURRENT, ...)
--   • principal_amount: stored as string with $ signs and commas
--   • interest_rate: same 3-way ambiguity as accounts
--     (0.055 vs '5.50%' vs '5.5' — all mean 5.5%)
--   • monthly_payment: missing for ~15% of rows — can be derived from
--     principal, rate, and term using the standard amortisation formula
--   • start_date: same 4-format date issue as other tables
--
-- ─────────────────────────────────────────────────────────────
-- SESSION 3 CHALLENGE: Build this staging model.
-- ─────────────────────────────────────────────────────────────

with source as (

    select * from {{ source('raw_banking', 'raw_loans') }}

)

-- TODO: add your cleaning logic here

select * from source
