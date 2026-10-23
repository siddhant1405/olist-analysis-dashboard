with orders as (
    select
        order_id,
        customer_unique_id,
        customer_state,
        order_purchase_at,
        order_purchase_at::date as purchase_date,
        total_payment_value as order_value,
        is_late,
        review_score
    from {{ ref('fact_orders') }}
    where is_delivered
        and total_payment_value is not null
        and total_payment_value >= 0
),

reference as (
    select max(purchase_date) + 1 as reference_date
    from orders
),

-- Orders placed on the same day are one shopping session (often split by seller), not a return visit.
purchase_days as (
    select
        customer_unique_id,
        purchase_date,
        dense_rank() over (partition by customer_unique_id order by purchase_date) as purchase_day_number
    from orders
),

second_purchase as (
    select
        customer_unique_id,
        min(purchase_date) as second_purchase_date
    from purchase_days
    where purchase_day_number = 2
    group by customer_unique_id
),

first_order as (
    select distinct on (customer_unique_id)
        customer_unique_id,
        purchase_date as first_purchase_date,
        customer_state as first_order_state,
        is_late as first_order_is_late,
        review_score as first_order_review_score
    from orders
    order by customer_unique_id, order_purchase_at, order_id
),

aggregated as (
    select
        customer_unique_id,
        count(distinct order_id)::integer as order_count,
        count(distinct purchase_date)::integer as purchase_day_count,
        sum(order_value)::numeric as monetary,
        max(purchase_date) as last_purchase_date
    from orders
    group by customer_unique_id
)

select
    aggregated.customer_unique_id,
    reference.reference_date,
    first_order.first_purchase_date,
    date_trunc('month', first_order.first_purchase_date)::date as cohort_month,
    second_purchase.second_purchase_date,
    aggregated.last_purchase_date,
    aggregated.order_count,
    aggregated.purchase_day_count,
    aggregated.monetary,
    reference.reference_date - aggregated.last_purchase_date as recency_days,
    reference.reference_date - first_order.first_purchase_date as observed_days,
    second_purchase.second_purchase_date - first_order.first_purchase_date as days_to_second_purchase,
    aggregated.purchase_day_count > 1 as is_repeat_customer,
    coalesce(second_purchase.second_purchase_date - first_order.first_purchase_date <= 90, false) as returned_within_90d,
    coalesce(second_purchase.second_purchase_date - first_order.first_purchase_date <= 180, false) as returned_within_180d,
    -- A customer can only be counted in a 90/180-day repeat rate once that window has fully elapsed.
    reference.reference_date - first_order.first_purchase_date > 90 as is_observed_90d,
    reference.reference_date - first_order.first_purchase_date > 180 as is_observed_180d,
    first_order.first_order_state,
    first_order.first_order_is_late,
    case
        when first_order.first_order_is_late then 'Late'
        when not first_order.first_order_is_late then 'On time'
    end as first_order_delivery,
    first_order.first_order_review_score
from aggregated
inner join first_order
    on aggregated.customer_unique_id = first_order.customer_unique_id
left join second_purchase
    on aggregated.customer_unique_id = second_purchase.customer_unique_id
cross join reference
