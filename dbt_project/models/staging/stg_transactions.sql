-- models/staging/stg_transactions.sql
--
-- STAGING MODEL: transactions
-- Source: {{ source('raw_banking', 'raw_transactions') }}
--
-- KNOWN DATA ISSUES
--   • category: each category has 5–8 aliases
--     e.g. 'Food & Dining', 'food', 'DINING', 'restaurants', 'F&D'
--   • transaction_type: 'debit'/'credit'/'DEBIT'/'CREDIT'/'DR'/'CR'
--   • amount: sign is inconsistent — debits are sometimes positive, sometimes negative
--   • status: 'Completed'/'COMPLETED'/'Complete'/'C' + similar for Pending/Failed
--   • merchant: ~7% are null disguises ('N/A', 'null', '')
--   • currency: mostly USD but ~15% are EUR/GBP/MXN/CAD
--   • transaction_date: same 4-format date issue as other tables
--
-- ─────────────────────────────────────────────────────────────
-- SESSION 3 CHALLENGE: Build this staging model.
-- ─────────────────────────────────────────────────────────────

with source as (

    select * from {{ source('raw_banking', 'raw_transactions') }}

)

-- TODO: add your cleaning logic here

select * from source
