/* ============================================================================
   OLIST E-COMMERCE ANALYTICS
   04_business_analysis.sql

   Purpose:
   Perform business-oriented analysis on the validated Olist dataset,
   focusing on commercial performance, customers, product categories,
   geography, logistics, and customer satisfaction.

   Business Rules:
   - Completed commercial analyses use orders with status = 'delivered'.
   - Product GMV = SUM(order_items.price), excluding freight.
   - Total Order Value = product value + freight value.
   - Average Order Value (AOV) is calculated at order level.
   - Customer-level analysis uses customer_unique_id.
   - Category translation uses LEFT JOIN to preserve unmapped categories.
   - Products without category are grouped as 'unknown'.
   - On-time delivery compares delivery DATE against estimated delivery DATE.
   - Orders with missing delivery date are excluded only from metrics that
     require delivery timing.
   - Multiple reviews for the same order are aggregated at order level.
   - Review/logistics relationships are interpreted as associations,
     not evidence of causation.
   - The primary monthly trend window is January 2017 through August 2018
     to avoid incomplete or residual periods.

   Dataset:
   Brazilian E-Commerce Public Dataset by Olist

   Database:
   PostgreSQL
============================================================================ */


/* ============================================================================
   1. BUSINESS OVERVIEW
============================================================================ */


/* ----------------------------------------------------------------------------
   1.1 ORDER OVERVIEW
   Objective:
   Understand order volume and status distribution.
---------------------------------------------------------------------------- */

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

/*
Observed result:
- Total orders: 99,441
- Delivered orders: 96,478
- Delivered rate: 97.02%
*/


SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) / COUNT(*),
        2
    ) AS delivered_percentage

FROM orders;


/* ----------------------------------------------------------------------------
   1.2 CUSTOMER OVERVIEW
   Objective:
   Distinguish customer records from unique customers.
---------------------------------------------------------------------------- */

SELECT
    COUNT(*) AS customer_records,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

/*
Observed result:
- Customer records: 99,441
- Unique customers: 96,096
*/


SELECT
    COUNT(DISTINCT c.customer_unique_id) AS delivered_unique_customers
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';

/*
Observed result:
- Unique customers with delivered orders: 93,358
*/


/* ----------------------------------------------------------------------------
   1.3 CUSTOMER PURCHASE FREQUENCY
   Objective:
   Measure customer repeat purchase behavior.
---------------------------------------------------------------------------- */

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS unique_customers,

    COUNT(*) FILTER (
        WHERE delivered_orders = 1
    ) AS one_time_customers,

    COUNT(*) FILTER (
        WHERE delivered_orders > 1
    ) AS repeat_customers,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivered_orders > 1
        ) / COUNT(*),
        2
    ) AS repeat_customer_percentage

FROM customer_orders;

/*
Observed result:
- Unique customers: 93,358
- One-time customers: 90,557
- Repeat customers: 2,801
- Repeat Customer Rate: 3.00%
*/


WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    delivered_orders,
    COUNT(*) AS customers
FROM customer_orders
GROUP BY delivered_orders
ORDER BY delivered_orders;


/* ----------------------------------------------------------------------------
   1.4 SALES VALUE
   Objective:
   Calculate Product GMV, Freight Value, and Total Order Value.
---------------------------------------------------------------------------- */

SELECT
    ROUND(SUM(oi.price), 2) AS product_gmv
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

/*
Observed result:
- Product GMV: R$ 13,221,498.11
*/


SELECT
    ROUND(SUM(oi.freight_value), 2) AS freight_value
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

/*
Observed result:
- Freight Value: R$ 2,198,275.64
*/


SELECT
    ROUND(
        SUM(oi.price + oi.freight_value),
        2
    ) AS total_order_value
FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

/*
Observed result:
- Total Order Value: R$ 15,419,773.75
*/


/* ----------------------------------------------------------------------------
   1.5 AVERAGE ORDER VALUE
   Objective:
   Calculate average order value at order level, avoiding item-level bias.
---------------------------------------------------------------------------- */

