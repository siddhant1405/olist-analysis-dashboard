with customers as (
    select
        customer_unique_id,
        cohort_month
    from {{ ref('customer_summary') }}
    where cohort_month >= '{{ var("analysis_start_date") }}'
        and cohort_month < '{{ var("analysis_end_date") }}'
),

activity as (
    select distinct
        customer_unique_id,
        purchase_month as activity_month
    from {{ ref('fact_orders') }}
    where is_delivered
        and total_payment_value is not null
        and total_payment_value >= 0
        and order_purchase_at < '{{ var("analysis_end_date") }}'
),

cohort_size as (
    select
        cohort_month,
        count(*)::integer as cohort_size
    from customers
    group by cohort_month
),

cohort_activity as (
    select
        customers.cohort_month,
        (
            (extract(year from activity.activity_month) - extract(year from customers.cohort_month)) * 12
            + extract(month from activity.activity_month) - extract(month from customers.cohort_month)
        )::integer as month_number,
        count(distinct customers.customer_unique_id)::integer as active_customers
    from customers
    inner join activity
        on customers.customer_unique_id = activity.customer_unique_id
    group by 1, 2
)

select
    cohort_activity.cohort_month,
    to_char(cohort_activity.cohort_month, 'YYYY-MM') as cohort_label,
    cohort_activity.month_number,
    cohort_activity.active_customers,
    cohort_size.cohort_size,
    cohort_activity.active_customers::numeric / cohort_size.cohort_size as retention_rate
from cohort_activity
inner join cohort_size
    on cohort_activity.cohort_month = cohort_size.cohort_month
