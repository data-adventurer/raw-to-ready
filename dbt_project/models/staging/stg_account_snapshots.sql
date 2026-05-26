-- models/staging/stg_account_snapshots.sql
--
-- STAGING MODEL: account_snapshots
-- Source: {{ source('raw_banking', 'raw_account_snapshots') }}
--
-- This table is already in a clean LONG format — one row per account per month.
-- Light renaming and type casting only at this layer.
--
-- ─────────────────────────────────────────────────────────────
-- SESSION 3 CHALLENGE: Build this staging model (mostly pass-through).
-- ─────────────────────────────────────────────────────────────

with source as (

    select * from {{ source('raw_banking', 'raw_account_snapshots') }}

)

-- TODO: cast closing_balance to NUMERIC, snapshot_year/month to INTEGER

select * from source