WITH order_values AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
)

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(AVG(order_value), 2) AS average_order_value,
    ROUND(MIN(order_value), 2) AS minimum_order_value,
    ROUND(MAX(order_value), 2) AS maximum_order_value
FROM order_values;

/*
Observed result:
- Delivered orders: 96,478
- AOV: R$ 159.83
- Minimum order value: R$ 9.59
- Maximum order value: R$ 13,664.08
*/


WITH order_values AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
)

SELECT
    ROUND(AVG(order_value), 2) AS average_order_value,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY order_value)::NUMERIC,
        2
    ) AS median_order_value,

    ROUND(
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY order_value)::NUMERIC,
        2
    ) AS p90_order_value,

    ROUND(
        PERCENTILE_CONT(0.95)
        WITHIN GROUP (ORDER BY order_value)::NUMERIC,
        2
    ) AS p95_order_value,

    ROUND(
        PERCENTILE_CONT(0.99)
        WITHIN GROUP (ORDER BY order_value)::NUMERIC,
        2
    ) AS p99_order_value

FROM order_values;

/*
Observed result:
- Average: R$ 159.83
- Median: R$ 105.28
- P90: R$ 305.92
- P95: R$ 446.23
- P99: R$ 1,052.39

Interpretation:
The distribution is right-skewed, with higher-value orders increasing the mean.
No outliers were removed without evidence of data inconsistency.
*/


/* ----------------------------------------------------------------------------
   1.6 ITEMS PER ORDER
   Objective:
   Understand typical basket size.
---------------------------------------------------------------------------- */

WITH items_per_order AS (
    SELECT
        oi.order_id,
        COUNT(*) AS total_items
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
)

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(AVG(total_items), 2) AS average_items_per_order,
    MIN(total_items) AS minimum_items,
    MAX(total_items) AS maximum_items
FROM items_per_order;

/*
Observed result:
- Average Items per Order: 1.14
- Minimum: 1
- Maximum: 21
*/


WITH items_per_order AS (
    SELECT
        oi.order_id,
        COUNT(*) AS total_items
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
)

SELECT
    total_items,
    COUNT(*) AS orders,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage

FROM items_per_order
GROUP BY total_items
ORDER BY total_items;

/*
Key insight:
- 90.01% of delivered orders contain exactly one item.
- 97.67% contain no more than two items.
*/


/* ============================================================================
   2. SALES TRENDS
============================================================================ */


/* ----------------------------------------------------------------------------
   2.1 MONTHLY SALES TREND
   Objective:
   Analyze delivered orders and Product GMV over time.
---------------------------------------------------------------------------- */

SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE AS month,

    COUNT(DISTINCT o.order_id) AS delivered_orders,

    ROUND(
        SUM(oi.price),
        2
    ) AS product_gmv

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )

ORDER BY month;


/* ----------------------------------------------------------------------------
   2.2 MONTHLY AOV
   Primary trend window:
   January 2017 through August 2018.
---------------------------------------------------------------------------- */

WITH monthly_orders AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS month,

        o.order_id,

        SUM(
            oi.price + oi.freight_value
        ) AS order_value

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= DATE '2017-01-01'
      AND o.order_purchase_timestamp < DATE '2018-09-01'

    GROUP BY
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        ),
        o.order_id
)

SELECT
    month,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(order_value), 2) AS total_order_value,
    ROUND(AVG(order_value), 2) AS average_order_value

FROM monthly_orders
GROUP BY month
ORDER BY month;


/* ----------------------------------------------------------------------------
   2.3 MONTH-OVER-MONTH GROWTH
---------------------------------------------------------------------------- */

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS month,

        COUNT(DISTINCT o.order_id) AS delivered_orders,

        SUM(
            oi.price + oi.freight_value
        ) AS total_order_value

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= DATE '2017-01-01'
      AND o.order_purchase_timestamp < DATE '2018-09-01'

    GROUP BY
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )
)

