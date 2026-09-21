-- ============================================================
-- OLIST E-COMMERCE ANALYTICS
-- Data Quality
-- ============================================================
-- Author: Renato Marcondes de Souza
-- Database: PostgreSQL
-- Project: Brazilian E-Commerce Analytics
--
-- Description:
-- Performs logical and business consistency checks on the Olist
-- dataset after the initial Data Validation process, following
-- Section 4 of the project documentation.
--
-- Data Quality scope:
-- Rule 1 - Order Timeline Consistency
-- Rule 2 - Order Status and Date Consistency
-- Rule 3 - Financial Values Consistency
-- Rule 4 - Review Consistency
-- Rule 5 - Product Physical Attributes
-- Rule 6 - Order Status Consistency
-- Rule 7 - Order and Payment Consistency
-- Rule 8 - Geographic Consistency
--
-- Methodology:
-- Identify -> Quantify -> Investigate -> Assess impact
-- -> Define treatment
--
-- Note:
-- This script performs read-only validation queries.
-- No records are modified or deleted from the raw dataset.
-- ============================================================



-- ============================================================
-- RULE 1 - ORDER TIMELINE CONSISTENCY
-- ============================================================

-- Objective:
-- Verify whether the main order timestamps follow the expected
-- chronological sequence:
--
-- Purchase -> Approval -> Carrier -> Customer Delivery
--
-- Records that violate this sequence are quantified and
-- investigated before any treatment decision is made.


-- ------------------------------------------------------------
-- 1.1 Orders with timeline inconsistencies
-- ------------------------------------------------------------

SELECT COUNT(*) AS orders_with_timeline_inconsistencies
FROM orders
WHERE
       order_approved_at < order_purchase_timestamp
    OR order_delivered_carrier_date < order_purchase_timestamp
    OR order_delivered_customer_date < order_purchase_timestamp
    OR (
        order_delivered_customer_date IS NOT NULL
        AND order_delivered_carrier_date IS NOT NULL
        AND order_delivered_customer_date
            < order_delivered_carrier_date
    );

-- Result observed:
-- 189 orders with at least one timeline inconsistency.



-- ------------------------------------------------------------
-- 1.2 Breakdown by inconsistency type
-- ------------------------------------------------------------

SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at < order_purchase_timestamp
    ) AS approval_before_purchase,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date
              < order_purchase_timestamp
    ) AS carrier_before_purchase,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              < order_purchase_timestamp
    ) AS delivery_before_purchase,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_delivered_carrier_date IS NOT NULL
          AND order_delivered_customer_date
              < order_delivered_carrier_date
    ) AS delivery_before_carrier

FROM orders;

-- Results observed:
-- Approval before purchase:        0
-- Carrier before purchase:       166
-- Delivery before purchase:        0
-- Delivery before carrier:        23



-- ------------------------------------------------------------
-- 1.3 Investigation:
-- Carrier date before purchase
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_cases,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp
              - order_delivered_carrier_date
              < INTERVAL '1 hour'
    ) AS less_than_1_hour,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp
              - order_delivered_carrier_date
              >= INTERVAL '1 hour'
          AND order_purchase_timestamp
              - order_delivered_carrier_date
              < INTERVAL '1 day'
    ) AS between_1_hour_and_1_day,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp
              - order_delivered_carrier_date
              >= INTERVAL '1 day'
          AND order_purchase_timestamp
              - order_delivered_carrier_date
              < INTERVAL '7 days'
    ) AS between_1_and_7_days,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp
              - order_delivered_carrier_date
              >= INTERVAL '7 days'
    ) AS more_than_7_days

FROM orders
WHERE order_delivered_carrier_date < order_purchase_timestamp;

-- Results observed:
-- Total cases:                  166
-- Less than 1 hour:            121
-- Between 1 hour and 1 day:     43
-- Between 1 and 7 days:          1
-- More than 7 days:              1
--
-- 164 of 166 cases (98.8%) differ by less than 24 hours.



-- Detailed investigation of carrier-before-purchase cases.

SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_purchase_timestamp
        - order_delivered_carrier_date AS time_difference
FROM orders
WHERE order_delivered_carrier_date < order_purchase_timestamp
ORDER BY time_difference DESC;



