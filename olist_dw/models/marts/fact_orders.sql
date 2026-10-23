with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customer') }}
),

payment as (
    select * from {{ ref('int_order_payments_summary') }}
),

review as (
    select * from {{ ref('int_order_reviews') }}
),

items as (
    select * from {{ ref('int_order_items_summary') }}
),

states as (
    select * from {{ ref('brazil_states') }}
),

joined as (
    select
        orders.order_id,
        orders.customer_id,
        customers.customer_unique_id,
        customers.state as customer_state,
        states.region as customer_region,
        states.region_sort as customer_region_sort,
        orders.order_status,
        orders.order_purchase_at,
        date_trunc('month', orders.order_purchase_at)::date as purchase_month,
        orders.order_approved_at,
        orders.order_delivered_carrier_at,
        orders.order_delivered_customer_at,
        orders.order_estimated_delivery_at,
        payment.total_payment_value,
        payment.payment_count,
        payment.primary_payment_type,
        items.item_count,
        items.seller_count,
        items.items_value,
        items.freight_value,
        review.review_score,
        date_part('day', orders.order_delivered_customer_at - orders.order_purchase_at) as delivery_days,
        -- Kept for backwards compatibility: positive means delivered BEFORE the estimate. Prefer days_late.
        date_part('day', orders.order_estimated_delivery_at - orders.order_delivered_customer_at) as delivery_days_vs_estimated,
        orders.order_estimated_delivery_at::date - orders.order_purchase_at::date as promised_days,
        orders.order_status = 'delivered'
            and orders.order_delivered_customer_at is not null as is_delivered,
        -- Calendar days after the estimated date; negative means early. Date-level, so same-day delivery is on time.
        orders.order_delivered_customer_at::date - orders.order_estimated_delivery_at::date as days_late,
        orders.order_delivered_carrier_at > items.shipping_limit_at as is_seller_handoff_late,
        not (items.seller_state_count = 1 and items.seller_state = customers.state) as is_cross_state,
        case
            when items.seller_state_count > 1 then 'Multiple states'
            when items.seller_state = customers.state then 'Same state'
            when items.seller_state = 'SP' then 'From Sao Paulo'
            else 'Other state'
        end as seller_origin,
        orders.order_purchase_at >= '{{ var("analysis_start_date") }}'
            and orders.order_purchase_at < '{{ var("analysis_end_date") }}' as is_in_analysis_window
    from orders
    left join customers on orders.customer_id = customers.customer_id
    left join payment on orders.order_id = payment.order_id
    left join review on orders.order_id = review.order_id
    left join items on orders.order_id = items.order_id
    left join states on customers.state = states.state
),

final as (
    select
        joined.*,
        case when is_delivered then days_late > 0 end as is_late,
        case
            when is_cross_state then 'Cross-state'
            when not is_cross_state then 'Same state'
        end as shipping_route,
        case
            when not is_delivered then 'Not delivered'
            when days_late > 0 then 'Late'
            else 'On time'
        end as delivery_status,
        case
            when not is_delivered then null
            when days_late <= -10 then '10+ days early'
            when days_late < 0 then '1-9 days early'
            when days_late = 0 then 'On estimated day'
            when days_late <= 3 then '1-3 days late'
            when days_late <= 7 then '4-7 days late'
            when days_late <= 14 then '8-14 days late'
            else '15+ days late'
        end as delivery_timing_bucket,
        case
            when not is_delivered then null
            when days_late <= -10 then 1
            when days_late < 0 then 2
            when days_late = 0 then 3
            when days_late <= 3 then 4
            when days_late <= 7 then 5
            when days_late <= 14 then 6
            else 7
        end as delivery_timing_sort,
        -- Grouped from most to least damaging for reviews; sort with experience_group_sort.
        case
            when not is_delivered then 'Not delivered'
            when days_late > 0 then 'Late'
            when seller_count > 1 then 'On time, multiple sellers'
            when item_count > 1 then 'On time, multiple items'
            else 'On time, single item'
        end as experience_group,
        case
            when not is_delivered then 1
            when days_late > 0 then 2
            when seller_count > 1 then 3
            when item_count > 1 then 4
            else 5
        end as experience_group_sort,
        case
            when items_value < 50 then 'Under R$50'
            when items_value < 100 then 'R$50-99'
            when items_value < 150 then 'R$100-149'
            when items_value < 200 then 'R$150-199'
            when items_value < 300 then 'R$200-299'
            when items_value < 500 then 'R$300-499'
            else 'R$500+'
        end as order_value_band,
        case
            when items_value < 50 then 1
            when items_value < 100 then 2
            when items_value < 150 then 3
            when items_value < 200 then 4
            when items_value < 300 then 5
            when items_value < 500 then 6
            else 7
        end as order_value_band_sort,
        -- New = an order on or before the customer's first delivered purchase day; later orders are Returning.
        case
            when order_purchase_at::date > min(case when is_delivered then order_purchase_at::date end)
                over (partition by customer_unique_id)
                then 'Returning'
            else 'New'
        end as customer_type,
        row_number() over (
            partition by customer_unique_id
            order by order_purchase_at, order_id
        )::integer as customer_order_number
    from joined
)

select * from final