SELECT
    month,
    delivered_orders,
    ROUND(total_order_value, 2) AS total_order_value,

    ROUND(
        100.0 * (
            delivered_orders
            - LAG(delivered_orders) OVER (ORDER BY month)
        )
        /
        NULLIF(
            LAG(delivered_orders) OVER (ORDER BY month),
            0
        ),
        2
    ) AS order_mom_growth_pct,

    ROUND(
        100.0 * (
            total_order_value
            - LAG(total_order_value) OVER (ORDER BY month)
        )
        /
        NULLIF(
            LAG(total_order_value) OVER (ORDER BY month),
            0
        ),
        2
    ) AS value_mom_growth_pct

FROM monthly_sales
ORDER BY month;

/*
Key observation:
November 2017:
- Orders MoM: +62.77%
- Total Order Value MoM: +53.55%
*/


/* ----------------------------------------------------------------------------
   2.4 YEAR-OVER-YEAR GROWTH
   Compare January-August 2017 with January-August 2018.
---------------------------------------------------------------------------- */

WITH monthly_sales AS (
    SELECT
        EXTRACT(
            YEAR FROM o.order_purchase_timestamp
        )::INT AS year,

        EXTRACT(
            MONTH FROM o.order_purchase_timestamp
        )::INT AS month_num,

        COUNT(DISTINCT o.order_id) AS delivered_orders,

        SUM(
            oi.price + oi.freight_value
        ) AS total_order_value

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= DATE '2017-01-01'
      AND o.order_purchase_timestamp < DATE '2018-09-01'

    GROUP BY
        EXTRACT(
            YEAR FROM o.order_purchase_timestamp
        ),
        EXTRACT(
            MONTH FROM o.order_purchase_timestamp
        )
)

SELECT
    s2017.month_num,

    s2017.delivered_orders AS orders_2017,
    s2018.delivered_orders AS orders_2018,

    ROUND(
        100.0
        * (
            s2018.delivered_orders
            - s2017.delivered_orders
        )
        / s2017.delivered_orders,
        2
    ) AS orders_yoy_growth_pct,

    ROUND(
        s2017.total_order_value,
        2
    ) AS value_2017,

    ROUND(
        s2018.total_order_value,
        2
    ) AS value_2018,

    ROUND(
        100.0
        * (
            s2018.total_order_value
            - s2017.total_order_value
        )
        / s2017.total_order_value,
        2
    ) AS value_yoy_growth_pct

FROM monthly_sales s2017

JOIN monthly_sales s2018
    ON s2017.month_num = s2018.month_num
   AND s2017.year = 2017
   AND s2018.year = 2018

ORDER BY s2017.month_num;

/*
Key insights:
- Jan-Aug 2018 delivered orders were approximately 139.94% higher
  than Jan-Aug 2017.
- Total Order Value increased approximately 143.36%.
- AOV increased only approximately 1.42%.
- Growth was therefore primarily driven by higher order volume.
- Every comparable month from January through August recorded YoY growth.
*/


/* ============================================================================
   3. PRODUCT AND CATEGORY ANALYSIS
============================================================================ */


/* ----------------------------------------------------------------------------
   3.1 TOP CATEGORIES BY PRODUCT GMV
---------------------------------------------------------------------------- */

SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'unknown'
    ) AS category,

    COUNT(*) AS items_sold,

    COUNT(
        DISTINCT oi.order_id
    ) AS orders,

    ROUND(
        SUM(oi.price),
        2
    ) AS product_gmv

FROM order_items oi

JOIN orders o
    ON oi.order_id = o.order_id

JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation ct
    ON p.product_category_name
     = ct.product_category_name

WHERE o.order_status = 'delivered'

GROUP BY 1

ORDER BY product_gmv DESC

LIMIT 15;


/* ----------------------------------------------------------------------------
   3.2 CATEGORY GMV SHARE AND AVERAGE ITEM PRICE
---------------------------------------------------------------------------- */

WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'unknown'
        ) AS category,

        COUNT(*) AS items_sold,

        COUNT(
            DISTINCT oi.order_id
        ) AS orders,

        SUM(oi.price) AS product_gmv

    FROM order_items oi

    JOIN orders o
        ON oi.order_id = o.order_id

    JOIN products p
        ON oi.product_id = p.product_id

    LEFT JOIN category_translation ct
        ON p.product_category_name
         = ct.product_category_name

    WHERE o.order_status = 'delivered'

    GROUP BY 1
)