-- ------------------------------------------------------------
-- 1.4 Investigation:
-- Customer delivery before carrier date
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_cases,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date
              - order_delivered_customer_date
              <= INTERVAL '24 hours'
    ) AS up_to_24_hours,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date
              - order_delivered_customer_date
              > INTERVAL '24 hours'
    ) AS more_than_24_hours

FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date
      < order_delivered_carrier_date;

-- Results observed:
-- Total cases:             23
-- Up to 24 hours:           7
-- More than 24 hours:      16
--
-- 16 of 23 cases (69.6%) differ by more than 24 hours.



-- Detailed investigation.

SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_delivered_carrier_date
        - order_delivered_customer_date AS time_difference
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date
      < order_delivered_carrier_date
ORDER BY time_difference DESC;


-- Treatment decision:
-- No records are deleted from the raw dataset.
--
-- Orders with timeline inconsistencies should be flagged and
-- excluded only from KPIs that depend on processing or delivery
-- time calculations.
--
-- The dataset does not provide enough information to determine
-- the root cause of these timestamp inconsistencies.



-- ============================================================
-- RULE 2 - ORDER STATUS AND DATE CONSISTENCY
-- ============================================================

-- Objective:
-- Verify whether the recorded order status is consistent with
-- the dates already registered in the order lifecycle.



-- ------------------------------------------------------------
-- 2.1 Delivered orders without delivery date
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_delivered,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS delivered_without_delivery_date

FROM orders
WHERE order_status = 'delivered';

-- Results observed:
-- Total delivered: 96,478
-- Without delivery date: 8
-- Approximately 0.008%.



-- ------------------------------------------------------------
-- 2.2 Canceled orders with delivery date
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_canceled,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
    ) AS canceled_with_delivery_date

FROM orders
WHERE order_status = 'canceled';

-- Results observed:
-- Total canceled: 625
-- Canceled with delivery date: 6
-- Approximately 0.960%.



-- Inspect canceled orders with recorded delivery.

SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM orders
WHERE order_status = 'canceled'
  AND order_delivered_customer_date IS NOT NULL
ORDER BY order_purchase_timestamp;

-- Result observed:
-- 6 records.
--
-- All contain purchase, approval, carrier and customer delivery
-- timestamps.
--
-- The dataset does not provide enough information to determine
-- why the final status is recorded as canceled.



-- ------------------------------------------------------------
-- 2.3 Delivered orders with missing process dates
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS unique_delivered_orders_with_missing_stage,

    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS missing_approval_date,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS missing_carrier_date,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_delivery_date

FROM orders

WHERE order_status = 'delivered'
  AND (
         order_approved_at IS NULL
      OR order_delivered_carrier_date IS NULL
      OR order_delivered_customer_date IS NULL
  );

-- Results observed:
-- Unique delivered orders affected: 23
-- Missing approval date:             14
-- Missing carrier date:               2
-- Missing delivery date:              8
--
-- Individual counts total 24 occurrences because one order
-- belongs to more than one missing-date condition.



-- Identify delivered orders with more than one missing date.

SELECT
    order_id,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM orders
WHERE order_status = 'delivered'
  AND (
        (order_approved_at IS NULL)::INTEGER
      + (order_delivered_carrier_date IS NULL)::INTEGER
      + (order_delivered_customer_date IS NULL)::INTEGER
      ) > 1;

-- Result observed:
-- 1 order contains more than one missing process date.



-- ------------------------------------------------------------
-- 2.4 Consolidated number of unique affected orders
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT order_id) AS unique_orders_with_status_date_issues
FROM orders
WHERE
    (
        order_status = 'delivered'
        AND (
               order_approved_at IS NULL
            OR order_delivered_carrier_date IS NULL
            OR order_delivered_customer_date IS NULL
        )
    )
    OR
    (
        order_status = 'canceled'
        AND order_delivered_customer_date IS NOT NULL
    );

-- Result observed:
-- 29 unique orders.
--
-- Important:
-- The 8 delivered orders from Rule 2.1 are already included
-- within the 23 delivered orders identified in Rule 2.3.
--
-- Therefore:
-- 23 delivered orders + 6 canceled orders = 29 unique orders.


-- Treatment decision:
-- Keep all records in the raw dataset.
--
-- Orders with status/date inconsistencies should be excluded
-- only from KPIs that depend on the affected lifecycle dates.



