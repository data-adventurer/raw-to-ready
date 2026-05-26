-- models/staging/stg_branches.sql
--
-- STAGING MODEL: branches
-- Source: {{ source('raw_banking', 'raw_branches') }}
--
-- NOTE: This table is in WIDE format — quarterly metrics are stored
-- as separate columns (Q1_2023_txn_count, Q2_2023_txn_count, etc.)
-- rather than rows. At this layer, just select and rename columns.
-- The UNPIVOT transformation will happen in a later intermediate model.
--
-- ─────────────────────────────────────────────────────────────
-- SESSION 3 CHALLENGE: Build this staging model (pass-through only).
-- ─────────────────────────────────────────────────────────────

with source as (

    select * from {{ source('raw_banking', 'raw_branches') }}

)

-- TODO: select and lightly rename columns — no UNPIVOT yet

select * from source
