select *
from {{ ref('customer_rfm') }}
where recency_days < 0
    or frequency < 1
    or monetary < 0
    or purchase_day_count > frequency
    or (is_repeat_customer and purchase_day_count < 2)