-- ============================================================
-- RULE 3 - FINANCIAL VALUES CONSISTENCY
-- ============================================================

-- Objective:
-- Verify whether item prices, freight values, payment values,
-- and payment installments contain invalid zero or negative
-- values that could affect financial analysis.



-- ------------------------------------------------------------
-- 3.1 Item prices
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_items,

    COUNT(*) FILTER (
        WHERE price = 0
    ) AS zero_price,

    COUNT(*) FILTER (
        WHERE price < 0
    ) AS negative_price,

    MIN(price) AS minimum_price,
    MAX(price) AS maximum_price

FROM order_items;

-- Results observed:
-- Total items:   112,650
-- Zero prices:         0
-- Negative prices:     0
-- Minimum price: R$ 0.85
-- Maximum price: R$ 6,735.00



-- ------------------------------------------------------------
-- 3.2 Freight values
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_items,

    COUNT(*) FILTER (
        WHERE freight_value = 0
    ) AS zero_freight,

    COUNT(*) FILTER (
        WHERE freight_value < 0
    ) AS negative_freight,

    MIN(freight_value) AS minimum_freight,
    MAX(freight_value) AS maximum_freight

FROM order_items;

-- Results observed:
-- Zero freight values: 383
-- Negative freight values: 0
-- Minimum freight: R$ 0.00
-- Maximum freight: R$ 409.68



-- ------------------------------------------------------------
-- 3.3 Payment values
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_payments,

    COUNT(*) FILTER (
        WHERE payment_value = 0
    ) AS zero_payment_records,

    COUNT(DISTINCT order_id) FILTER (
        WHERE payment_value = 0
    ) AS orders_with_zero_payment,

    COUNT(*) FILTER (
        WHERE payment_value < 0
    ) AS negative_payment_records

FROM order_payments;

-- Results observed:
-- Zero payment records: 9
-- Orders affected: 8
-- Negative payment records: 0



-- Inspect zero-value payments.

SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM order_payments
WHERE payment_value = 0
ORDER BY order_id, payment_sequential;



-- Distribution of zero-value payments by payment type.

SELECT
    payment_type,
    COUNT(*) AS zero_payment_records
FROM order_payments
WHERE payment_value = 0
GROUP BY payment_type
ORDER BY zero_payment_records DESC;



-- ------------------------------------------------------------
-- 3.4 Payment installments
-- ------------------------------------------------------------

SELECT
    COUNT(*) FILTER (
        WHERE payment_installments = 0
    ) AS zero_installments,

    COUNT(*) FILTER (
        WHERE payment_installments < 0
    ) AS negative_installments

FROM order_payments;

-- Results observed:
-- Payment records with zero installments: 2
-- Negative installments: 0



-- Inspect records with zero installments.

SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM order_payments
WHERE payment_installments <= 0
ORDER BY order_id, payment_sequential;

-- Results observed:
-- 2 records.
-- Both use payment_type = 'credit_card'.
-- Both are associated with payment_sequential = 2.
--
-- No cause is inferred from the available data.


-- Treatment decision:
-- Zero freight and zero payment records are preserved.
--
-- The dataset does not provide sufficient evidence to classify
-- these values automatically as data errors.
--
-- Records with payment_installments = 0 are kept and documented
-- as isolated inconsistencies.



-- ============================================================
-- RULE 4 - REVIEW CONSISTENCY
-- ============================================================

-- Objective:
-- Verify whether review_score values remain within the expected
-- rating scale from 1 to 5 and analyze their distribution.



-- ------------------------------------------------------------
-- 4.1 Review score range
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_reviews,
    MIN(review_score) AS minimum_score,
    MAX(review_score) AS maximum_score,

    COUNT(*) FILTER (
        WHERE review_score < 1 OR review_score > 5
    ) AS invalid_scores

FROM order_reviews;

-- Results observed:
-- Total reviews: 99,224
-- Minimum score: 1
-- Maximum score: 5
-- Invalid scores: 0



-- ------------------------------------------------------------
-- 4.2 Review score distribution
-- ------------------------------------------------------------

SELECT
    review_score,
    COUNT(*) AS quantity,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage

FROM order_reviews

