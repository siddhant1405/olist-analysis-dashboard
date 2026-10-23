with order_items as (
    select * from {{ ref('stg_order_items') }}
),

sellers as (
    select * from {{ ref('stg_seller') }}
),

aggregated as (
    select
        order_items.order_id,
        count(*)::integer as item_count,
        count(distinct order_items.seller_id)::integer as seller_count,
        count(distinct sellers.state)::integer as seller_state_count,
        -- Only meaningful when every seller on the order is in the same state.
        max(sellers.state) as seller_state,
        sum(order_items.price) as items_value,
        sum(order_items.freight_value) as freight_value,
        max(order_items.shipping_limit_at) as shipping_limit_at
    from order_items
    left join sellers
        on order_items.seller_id = sellers.seller_id
    group by order_items.order_id
)

select * from aggregated
