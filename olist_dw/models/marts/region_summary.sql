with states as (
    select * from {{ ref('brazil_states') }}
),

orders as (
    select * from {{ ref('fact_orders') }}
    where is_delivered
        and is_in_analysis_window
),

sellers as (
    select
        state,
        count(*)::integer as seller_count
    from {{ ref('stg_seller') }}
    group by state
),

order_metrics as (
    select
        customer_state as state,
        count(*)::integer as delivered_orders,
        count(distinct customer_unique_id)::integer as customers,
        sum(items_value)::numeric as revenue,
        sum(freight_value)::numeric as freight_value,
        avg(freight_value)::numeric as avg_freight_per_order,
        avg(is_late::integer)::numeric as late_rate,
        avg(delivery_days)::numeric as avg_delivery_days,
        avg(review_score)::numeric as avg_review_score,
        avg((seller_origin = 'Same state')::integer)::numeric as local_seller_order_share
    from orders
    group by customer_state
)

select
    states.state,
    states.state_name,
    states.region,
    states.region_sort,
    states.population_2022,
    coalesce(order_metrics.delivered_orders, 0) as delivered_orders,
    coalesce(order_metrics.customers, 0) as customers,
    coalesce(order_metrics.revenue, 0) as revenue,
    coalesce(order_metrics.freight_value, 0) as freight_value,
    coalesce(sellers.seller_count, 0) as seller_count,
    order_metrics.avg_freight_per_order,
    order_metrics.freight_value / nullif(order_metrics.revenue, 0) as freight_share_of_revenue,
    order_metrics.late_rate,
    order_metrics.avg_delivery_days,
    order_metrics.avg_review_score,
    order_metrics.local_seller_order_share,
    coalesce(order_metrics.customers, 0) * 100000.0 / states.population_2022 as customers_per_100k
from states
left join order_metrics
    on states.state = order_metrics.state
left join sellers
    on states.state = sellers.state