GROUP BY review_score
ORDER BY review_score;

-- Results observed:
--
-- Score 1: 11,424  (11.51%)
-- Score 2:  3,151  ( 3.18%)
-- Score 3:  8,179  ( 8.24%)
-- Score 4: 19,142  (19.29%)
-- Score 5: 57,328  (57.78%)
--
-- Scores 4 and 5 represent approximately 77.07% of reviews.


-- Treatment decision:
-- No treatment required.
-- review_score can be used directly in satisfaction analysis.



-- ============================================================
-- RULE 5 - PRODUCT PHYSICAL ATTRIBUTES
-- ============================================================

-- Objective:
-- Verify whether product weight and dimensions contain zero,
-- negative or extreme values that could compromise logistics
-- analysis.
--
-- Null values were evaluated separately in
-- 02_data_validation.sql.



-- ------------------------------------------------------------
-- 5.1 Zero or negative physical attributes
-- ------------------------------------------------------------

SELECT
    COUNT(*) FILTER (
        WHERE product_weight_g <= 0
    ) AS invalid_weight,

    COUNT(*) FILTER (
        WHERE product_length_cm <= 0
    ) AS invalid_length,

    COUNT(*) FILTER (
        WHERE product_height_cm <= 0
    ) AS invalid_height,

    COUNT(*) FILTER (
        WHERE product_width_cm <= 0
    ) AS invalid_width

FROM products;

-- Results observed:
-- Weight <= 0: 4
-- Length <= 0: 0
-- Height <= 0: 0
-- Width <= 0: 0



-- Inspect products with zero or negative physical attributes.

SELECT
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM products
WHERE product_weight_g <= 0
   OR product_length_cm <= 0
   OR product_height_cm <= 0
   OR product_width_cm <= 0
ORDER BY product_id;

-- Result observed:
-- 4 products with weight = 0 g.
-- All belong to category cama_mesa_banho.
-- All have dimensions 30 x 25 x 30 cm.



-- ------------------------------------------------------------
-- 5.2 Maximum physical values
-- ------------------------------------------------------------

SELECT
    MAX(product_weight_g) AS maximum_weight_g,
    MAX(product_length_cm) AS maximum_length_cm,
    MAX(product_height_cm) AS maximum_height_cm,
    MAX(product_width_cm) AS maximum_width_cm
FROM products;

-- Results observed:
-- Maximum weight: 40,425 g
-- Maximum length: 105 cm
-- Maximum height: 105 cm
-- Maximum width: 118 cm


-- Treatment decision:
-- The four products with zero weight are preserved but should
-- be excluded or flagged when metrics depend directly on weight.
--
-- Maximum values were inspected and were not classified as
-- inconsistencies based solely on their magnitude.



-- ============================================================
-- RULE 6 - ORDER STATUS CONSISTENCY
-- ============================================================

-- Objective:
-- Verify the values contained in order_status and analyze their
-- distribution across the dataset.



-- ------------------------------------------------------------
-- 6.1 Status distribution
-- ------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS quantity,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage

FROM orders

GROUP BY order_status
ORDER BY quantity DESC;

-- Results observed:
--
-- delivered    96,478   97.02%
-- shipped       1,107    1.11%
-- canceled        625    0.63%
-- unavailable     609    0.61%
-- invoiced        314    0.32%
-- processing      301    0.30%
-- created           5    0.01%
-- approved          2    0.00%



-- ------------------------------------------------------------
-- 6.2 Distinct and null status values
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT order_status) AS distinct_statuses,

    COUNT(*) FILTER (
        WHERE order_status IS NULL
    ) AS null_statuses

FROM orders;

-- Results observed:
-- Distinct statuses: 8
-- Null statuses: 0



-- ------------------------------------------------------------
-- 6.3 Check for unexpected status values
-- ------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS quantity
FROM orders
WHERE order_status NOT IN (
    'delivered',
    'shipped',
    'canceled',
    'unavailable',
    'invoiced',
    'processing',
    'created',
    'approved'
)
GROUP BY order_status
ORDER BY quantity DESC;

-- Result observed:
-- No unexpected values.


-- Treatment decision:
-- No treatment required for the order_status domain.
--
-- Relationships between order status and lifecycle dates were
-- evaluated separately in Rule 2.