SELECT
    category,
    items_sold,
    orders,

    ROUND(
        product_gmv,
        2
    ) AS product_gmv,

    ROUND(
        100.0 * product_gmv
        / SUM(product_gmv) OVER (),
        2
    ) AS gmv_share_pct,

    ROUND(
        product_gmv / items_sold,
        2
    ) AS average_item_price

FROM category_sales

ORDER BY product_gmv DESC

LIMIT 15;

/*
Key observations:
- Health & Beauty leads Product GMV with 9.33%.
- Watches & Gifts ranks second in GMV despite lower item volume,
  supported by a higher average item price.
- Top five categories account for 39.83% of Product GMV.
*/


/* ----------------------------------------------------------------------------
   3.3 TOP CATEGORIES BY ITEM VOLUME
---------------------------------------------------------------------------- */

WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'unknown'
        ) AS category,

        COUNT(*) AS items_sold,

        COUNT(
            DISTINCT oi.order_id
        ) AS orders,

        SUM(oi.price) AS product_gmv

    FROM order_items oi

    JOIN orders o
        ON oi.order_id = o.order_id

    JOIN products p
        ON oi.product_id = p.product_id

    LEFT JOIN category_translation ct
        ON p.product_category_name
         = ct.product_category_name

    WHERE o.order_status = 'delivered'

    GROUP BY 1
)

SELECT
    category,
    items_sold,

    ROUND(
        100.0 * items_sold
        / SUM(items_sold) OVER (),
        2
    ) AS item_share_pct,

    orders,

    ROUND(
        product_gmv,
        2
    ) AS product_gmv,

    ROUND(
        product_gmv / items_sold,
        2
    ) AS average_item_price

FROM category_sales

ORDER BY items_sold DESC

LIMIT 15;

/*
Key observation:
Bed, Bath & Table leads item volume with 9.94%, while
Health & Beauty leads Product GMV.
*/


/* ----------------------------------------------------------------------------
   3.4 CATEGORY GMV CONCENTRATION
---------------------------------------------------------------------------- */

WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'unknown'
        ) AS category,

        SUM(oi.price) AS product_gmv

    FROM order_items oi

    JOIN orders o
        ON oi.order_id = o.order_id

    JOIN products p
        ON oi.product_id = p.product_id

    LEFT JOIN category_translation ct
        ON p.product_category_name
         = ct.product_category_name

    WHERE o.order_status = 'delivered'

    GROUP BY 1
),

ranked_categories AS (
    SELECT
        category,
        product_gmv,

        ROUND(
            100.0 * product_gmv
            / SUM(product_gmv) OVER (),
            2
        ) AS gmv_share_pct,

        SUM(product_gmv) OVER (
            ORDER BY product_gmv DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW
        ) AS cumulative_gmv,

        SUM(product_gmv) OVER () AS total_gmv

    FROM category_sales
)

SELECT
    category,

    ROUND(
        product_gmv,
        2
    ) AS product_gmv,

    gmv_share_pct,

    ROUND(
        100.0 * cumulative_gmv
        / total_gmv,
        2
    ) AS cumulative_gmv_pct

FROM ranked_categories

ORDER BY product_gmv DESC;

/*
Key observation:
- 18 categories are required to exceed 80% of Product GMV.
- The first 18 categories represent 81.29%.
*/


/* ----------------------------------------------------------------------------
   3.5 PRODUCTS WITH MISSING CATEGORY
---------------------------------------------------------------------------- */

SELECT
    COUNT(
        DISTINCT p.product_id
    ) AS products,

    COUNT(*) AS items_sold,

    COUNT(
        DISTINCT oi.order_id
    ) AS orders,

    ROUND(
        SUM(oi.price),
        2
    ) AS product_gmv,

    ROUND(
        100.0 * SUM(oi.price)
        /
        (
            SELECT
                SUM(oi2.price)
            FROM order_items oi2
            JOIN orders o2
                ON oi2.order_id = o2.order_id
            WHERE o2.order_status = 'delivered'
        ),
        2
    ) AS gmv_share_pct

FROM order_items oi

JOIN orders o
    ON oi.order_id = o.order_id

