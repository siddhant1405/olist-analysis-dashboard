-- Every customer is active in their own cohort month, so month 0 retention is exactly 100%.
select *
from {{ ref('customer_cohort_retention') }}
where (month_number = 0 and active_customers <> cohort_size)
    or month_number < 0
    or retention_rate > 1