-- ============================================================
-- RULE 7 - ORDER AND PAYMENT CONSISTENCY
-- ============================================================

-- Objective:
-- Compare the financial value calculated from order items and
-- freight against the total recorded in order_payments.
--
-- Important:
-- order_items and order_payments may both contain multiple rows
-- for the same order.
--
-- A direct JOIN would create a fan-out effect and inflate SUM()
-- calculations.
--
-- Therefore, each table is aggregated by order_id before the
-- totals are compared.



-- ------------------------------------------------------------
-- 7.1 Order value vs. payment value
-- ------------------------------------------------------------

WITH item_totals AS (

    SELECT
        order_id,
        SUM(price + freight_value) AS order_value
    FROM order_items
    GROUP BY order_id

),

payment_totals AS (

    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM order_payments
    GROUP BY order_id

)

SELECT
    COUNT(*) AS compared_orders,

    COUNT(*) FILTER (
        WHERE ABS(i.order_value - p.payment_value) <= 0.01
    ) AS consistent_orders,

    COUNT(*) FILTER (
        WHERE ABS(i.order_value - p.payment_value) > 0.01
    ) AS divergent_orders,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE ABS(i.order_value - p.payment_value) <= 0.01
        )
        / COUNT(*),
        2
    ) AS consistency_percentage

FROM item_totals i

JOIN payment_totals p
    ON i.order_id = p.order_id;

-- Results observed:
-- Compared orders:     98,665
-- Consistent orders:   98,362
-- Divergent orders:       303
-- Consistency rate:     99.69%



-- ------------------------------------------------------------
-- 7.2 Magnitude of the 303 divergences
-- ------------------------------------------------------------

WITH item_totals AS (

    SELECT
        order_id,
        SUM(price + freight_value) AS order_value
    FROM order_items
    GROUP BY order_id

),

payment_totals AS (

    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM order_payments
    GROUP BY order_id

),

differences AS (

    SELECT
        i.order_id,
        i.order_value,
        p.payment_value,
        ABS(i.order_value - p.payment_value) AS absolute_difference
    FROM item_totals i

    JOIN payment_totals p
        ON i.order_id = p.order_id

    WHERE ABS(i.order_value - p.payment_value) > 0.01
)

SELECT
    COUNT(*) FILTER (
        WHERE absolute_difference > 0.01
          AND absolute_difference <= 0.10
    ) AS between_002_and_010,

    COUNT(*) FILTER (
        WHERE absolute_difference > 0.10
          AND absolute_difference <= 1.00
    ) AS between_011_and_100,

    COUNT(*) FILTER (
        WHERE absolute_difference > 1.00
          AND absolute_difference <= 10.00
    ) AS between_101_and_1000,

    COUNT(*) FILTER (
        WHERE absolute_difference > 10.00
          AND absolute_difference <= 50.00
    ) AS between_1001_and_5000,

    COUNT(*) FILTER (
        WHERE absolute_difference > 50.00
    ) AS above_5000

FROM differences;

-- Results observed:
-- R$ 0.02 - R$ 0.10: 44
-- R$ 0.11 - R$ 1.00: 10
-- R$ 1.01 - R$10.00: 151
-- R$10.01 - R$50.00: 90
-- Above R$50.00:        8
--
-- Total: 303 divergent orders.



-- ------------------------------------------------------------
-- 7.3 Maximum financial divergence
-- ------------------------------------------------------------

WITH item_totals AS (

    SELECT
        order_id,
        SUM(price + freight_value) AS order_value
    FROM order_items
    GROUP BY order_id

),

payment_totals AS (

    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM order_payments
    GROUP BY order_id

)

SELECT
    MAX(ABS(i.order_value - p.payment_value))
        AS maximum_absolute_difference

FROM item_totals i

JOIN payment_totals p
    ON i.order_id = p.order_id;

-- Result observed:
-- Maximum absolute difference: R$ 182.81



-- ------------------------------------------------------------
-- 7.4 Investigate divergences above R$ 50
-- ------------------------------------------------------------

WITH item_totals AS (

    SELECT
        order_id,
        SUM(price + freight_value) AS order_value
    FROM order_items
    GROUP BY order_id

),

payment_totals AS (

    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM order_payments
    GROUP BY order_id

),

