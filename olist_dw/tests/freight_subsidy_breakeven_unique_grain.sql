select customer_region, order_value_band
from {{ ref('freight_subsidy_breakeven') }}
group by customer_region, order_value_band
having count(*) > 1
