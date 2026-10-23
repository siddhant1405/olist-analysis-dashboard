-- Estimates how route order volume responds to freight, from month-to-month freight changes on the same route.
-- Route = seller state -> customer state. Freight is weight-adjusted so heavier product mixes don't look like price rises.
-- Two-way fixed effects (route and month), estimated by double-demeaning; one row with the slope.

with items as (
    select
        order_items.order_id,
        sellers.state || '>' || orders.customer_state as route,
        orders.purchase_month,
        ln(greatest(order_items.freight_value, 0.5)) as log_freight,
        ln(products.product_weight_g) as log_weight
    from {{ ref('stg_order_items') }} as order_items
    inner join {{ ref('fact_orders') }} as orders
        on order_items.order_id = orders.order_id
    inner join {{ ref('stg_seller') }} as sellers
        on order_items.seller_id = sellers.seller_id
    inner join {{ ref('stg_products') }} as products
        on order_items.product_id = products.product_id
    where orders.is_delivered
        and orders.is_in_analysis_window
        and products.product_weight_g > 0
),

weight_fit as (
    select
        regr_slope(log_freight, log_weight) as slope,
        regr_intercept(log_freight, log_weight) as intercept
    from items
),

route_months as (
    select
        items.route,
        items.purchase_month,
        count(distinct items.order_id) as orders,
        -- Average freight relative to what an item of that weight usually costs to ship.
        avg(items.log_freight - (weight_fit.intercept + weight_fit.slope * items.log_weight)) as freight_rate
    from items
    cross join weight_fit
    group by items.route, items.purchase_month
),

panel as (
    select
        route,
        purchase_month,
        ln(orders) as log_orders,
        freight_rate
    from route_months
    where orders >= 10
        and route in (
            select route from route_months group by route having sum(orders) >= 500
        )
),

demeaned as (
    select
        route,
        log_orders
            - avg(log_orders) over (partition by route)
            - avg(log_orders) over (partition by purchase_month)
            + avg(log_orders) over () as log_orders_d,
        freight_rate
            - avg(freight_rate) over (partition by route)
            - avg(freight_rate) over (partition by purchase_month)
            + avg(freight_rate) over () as freight_rate_d
    from panel
)

select
    regr_slope(log_orders_d, freight_rate_d)::numeric as freight_elasticity,
    corr(log_orders_d, freight_rate_d)::numeric as correlation,
    count(distinct route)::integer as routes,
    count(*)::integer as route_months,
    stddev(freight_rate_d)::numeric as freight_variation
from demeaned