JOIN products p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered'
  AND p.product_category_name IS NULL;

/*
Observed result:
- Products: 584
- Items sold: 1,537
- Orders: 1,392
- Product GMV: R$ 170,726.63
- GMV share: 1.29%

Treatment:
Records are retained and represented as 'unknown' in category analyses.
*/


/* ============================================================================
   4. CUSTOMER AND GEOGRAPHIC ANALYSIS
============================================================================ */


/* ----------------------------------------------------------------------------
   4.1 CUSTOMERS AND ORDERS BY STATE
---------------------------------------------------------------------------- */

SELECT
    c.customer_state AS state,

    COUNT(
        DISTINCT c.customer_unique_id
    ) AS unique_customers,

    COUNT(
        DISTINCT o.order_id
    ) AS delivered_orders

FROM orders o

JOIN customers c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_state

ORDER BY unique_customers DESC;


/* ----------------------------------------------------------------------------
   4.2 CUSTOMER STATE STABILITY
---------------------------------------------------------------------------- */

WITH customer_states AS (
    SELECT
        c.customer_unique_id,

        COUNT(
            DISTINCT c.customer_state
        ) AS states_count

    FROM orders o

    JOIN customers c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'

    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS unique_customers,

    COUNT(*) FILTER (
        WHERE states_count = 1
    ) AS customers_one_state,

    COUNT(*) FILTER (
        WHERE states_count > 1
    ) AS customers_multiple_states,

    MAX(states_count) AS maximum_states_per_customer

FROM customer_states;

/*
Observed result:
- 93,358 unique customers
- 93,321 associated with one state
- 37 associated with multiple states
- 99.96% state stability
*/


/* ----------------------------------------------------------------------------
   4.3 PRODUCT GMV AND ORDER SHARE BY STATE
---------------------------------------------------------------------------- */

WITH state_sales AS (
    SELECT
        c.customer_state AS state,

        COUNT(
            DISTINCT c.customer_unique_id
        ) AS unique_customers,

        COUNT(
            DISTINCT o.order_id
        ) AS delivered_orders,

        SUM(oi.price) AS product_gmv

    FROM orders o

    JOIN customers c
        ON o.customer_id = c.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY c.customer_state
)

SELECT
    state,
    unique_customers,
    delivered_orders,

    ROUND(
        100.0 * delivered_orders
        / SUM(delivered_orders) OVER (),
        2
    ) AS order_share_pct,

    ROUND(
        product_gmv,
        2
    ) AS product_gmv,

    ROUND(
        100.0 * product_gmv
        / SUM(product_gmv) OVER (),
        2
    ) AS gmv_share_pct

FROM state_sales

ORDER BY product_gmv DESC;

/*
Key observations:
- SP accounts for 41.98% of delivered orders and 38.33% of Product GMV.
- SP, RJ, and MG together represent:
  66.55% of delivered orders
  63.38% of Product GMV.
*/


/* ----------------------------------------------------------------------------
   4.4 AOV AND FREIGHT BY STATE
---------------------------------------------------------------------------- */

WITH order_values AS (
    SELECT
        c.customer_state AS state,
        o.order_id,

        SUM(
            oi.price
        ) AS product_value,

        SUM(
            oi.freight_value
        ) AS freight_value,

        SUM(
            oi.price + oi.freight_value
        ) AS total_order_value

    FROM orders o

    JOIN customers c
        ON o.customer_id = c.customer_id

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        c.customer_state,
        o.order_id
)

SELECT
    state,

    COUNT(*) AS delivered_orders,

    ROUND(
        AVG(product_value),
        2
    ) AS avg_product_value,

    ROUND(
        AVG(freight_value),
        2
    ) AS avg_freight_value,

    ROUND(
        AVG(total_order_value),
        2
    ) AS average_order_value,

    ROUND(
        100.0 * SUM(freight_value)
        / SUM(total_order_value),
        2
    ) AS freight_share_pct

FROM order_values

GROUP BY state

ORDER BY average_order_value DESC;

/*
Key observations:
- SP has the largest order volume but the lowest state AOV:
  R$ 142.46.
- SP freight share: 12.17%.
- Higher AOV in several lower-volume states is explained by both
  higher product values and higher freight costs.
*/


/* ============================================================================
   5. LOGISTICS ANALYSIS
============================================================================ */


/* ----------------------------------------------------------------------------
   5.1 DELIVERY TIME AND ON-TIME DELIVERY RATE

   Business Rule:
   An order is considered on time when the delivery DATE is equal to
   or earlier than the estimated delivery DATE.

   Using timestamps would incorrectly classify orders delivered later
   during the estimated calendar day as late.
---------------------------------------------------------------------------- */

WITH delivery_analysis AS (
    SELECT
        o.order_id,

        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_purchase_timestamp
            )
        ) / 86400.0 AS delivery_days,

        CASE
            WHEN o.order_delivered_customer_date::DATE
                 <= o.order_estimated_delivery_date::DATE
            THEN 1
            ELSE 0
        END AS on_time

    FROM orders o

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)

