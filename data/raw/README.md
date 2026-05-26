# Raw Data

These 7 CSV files are the source data for the training program.
Load all of them into Snowflake under `RAW_TO_READY.RAW` before starting Session 1.

| File | Rows | Notes |
|---|---|---|
| raw_customers.csv | ~215 | Includes ~15 intentional duplicate rows |
| raw_accounts.csv | 400 | |
| raw_transactions.csv | 5,000 | |
| raw_branches.csv | 20 | Wide format — quarterly metrics as columns |
| raw_loans.csv | 300 | |
| raw_exchange_rates.csv | ~390 | Wide format — currencies as columns, weekdays only |
| raw_account_snapshots.csv | 1,440 | Long format — one row per account per month |

See `sessions/session-01/README.md` for loading instructions.
