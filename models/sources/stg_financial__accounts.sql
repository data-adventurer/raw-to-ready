select 
    account_id
    ,account_status
    ,account_type
    ,balance
    ,branch_id::varchar as branch_id
    ,currency 
    ,customer_id
    ,interest_rate 
    ,open_date as account_open_date
from dbt.dengoh.raw_accounts