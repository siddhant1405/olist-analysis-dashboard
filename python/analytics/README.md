# Customer RFM analysis

The `customer_rfm` mart produces one row per underlying customer. It uses
`customer_unique_id` to combine repeat purchases across order-level customer
IDs, falling back to `customer_id` only if the unique key is blank. RFM is
calculated from delivered orders in `fact_orders`; it does not join item rows
or payment rows into the customer aggregation. Monetary value is the existing
per-order `total_payment_value`, counted once per order.

The reproducible reference date is the maximum qualifying purchase date plus
one day. Cancelled and other non-delivered orders, missing purchase dates,
missing payment totals, and negative order totals are excluded. The source has
no explicit refund indicator, so negative values are excluded rather than
assumed to be refunds. In the inspected CSV snapshot, the reference date was
2018-08-30; one delivered order with no payment summary was excluded.

Recency and monetary scores use `PERCENT_RANK`, preserving ties, with values
clamped to 1-5. Frequency tiers are explicit because 90,556 of 93,357 eligible
customers had one qualifying order: 1 order maps to 1, 2 to 2, 3 to 3, 4 to 4,
and 5 or more to 5.

The mutually exclusive segment rules are applied in this order:

1. Champions: R >= 4, F >= 4, M >= 4.
2. Loyal Customers: R >= 3, F >= 3, M >= 3, excluding Champions.
3. Potential Loyalists: R >= 4, excluding earlier segments.
4. At Risk: R <= 2 and (F >= 2 or M >= 4), excluding earlier segments.
5. Hibernating: all remaining eligible customers.

The inspected raw-CSV snapshot contains 93,357 eligible customers: Champions
32, Loyal Customers 125, Potential Loyalists 37,198, At Risk 14,799, and
Hibernating 41,203. These counts should be regenerated against the active
database before use in customer campaigns.
