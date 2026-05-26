-- models/staging/stg_exchange_rates.sql
--
-- STAGING MODEL: exchange_rates
-- Source: {{ source('raw_banking', 'raw_exchange_rates') }}
--
-- NOTE: This table is in WIDE format — 8 currency columns
-- (EUR, GBP, JPY, CAD, MXN, AUD, BRL, CHF) with one row per date.
-- At this layer, just pass through. The UNPIVOT into a proper
-- lookup table (one row per date+currency) happens in an intermediate model.
--
-- ─────────────────────────────────────────────────────────────
-- SESSION 3 CHALLENGE: Build this staging model (pass-through only).
-- ─────────────────────────────────────────────────────────────

with source as (

    select * from {{ source('raw_banking', 'raw_exchange_rates') }}

)

-- TODO: select and lightly cast/rename — no UNPIVOT yet

select * from source
