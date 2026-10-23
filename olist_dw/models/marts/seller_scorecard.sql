with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('fact_orders') }}
    where is_delivered
        and is_in_analysis_window
),

sellers as (
    select * from {{ ref('stg_seller') }}
),

-- One row per seller per order: a multi-seller order counts once for each seller on it.
seller_orders as (
    select
        seller_id,
        order_id,
        sum(price) as revenue,
        max(shipping_limit_at) as shipping_limit_at
    from order_items
    group by seller_id, order_id
),

joined as (
    select
        seller_orders.seller_id,
        seller_orders.order_id,
        seller_orders.revenue,
        orders.is_late,
        orders.review_score,
        orders.delivery_days,
        orders.order_delivered_carrier_at > seller_orders.shipping_limit_at as is_handoff_late
    from seller_orders
    inner join orders
        on seller_orders.order_id = orders.order_id
),

platform as (
    select avg(is_late::integer) as platform_late_rate
    from joined
),

aggregated as (
    select
        seller_id,
        count(*)::integer as delivered_orders,
        sum(revenue)::numeric as revenue,
        sum(is_late::integer)::integer as late_orders,
        avg(is_late::integer)::numeric as late_rate,
        avg(is_handoff_late::integer)::numeric as handoff_late_rate,
        avg(review_score)::numeric as avg_review_score,
        avg(delivery_days)::numeric as avg_delivery_days
    from joined
    group by seller_id
)

select
    aggregated.seller_id,
    sellers.state as seller_state,
    sellers.city as seller_city,
    aggregated.delivered_orders,
    aggregated.revenue,
    aggregated.late_orders,
    aggregated.late_rate,
    aggregated.handoff_late_rate,
    aggregated.avg_review_score,
    aggregated.avg_delivery_days,
    platform.platform_late_rate,
    case
        when aggregated.delivered_orders < 30 then 'Low volume'
        when aggregated.late_rate >= 2 * platform.platform_late_rate then 'High risk'
        when aggregated.late_rate > platform.platform_late_rate then 'Watch'
        else 'Healthy'
    end as performance_tier,
    case
        when aggregated.delivered_orders < 30 then 4
        when aggregated.late_rate >= 2 * platform.platform_late_rate then 1
        when aggregated.late_rate > platform.platform_late_rate then 2
        else 3
    end as performance_tier_sort
from aggregated
left join sellers
    on aggregated.seller_id = sellers.seller_id
cross join platform
