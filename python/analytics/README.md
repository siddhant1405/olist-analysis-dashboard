# Customer analytics

## Why the segmentation changed

97% of customers place a single delivered order, so a 1-5 frequency score puts
almost everyone in the same bucket and classic RFM segments ("Champions",
"Loyal Customers") describe a few dozen people. The segmentation now treats
frequency as repeat vs one-time and splits customers by recency and value.

## Definitions

All customer models use delivered orders with a non-negative payment total,
keyed on `customer_unique_id` (Olist issues a new `customer_id` for every
order).

- **Repeat purchase**: a second distinct purchase *day*. About 28% of apparent
  repeat customers only placed several orders on one day, usually one checkout
  split across sellers.
- **Repeat rate (180d)**: customers with a second purchase day within 180 days
  of their first, among customers whose first purchase is more than 180 days
  before the reference date. Recent customers have not had time to return, so
  including them understates the rate.
- **Reference date**: last qualifying purchase date plus one day.
- 76% of second purchases happen within 180 days (median 74 days), so 180 days
  separates active from lapsed customers.

## Segments (`customer_rfm`)

Value bands are monetary terciles. Rules apply in order:

| Segment | Rule | Recommended action |
|---|---|---|
| Active Repeat | 2+ purchase days, last purchase within 180 days | Protect: loyalty perks and priority service |
| Lapsed Repeat | 2+ purchase days, last purchase over 180 days ago | Win back with offers based on past categories |
| New High-Value | One purchase day within 180 days, top tercile | Drive a second purchase within 90 days |
| New Standard | One purchase day within 180 days | Low-cost automated nudge |
| Lapsed High-Value | One purchase day over 180 days ago, top tercile | Selective win-back; A/B test the payback |
| Lapsed Standard | Everyone else | Exclude from paid campaigns |

## Related models

- `customer_summary`: one row per customer with lifetime metrics and the
  90/180-day repeat flags.
- `customer_cohort_retention`: share of each first-purchase cohort that buys
  again N months later.
- `seller_scorecard`: per-seller late rate, handoff lateness, reviews and a
  performance tier.
- `region_summary`: one row per state with population, customers per 100k,
  freight share, late rate and local-seller share.
- `freight_demand_elasticity` and `freight_subsidy_breakeven`: freight demand
  sensitivity and where a freight subsidy would pay for itself.
