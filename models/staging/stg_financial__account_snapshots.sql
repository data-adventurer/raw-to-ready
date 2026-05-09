select 
    account_id
    ,closing_balance
    ,fees_charges
    ,month_label
    ,snapshot_id
    ,snapshot_month 
    ,napshot_year
    ,txn_count 
from dbt.dengoh.raw_account_snapshots