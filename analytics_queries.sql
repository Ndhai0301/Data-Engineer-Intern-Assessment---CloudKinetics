-- Data model (star schema, from Question 2 — PostgreSQL syntax):
--   dim_customer(customer_key, customer_id, name, email, city, signup_date)
--   dim_product(product_key, product_id, product_name, category, brand)
--   dim_date(date_key, date, day_of_week, week, month, quarter, year)
--   fact_order_items(order_id, product_key, customer_key, order_date_key,
--                     quantity, unit_price, discount_amount, line_revenue)   -- grain: one row per product line in an order (main fact)
--   fact_orders(order_id, customer_key, order_date_key, order_status,
--               total_amount, item_count)                                   -- grain: one row per order
--   fact_payments(payment_id, order_id, customer_key, payment_date_key,
--                 payment_method, amount, payment_status)                   -- grain: one row per payment ATTEMPT,
--                                                                            -- payment_status IN ('paid','failed','pending','refunded')

-- ============================================================
-- 1. Total revenue by day
-- ============================================================
-- Logic: sum line_revenue from fact_order_items grouped by the order's date
-- (via dim_date), keeping only orders that have at least one 'paid' payment attempt.
SELECT
    d.date                    AS day,
    SUM(foi.line_revenue)     AS total_revenue
FROM fact_order_items foi
JOIN dim_date d ON d.date_key = foi.order_date_key
WHERE EXISTS (
    SELECT 1 FROM fact_payments fp
    WHERE fp.order_id = foi.order_id AND fp.payment_status = 'paid'
)
GROUP BY d.date
ORDER BY day;


-- ============================================================
-- 2. Top 3 best-selling products each week (by quantity sold)
-- ============================================================
-- Logic: aggregate quantity sold per product per ISO week from fact_order_items,
-- then use RANK() to number products within each week by quantity descending, keeping rank <= 3.
WITH weekly_sales AS (
    SELECT
        date_trunc('week', d.date)::date AS week_start,
        foi.product_key,
        SUM(foi.quantity) AS total_qty
    FROM fact_order_items foi
    JOIN dim_date d ON d.date_key = foi.order_date_key
    GROUP BY 1, foi.product_key
),
ranked AS (
    SELECT
        week_start,
        product_key,
        total_qty,
        RANK() OVER (PARTITION BY week_start ORDER BY total_qty DESC) AS rnk
    FROM weekly_sales
)
SELECT
    r.week_start,
    p.product_id,
    p.product_name,
    r.total_qty,
    r.rnk
FROM ranked r
JOIN dim_product p ON p.product_key = r.product_key
WHERE r.rnk <= 3
ORDER BY r.week_start, r.rnk;


-- ============================================================
-- 3. Payment success rate (paid orders / total orders)
-- ============================================================
-- Logic: fact_payments is attempt-level, so collapse to one row per order that
-- indicates whether it was EVER paid, then divide paid orders by all orders in fact_orders.
WITH order_payment_status AS (
    SELECT
        fo.order_id,
        BOOL_OR(fp.payment_status = 'paid') AS was_paid
    FROM fact_orders fo
    LEFT JOIN fact_payments fp ON fp.order_id = fo.order_id
    GROUP BY fo.order_id
)
SELECT
    COUNT(*) FILTER (WHERE was_paid)::numeric / COUNT(*) AS payment_success_rate
FROM order_payment_status;
