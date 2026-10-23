-- Where would a freight subsidy pay for itself?
-- With order volume responding to freight at elasticity e, Olist earns commission c on the extra item value.
-- A small subsidy adds profit only when freight / item value < |e| x c. The commission rate is not in the
-- data, so the break-even line is shown for 10%, 15% and 20%.

with orders as (
    select * from {{ ref('fact_orders') }}
    where is_delivered
        and is_in_analysis_window
),

elasticity as (
    select abs(freight_elasticity) as abs_elasticity
    from {{ ref('freight_demand_elasticity') }}
),

bands as (
    select
        customer_region,
        customer_region_sort,
        order_value_band,
        order_value_band_sort,
        count(*)::integer as delivered_orders,
        sum(items_value)::numeric as revenue,
        sum(freight_value)::numeric as freight_value
    from orders
    group by 1, 2, 3, 4
)

select
    bands.customer_region,
    bands.customer_region_sort,
    bands.order_value_band,
    bands.order_value_band_sort,
    bands.delivered_orders,
    bands.revenue,
    bands.freight_value,
    bands.freight_value / nullif(bands.revenue, 0) as freight_share,
    elasticity.abs_elasticity,
    elasticity.abs_elasticity * 0.10 as breakeven_share_at_10pct,
    elasticity.abs_elasticity * 0.15 as breakeven_share_at_15pct,
    elasticity.abs_elasticity * 0.20 as breakeven_share_at_20pct,
    bands.freight_value / nullif(bands.revenue, 0) < elasticity.abs_elasticity * {{ var('commission_rate') }}
        as is_subsidy_profitable
from bands
cross join elasticity
