select *
from {{ ref('customer_rfm') }}
where recency_days < 0
    or frequency < 1
    or monetary < 0
    or rfm_score !~ '^[1-5]{3}$'
