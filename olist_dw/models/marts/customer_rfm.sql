-- 97% of Olist customers buy once, so a 1-5 frequency score carries almost no information.
-- Segments use repeat status (distinct purchase days), recency and value instead.
with customers as (
    select * from {{ ref('customer_summary') }}
),

ranked as (
    select
        customers.*,
        percent_rank() over (order by monetary asc) as monetary_percent_rank
    from customers
),

banded as (
    select
        customer_unique_id,
        reference_date,
        recency_days,
        order_count as frequency,
        purchase_day_count,
        monetary,
        is_repeat_customer,
        case
            when recency_days <= 90 then '0-90 days'
            when recency_days <= 180 then '91-180 days'
            when recency_days <= 365 then '181-365 days'
            else '365+ days'
        end as recency_band,
        case
            when recency_days <= 90 then 1
            when recency_days <= 180 then 2
            when recency_days <= 365 then 3
            else 4
        end as recency_band_sort,
        case
            when monetary_percent_rank >= 2.0 / 3 then 'High'
            when monetary_percent_rank >= 1.0 / 3 then 'Mid'
            else 'Low'
        end as value_band,
        case
            when monetary_percent_rank >= 2.0 / 3 then 1
            when monetary_percent_rank >= 1.0 / 3 then 2
            else 3
        end as value_band_sort
    from ranked
),

segmented as (
    select
        banded.*,
        case
            when is_repeat_customer and recency_days <= 180 then 'Active Repeat'
            when is_repeat_customer then 'Lapsed Repeat'
            when recency_days <= 180 and value_band = 'High' then 'New High-Value'
            when recency_days <= 180 then 'New Standard'
            when value_band = 'High' then 'Lapsed High-Value'
            else 'Lapsed Standard'
        end as rfm_segment
    from banded
)

select
    segmented.*,
    case rfm_segment
        when 'Active Repeat' then 1
        when 'Lapsed Repeat' then 2
        when 'New High-Value' then 3
        when 'New Standard' then 4
        when 'Lapsed High-Value' then 5
        else 6
    end as rfm_segment_sort,
    case rfm_segment
        when 'Active Repeat' then 'Protect: loyalty perks and priority service'
        when 'Lapsed Repeat' then 'Win back with offers based on past categories'
        when 'New High-Value' then 'Drive a second purchase within 90 days with cross-sell'
        when 'New Standard' then 'Low-cost automated nudge toward a second purchase'
        when 'Lapsed High-Value' then 'Selective win-back; A/B test whether it pays back'
        else 'Exclude from paid campaigns'
    end as recommended_action
from segmented