SELECT
    COUNT(*) AS analyzed_orders,

    ROUND(
        AVG(delivery_days)::NUMERIC,
        2
    ) AS average_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY delivery_days
        )::NUMERIC,
        2
    ) AS median_delivery_days,

    SUM(on_time) AS on_time_orders,

    COUNT(*) - SUM(on_time) AS late_orders,

    ROUND(
        100.0 * SUM(on_time)
        / COUNT(*),
        2
    ) AS on_time_delivery_pct

FROM delivery_analysis;

/*
Observed result:
- Analyzed orders: 96,470
- Average delivery time: 12.56 days
- Median delivery time: 10.22 days
- On-time orders: 89,936
- Late orders: 6,534
- On-Time Delivery Rate: 93.23%
*/


/* ----------------------------------------------------------------------------
   5.2 LATE DELIVERY SEVERITY
---------------------------------------------------------------------------- */

WITH late_deliveries AS (
    SELECT
        order_id,

        (
            order_delivered_customer_date::DATE
            - order_estimated_delivery_date::DATE
        ) AS delay_days

    FROM orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_delivered_customer_date::DATE
          > order_estimated_delivery_date::DATE
)

SELECT
    COUNT(*) AS late_orders,

    ROUND(
        AVG(delay_days)::NUMERIC,
        2
    ) AS average_delay_days,

    PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY delay_days
        ) AS median_delay_days,

    PERCENTILE_CONT(0.90)
        WITHIN GROUP (
            ORDER BY delay_days
        ) AS p90_delay_days,

    MAX(delay_days) AS maximum_delay_days

FROM late_deliveries;

/*
Observed result:
- Late orders: 6,534
- Average delay: 10.62 days
- Median delay: 7 days
- P90 delay: 22 days
- Maximum delay: 188 days
*/


/* ----------------------------------------------------------------------------
   5.3 DELAY DISTRIBUTION
---------------------------------------------------------------------------- */

WITH late_deliveries AS (
    SELECT
        order_id,

        (
            order_delivered_customer_date::DATE
            - order_estimated_delivery_date::DATE
        ) AS delay_days

    FROM orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_delivered_customer_date::DATE
          > order_estimated_delivery_date::DATE
),

delay_groups AS (
    SELECT
        order_id,
        delay_days,

        CASE
            WHEN delay_days BETWEEN 1 AND 3
                THEN '01 - 1 to 3 days'

            WHEN delay_days BETWEEN 4 AND 7
                THEN '02 - 4 to 7 days'

            WHEN delay_days BETWEEN 8 AND 14
                THEN '03 - 8 to 14 days'

            WHEN delay_days BETWEEN 15 AND 30
                THEN '04 - 15 to 30 days'

            ELSE '05 - More than 30 days'
        END AS delay_range

    FROM late_deliveries
)

SELECT
    delay_range,

    COUNT(*) AS late_orders,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage

FROM delay_groups

GROUP BY delay_range

ORDER BY delay_range;

/*
Key observations:
- 56.20% of late orders were delivered within 7 days after the estimate.
- 78.82% were delivered within 14 days.
- 5.28% exceeded 30 days.
*/


/* ============================================================================
   6. CUSTOMER SATISFACTION
============================================================================ */


