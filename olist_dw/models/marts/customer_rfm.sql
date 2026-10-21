{{ config(materialized='table') }}

with qualifying_orders as (
    select
        orders.order_id,
        coalesce(
            nullif(trim(customers.customer_unique_id), ''),
            nullif(trim(orders.customer_id), '')
        ) as customer_unique_id,
        orders.order_purchase_at::date as purchase_date,
        orders.total_payment_value::numeric as order_value
    from {{ ref('fact_orders') }} as orders
    inner join {{ ref('dim_customers') }} as customers
        on orders.customer_id = customers.customer_id
    where orders.order_status = 'delivered'
        and orders.order_purchase_at is not null
        and orders.total_payment_value is not null
        and orders.total_payment_value >= 0
        and coalesce(
            nullif(trim(customers.customer_unique_id), ''),
            nullif(trim(orders.customer_id), '')
        ) is not null
),

reference as (
    select max(purchase_date) + 1 as reference_date
    from qualifying_orders
),

customer_metrics as (
    select
        orders.customer_unique_id,
        reference.reference_date,
        reference.reference_date - max(orders.purchase_date) as recency_days,
        count(distinct orders.order_id)::integer as frequency,
        sum(orders.order_value)::numeric as monetary
    from qualifying_orders as orders
    cross join reference
    group by orders.customer_unique_id, reference.reference_date
),

ranked as (
    select
        customer_metrics.*,
        percent_rank() over (order by recency_days asc) as recency_percent_rank,
        percent_rank() over (order by monetary asc) as monetary_percent_rank
    from customer_metrics
),

scored as (
    select
        customer_unique_id,
        reference_date,
        recency_days,
        frequency,
        monetary,
        greatest(1, least(5, 5 - floor(recency_percent_rank * 5)::integer)) as recency_score,
        case
            when frequency >= 5 then 5
            when frequency = 4 then 4
            when frequency = 3 then 3
            when frequency = 2 then 2
            else 1
        end as frequency_score,
        greatest(1, least(5, floor(monetary_percent_rank * 5)::integer + 1)) as monetary_score
    from ranked
),

segmented as (
    select
        scored.*,
        concat(recency_score, frequency_score, monetary_score) as rfm_score,
        case
            when recency_score >= 4 and frequency_score >= 4 and monetary_score >= 4
                then 'Champions'
            when recency_score >= 3 and frequency_score >= 3 and monetary_score >= 3
                then 'Loyal Customers'
            when recency_score >= 4 and frequency_score >= 1
                then 'Potential Loyalists'
            when recency_score <= 2 and (frequency_score >= 2 or monetary_score >= 4)
                then 'At Risk'
            else 'Hibernating'
        end as rfm_segment
    from scored
)

select
    customer_unique_id,
    reference_date,
    recency_days,
    frequency,
    monetary,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_score,
    rfm_segment
from segmented
