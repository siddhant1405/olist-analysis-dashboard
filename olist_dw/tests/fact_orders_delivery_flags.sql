-- Delivery flags must agree with each other and be null for undelivered orders.
select *
from {{ ref('fact_orders') }}
where (not is_delivered and (is_late is not null or delivery_timing_bucket is not null))
    or (is_delivered and is_late is null)
    or (is_late and delivery_status <> 'Late')
    or (delivery_status = 'Late' and days_late <= 0)