/* ----------------------------------------------------------------------------
   6.1 REVIEW COVERAGE
   Multiple reviews are aggregated at order level to avoid overweighting
   orders containing more than one review record.
---------------------------------------------------------------------------- */

WITH reviews_per_order AS (
    SELECT
        order_id,
        COUNT(*) AS review_count,
        AVG(review_score) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
)

SELECT
    COUNT(*) AS delivered_orders,

    COUNT(r.order_id) AS orders_with_review,

    COUNT(*) - COUNT(r.order_id) AS orders_without_review,

    COUNT(*) FILTER (
        WHERE r.review_count > 1
    ) AS orders_with_multiple_reviews,

    ROUND(
        100.0 * COUNT(r.order_id)
        / COUNT(*),
        2
    ) AS review_coverage_pct

FROM orders o

LEFT JOIN reviews_per_order r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered';

/*
Observed result:
- Delivered orders: 96,478
- Orders with review: 95,832
- Orders without review: 646
- Orders with multiple reviews: 525
- Review coverage: 99.33%
*/


/* ----------------------------------------------------------------------------
   6.2 ON-TIME VS LATE CUSTOMER SATISFACTION
---------------------------------------------------------------------------- */

WITH reviews_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
),

delivery_reviews AS (
    SELECT
        o.order_id,

        CASE
            WHEN o.order_delivered_customer_date::DATE
                 <= o.order_estimated_delivery_date::DATE
            THEN 'On time'
            ELSE 'Late'
        END AS delivery_status,

        r.avg_review_score

    FROM orders o

    JOIN reviews_per_order r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)

SELECT
    delivery_status,

    COUNT(*) AS orders,

    ROUND(
        AVG(avg_review_score)::NUMERIC,
        2
    ) AS average_review_score,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE avg_review_score <= 2
        ) / COUNT(*),
        2
    ) AS low_review_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE avg_review_score >= 4
        ) / COUNT(*),
        2
    ) AS positive_review_pct

FROM delivery_reviews

GROUP BY delivery_status

ORDER BY delivery_status;

/*
Observed result:

Late:
- Orders: 6,381
- Average Review Score: 2.27
- Low Review Rate: 62.36%
- Positive Review Rate: 26.74%

On time:
- Orders: 89,443
- Average Review Score: 4.29
- Low Review Rate: 9.23%
- Positive Review Rate: 82.64%

Interpretation:
Delivery performance shows a strong association with customer satisfaction.
This analysis demonstrates association, not causation.
*/


/* ----------------------------------------------------------------------------
   6.3 DELAY SEVERITY VS CUSTOMER SATISFACTION
---------------------------------------------------------------------------- */

WITH reviews_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
),

delivery_reviews AS (
    SELECT
        o.order_id,

        (
            o.order_delivered_customer_date::DATE
            - o.order_estimated_delivery_date::DATE
        ) AS delay_days,

        r.avg_review_score

    FROM orders o

    JOIN reviews_per_order r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),

delay_groups AS (
    SELECT
        order_id,
        avg_review_score,

        CASE
            WHEN delay_days <= 0
                THEN '00 - On time'

            WHEN delay_days BETWEEN 1 AND 3
                THEN '01 - 1 to 3 days'

            WHEN delay_days BETWEEN 4 AND 7
                THEN '02 - 4 to 7 days'

            WHEN delay_days BETWEEN 8 AND 14
                THEN '03 - 8 to 14 days'

            WHEN delay_days BETWEEN 15 AND 30
                THEN '04 - 15 to 30 days'

            ELSE '05 - More than 30 days'
        END AS delay_range

    FROM delivery_reviews
)

SELECT
    delay_range,

    COUNT(*) AS orders,

    ROUND(
        AVG(avg_review_score)::NUMERIC,
        2
    ) AS average_review_score,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE avg_review_score <= 2
        ) / COUNT(*),
        2
    ) AS low_review_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE avg_review_score >= 4
        ) / COUNT(*),
        2
    ) AS positive_review_pct

FROM delay_groups

GROUP BY delay_range

ORDER BY delay_range;