payment_profile AS (

    SELECT
        order_id,
        COUNT(*) AS payment_records,
        STRING_AGG(
            DISTINCT payment_type,
            ', '
            ORDER BY payment_type
        ) AS payment_types,
        MIN(payment_installments) AS min_installments,
        MAX(payment_installments) AS max_installments
    FROM order_payments
    GROUP BY order_id

)

SELECT
    o.order_id,
    o.order_status,
    i.order_value,
    p.payment_value,

    p.payment_value - i.order_value
        AS signed_difference,

    ABS(p.payment_value - i.order_value)
        AS absolute_difference,

    pp.payment_records,
    pp.payment_types,
    pp.min_installments,
    pp.max_installments

FROM item_totals i

JOIN payment_totals p
    ON i.order_id = p.order_id

JOIN orders o
    ON i.order_id = o.order_id

JOIN payment_profile pp
    ON i.order_id = pp.order_id

WHERE ABS(p.payment_value - i.order_value) > 50

ORDER BY absolute_difference DESC;

-- Results observed:
-- 8 orders above R$50 difference.
-- All have order_status = 'delivered'.
-- All contain one payment record.
-- All use credit_card.
-- Installments range from 5 to 24.
-- Maximum difference: R$182.81.



-- ------------------------------------------------------------
-- 7.5 Direction of divergences above R$ 50
-- ------------------------------------------------------------

WITH item_totals AS (

    SELECT
        order_id,
        SUM(price + freight_value) AS order_value
    FROM order_items
    GROUP BY order_id

),

payment_totals AS (

    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM order_payments
    GROUP BY order_id

)

SELECT
    COUNT(*) FILTER (
        WHERE p.payment_value > i.order_value
          AND ABS(p.payment_value - i.order_value) > 50
    ) AS payment_above_calculated_value,

    COUNT(*) FILTER (
        WHERE p.payment_value < i.order_value
          AND ABS(p.payment_value - i.order_value) > 50
    ) AS payment_below_calculated_value

FROM item_totals i

JOIN payment_totals p
    ON i.order_id = p.order_id;

-- Results observed:
-- Payment above calculated order value: 7
-- Payment below calculated order value: 1



-- ------------------------------------------------------------
-- 7.6 Orders excluded from the INNER JOIN comparison
-- ------------------------------------------------------------

SELECT
    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM order_items oi
            WHERE oi.order_id = o.order_id
        )
    ) AS orders_without_items,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM order_payments op
            WHERE op.order_id = o.order_id
        )
    ) AS orders_without_payments,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM order_items oi
            WHERE oi.order_id = o.order_id
        )
        AND NOT EXISTS (
            SELECT 1
            FROM order_payments op
            WHERE op.order_id = o.order_id
        )
    ) AS orders_without_items_and_payments

FROM orders o;

-- Results observed:
-- Orders without items: 775
-- Orders without payments: 1
-- Orders missing both: 0
--
-- Total orders outside the financial comparison: 776.



-- ------------------------------------------------------------
-- 7.7 Status distribution of orders without items
-- ------------------------------------------------------------

SELECT
    o.order_status,
    COUNT(*) AS quantity

FROM orders o

WHERE NOT EXISTS (
    SELECT 1
    FROM order_items oi
    WHERE oi.order_id = o.order_id
)

GROUP BY o.order_status
ORDER BY quantity DESC;

-- Results observed:
-- unavailable: 603
-- canceled:    164
-- created:       5
-- invoiced:      2
-- shipped:       1
--
-- unavailable + canceled = 767 orders
-- 767 / 775 = 98.97%



-- ------------------------------------------------------------
-- 7.8 Order without a payment record
-- ------------------------------------------------------------

SELECT
    o.*
FROM orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM order_payments op
    WHERE op.order_id = o.order_id
);

-- Result observed:
-- 1 order:
-- bfbd0f9bdef84302105ad712db648a6c
--
-- Status: delivered
-- Purchase date: 2016-09-15
--
-- Important:
-- This means that no payment record exists in order_payments
-- for this order.
--
-- It does NOT prove that the customer did not pay.


-- Treatment decision:
-- Keep all records in the raw dataset.
--
-- Financial divergences should be flagged and considered when
-- calculating financial KPIs.
--
-- Orders without items or payments should be excluded from
-- metrics that require both components.
--
-- No cause is inferred for the 303 divergent orders because the
-- available dataset does not provide sufficient evidence.



-- ============================================================
-- RULE 8 - GEOGRAPHIC CONSISTENCY
-- ============================================================

-- Objective:
-- Verify whether customer_state and seller_state contain valid
-- Brazilian state abbreviations and are consistently formatted.



-- ------------------------------------------------------------
-- 8.1 Customer states
-- ------------------------------------------------------------

SELECT
    customer_state,
    COUNT(*) AS quantity
FROM customers
GROUP BY customer_state
ORDER BY customer_state;

-- Result observed:
-- 27 distinct Brazilian UFs.
-- No invalid state abbreviations detected.



-- ------------------------------------------------------------
-- 8.2 Validate customer state domain
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT customer_state) AS distinct_customer_states,

    COUNT(*) FILTER (
        WHERE customer_state NOT IN (
            'AC','AL','AP','AM','BA','CE','DF','ES','GO',
            'MA','MT','MS','MG','PA','PB','PR','PE','PI',
            'RJ','RN','RS','RO','RR','SC','SP','SE','TO'
        )
    ) AS invalid_customer_states

FROM customers;

-- Results observed:
-- Distinct customer states: 27
-- Invalid customer state records: 0



-- ------------------------------------------------------------
-- 8.3 Seller states
-- ------------------------------------------------------------

SELECT
    seller_state,
    COUNT(*) AS quantity
FROM sellers
GROUP BY seller_state
ORDER BY seller_state;

-- Result observed:
-- 23 distinct Brazilian UFs.
-- No invalid state abbreviations detected.



-- ------------------------------------------------------------
-- 8.4 Validate seller state domain
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT seller_state) AS distinct_seller_states,

    COUNT(*) FILTER (
        WHERE seller_state NOT IN (
            'AC','AL','AP','AM','BA','CE','DF','ES','GO',
            'MA','MT','MS','MG','PA','PB','PR','PE','PI',
            'RJ','RN','RS','RO','RR','SC','SP','SE','TO'
        )
    ) AS invalid_seller_states

FROM sellers;

-- Results observed:
-- Distinct seller states: 23
-- Invalid seller state records: 0



-- ------------------------------------------------------------
-- 8.5 Brazilian states without sellers in the dataset
-- ------------------------------------------------------------

WITH valid_ufs (uf) AS (

    VALUES
        ('AC'), ('AL'), ('AP'), ('AM'), ('BA'),
        ('CE'), ('DF'), ('ES'), ('GO'), ('MA'),
        ('MT'), ('MS'), ('MG'), ('PA'), ('PB'),
        ('PR'), ('PE'), ('PI'), ('RJ'), ('RN'),
        ('RS'), ('RO'), ('RR'), ('SC'), ('SP'),
        ('SE'), ('TO')

)

SELECT uf AS state_without_sellers
FROM valid_ufs

EXCEPT

SELECT DISTINCT seller_state
FROM sellers

ORDER BY state_without_sellers;

-- Results observed:
-- AL
-- AP
-- RR
-- TO
--
-- Their absence represents the geographic distribution of the
-- dataset and is not treated as a data quality inconsistency.


-- Treatment decision:
-- customer_state and seller_state require no additional
-- standardization before geographic analysis.



-- ============================================================
-- FINAL DATA QUALITY NOTES
-- ============================================================

-- Overall conclusions:
--
-- 1. The dataset presents good overall structural and business
--    consistency.
--
-- 2. Timeline and status/date inconsistencies affect only a
--    small portion of orders and should be handled according to
--    the KPI being calculated.
--
-- 3. Financial comparison between orders and payments showed
--    99.69% consistency among comparable orders.
--
-- 4. Review scores and geographic state fields showed no domain
--    inconsistencies.
--
-- 5. Four products contain zero weight and should be treated
--    carefully in weight-based logistics analysis.
--
-- 6. No raw records are deleted as part of this process.
--
-- 7. Data quality issues are preserved, documented and handled
--    through filters or flags in the analytical layer when
--    required.
--
-- ============================================================
-- END OF DATA QUALITY SCRIPT
-- ============================================================