/*
Observed result:

On time:
- Avg Review: 4.29

1-3 days late:
- Avg Review: 3.29

4-7 days late:
- Avg Review: 2.11

8-14 days late:
- Avg Review: 1.67

15-30 days late:
- Avg Review: 1.62

More than 30 days:
- Avg Review: 2.06

Interpretation:
Customer satisfaction deteriorates sharply after the estimated delivery date.
The relationship is strongly negative overall but not strictly monotonic
for extremely delayed orders.
*/


/* ----------------------------------------------------------------------------
   6.4 EXTREME DELAY REVIEW ANALYSIS
   Objective:
   Investigate the heterogeneous >30-day delay tail.
---------------------------------------------------------------------------- */

WITH reviews_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
),

severe_delays AS (
    SELECT
        o.order_id,

        (
            o.order_delivered_customer_date::DATE
            - o.order_estimated_delivery_date::DATE
        ) AS delay_days,

        r.avg_review_score

    FROM orders o

    JOIN reviews_per_order r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND (
          o.order_delivered_customer_date::DATE
          - o.order_estimated_delivery_date::DATE
      ) > 30
)

SELECT
    CASE
        WHEN delay_days BETWEEN 31 AND 45
            THEN '31 - 45 days'

        WHEN delay_days BETWEEN 46 AND 60
            THEN '46 - 60 days'

        WHEN delay_days BETWEEN 61 AND 90
            THEN '61 - 90 days'

        ELSE 'More than 90 days'
    END AS delay_range,

    COUNT(*) AS orders,

    ROUND(
        AVG(avg_review_score)::NUMERIC,
        2
    ) AS average_review_score,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE avg_review_score <= 2
        ) / COUNT(*),
        2
    ) AS low_review_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE avg_review_score >= 4
        ) / COUNT(*),
        2
    ) AS positive_review_pct

FROM severe_delays

GROUP BY 1

ORDER BY MIN(delay_days);

/*
Observed result:
31-45 days:
- 185 orders
- Avg Review: 1.68

46-60 days:
- 69 orders
- Avg Review: 2.25

61-90 days:
- 30 orders
- Avg Review: 2.43

More than 90 days:
- 45 orders
- Avg Review: 3.07

Interpretation:
The extreme-delay tail contains relatively small sample sizes and does not
follow a consistent monotonic pattern. No causal explanation is inferred.
*/


/* ============================================================================
   FINAL BUSINESS INSIGHTS
============================================================================ */

/*
1. Commercial Scale
   - 96,478 delivered orders.
   - 93,358 unique customers with delivered orders.
   - Product GMV: R$ 13.22M.
   - Total Order Value: R$ 15.42M.
   - AOV: R$ 159.83.

2. Customer Behavior
   - Only 3.00% of customers placed more than one delivered order.
   - 90.01% of delivered orders contained exactly one item.

3. Growth
   - Jan-Aug 2018 recorded approximately 139.94% more delivered orders
     than the same period in 2017.
   - Total Order Value increased approximately 143.36%.
   - AOV increased only approximately 1.42%, indicating that growth was
     primarily driven by order volume.

4. Product Categories
   - Health & Beauty leads Product GMV.
   - Bed, Bath & Table leads item volume.
   - Top five categories account for 39.83% of Product GMV.
   - 18 categories are required to exceed 80% of Product GMV.

5. Geography
   - SP accounts for 41.98% of delivered orders.
   - SP, RJ, and MG together represent 66.55% of delivered orders.
   - Geographic AOV differences reflect both product value and freight.

6. Logistics
   - Average delivery time: 12.56 days.
   - Median delivery time: 10.22 days.
   - On-Time Delivery Rate: 93.23%.
   - Median delay among late orders: 7 days.

7. Customer Satisfaction
   - On-time orders: average review score 4.29.
   - Late orders: average review score 2.27.
   - 62.36% of late orders received low review scores.
   - Only 9.23% of on-time orders received low review scores.
   - Delivery delay shows a strong negative association with satisfaction.

Final Note:
All business analyses preserve the raw dataset.
Records are excluded only when the specific KPI requires unavailable
or logically unsuitable fields.
*/
