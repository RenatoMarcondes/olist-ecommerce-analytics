-- ============================================================
-- OLIST E-COMMERCE ANALYTICS
-- Data Validation
-- ============================================================
-- Author: Renato Marcondes de Souza
-- Database: PostgreSQL
-- Project: Brazilian E-Commerce Analytics
--
-- Description:
-- Performs the initial structural validation of the Olist
-- dataset after data import, following Section 3 of the project
-- documentation.
--
-- Data Validation scope:
-- 3.1 - Data Load and Volume
-- 3.2 - Duplicate Records
-- 3.3 - Null Values
-- 3.4 - Referential Integrity
--
-- Methodology:
-- Validate load -> Check uniqueness -> Evaluate completeness
-- -> Validate relationships
--
-- Note:
-- This script performs read-only validation queries.
-- No records are modified or deleted from the raw dataset.
-- ============================================================



-- ============================================================
-- 3.1 DATA LOAD AND VOLUME
-- ============================================================

-- Objective:
-- Confirm that all 9 dataset tables were successfully imported
-- into PostgreSQL and validate the number of records available
-- for subsequent analysis.



-- ------------------------------------------------------------
-- 3.1.1 Record count by table
-- ------------------------------------------------------------

SELECT 'orders' AS table_name, COUNT(*) AS total_records
FROM orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL

SELECT 'order_payments', COUNT(*)
FROM order_payments

UNION ALL

SELECT 'order_reviews', COUNT(*)
FROM order_reviews

UNION ALL

SELECT 'customers', COUNT(*)
FROM customers

UNION ALL

SELECT 'products', COUNT(*)
FROM products

UNION ALL

SELECT 'sellers', COUNT(*)
FROM sellers

UNION ALL

SELECT 'geolocation', COUNT(*)
FROM geolocation

UNION ALL

SELECT 'category_translation', COUNT(*)
FROM category_translation

ORDER BY table_name;

-- Results observed:
--
-- category_translation:        71
-- customers:               99,441
-- geolocation:          1,000,163
-- order_items:            112,650
-- order_payments:         103,886
-- order_reviews:           99,224
-- orders:                  99,441
-- products:                32,951
-- sellers:                  3,095
--
-- More than 1.5 million records were successfully loaded across
-- the 9 dataset tables.


-- Validation decision:
-- All expected tables contain data and the imported volumes are
-- consistent with the expected structure of the Olist dataset.



-- ============================================================
-- 3.2 DUPLICATE RECORDS
-- ============================================================

-- Objective:
-- Identify duplicate records based on primary or composite keys
-- and detect exact duplicate rows in tables without a unique key.
--
-- Important:
-- Repeated identifiers do not automatically represent duplicate
-- records. Duplicate analysis must use the appropriate unique or
-- composite key for each table.



-- ------------------------------------------------------------
-- 3.2.1 Tables with single-column keys
-- ------------------------------------------------------------


-- Orders
-- Expected unique key: order_id

SELECT
    order_id,
    COUNT(*) AS occurrences
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Result observed:
-- 0 duplicate order_id values.



-- Customers
-- Expected unique key: customer_id

SELECT
    customer_id,
    COUNT(*) AS occurrences
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Result observed:
-- 0 duplicate customer_id values.



-- Products
-- Expected unique key: product_id

SELECT
    product_id,
    COUNT(*) AS occurrences
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Result observed:
-- 0 duplicate product_id values.



-- Sellers
-- Expected unique key: seller_id

SELECT
    seller_id,
    COUNT(*) AS occurrences
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- Result observed:
-- 0 duplicate seller_id values.



-- Category Translation
-- Expected unique key: product_category_name

SELECT
    product_category_name,
    COUNT(*) AS occurrences
FROM category_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;

-- Result observed:
-- 0 duplicate product_category_name values.



-- ------------------------------------------------------------
-- 3.2.2 Tables with composite keys
-- ------------------------------------------------------------


-- Order Items
-- Composite key: order_id + order_item_id

SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrences
FROM order_items
GROUP BY
    order_id,
    order_item_id
HAVING COUNT(*) > 1;

-- Result observed:
-- 0 duplicate composite keys.



-- Order Payments
-- Composite key: order_id + payment_sequential

SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS occurrences
FROM order_payments
GROUP BY
    order_id,
    payment_sequential
HAVING COUNT(*) > 1;

-- Result observed:
-- 0 duplicate composite keys.



-- Order Reviews
-- Composite key: review_id + order_id

SELECT
    review_id,
    order_id,
    COUNT(*) AS occurrences
FROM order_reviews
GROUP BY
    review_id,
    order_id
HAVING COUNT(*) > 1;

-- Result observed:
-- 0 duplicate composite keys.



-- ------------------------------------------------------------
-- 3.2.3 Geolocation exact duplicate records
-- ------------------------------------------------------------

-- The geolocation table does not have a primary key.
--
-- Multiple records for the same ZIP code prefix may exist, so
-- ZIP code prefix alone cannot be used to identify duplicates.
--
-- Exact duplicate analysis therefore considers all columns.

SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    COUNT(*) AS occurrences
FROM geolocation
GROUP BY
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;



-- Count duplicate rows beyond the first occurrence.

SELECT
    SUM(occurrences - 1) AS duplicate_rows
FROM (
    SELECT
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state,
        COUNT(*) AS occurrences
    FROM geolocation
    GROUP BY
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    HAVING COUNT(*) > 1
) AS duplicates;

-- Result observed:
-- Exact duplicate rows beyond the first occurrence: 261,831


-- Treatment decision:
-- No duplicate records were found in the 8 tables with defined
-- unique or composite keys.
--
-- Exact duplicate rows exist in geolocation, but no records are
-- deleted from the raw dataset.
--
-- If geolocation is used in geographic joins, an aggregated or
-- deduplicated analytical version should be created to prevent
-- row multiplication and distorted aggregations.



-- ============================================================
-- 3.3 NULL VALUES
-- ============================================================

-- Objective:
-- Evaluate data completeness by identifying null values across
-- all dataset tables and determine whether missing values require
-- further investigation or analytical treatment.



-- ------------------------------------------------------------
-- 3.3.1 Customers
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE customer_id IS NULL
    ) AS null_customer_id,

    COUNT(*) FILTER (
        WHERE customer_unique_id IS NULL
    ) AS null_customer_unique_id,

    COUNT(*) FILTER (
        WHERE customer_zip_code_prefix IS NULL
    ) AS null_zip_code,

    COUNT(*) FILTER (
        WHERE customer_city IS NULL
    ) AS null_city,

    COUNT(*) FILTER (
        WHERE customer_state IS NULL
    ) AS null_state

FROM customers;

-- Result observed:
-- No null values in the analyzed fields.



-- ------------------------------------------------------------
-- 3.3.2 Products
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE product_id IS NULL
    ) AS null_product_id,

    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
    ) AS null_category,

    COUNT(*) FILTER (
        WHERE product_name_lenght IS NULL
    ) AS null_name_length,

    COUNT(*) FILTER (
        WHERE product_description_lenght IS NULL
    ) AS null_description_length,

    COUNT(*) FILTER (
        WHERE product_photos_qty IS NULL
    ) AS null_photos_qty,

    COUNT(*) FILTER (
        WHERE product_weight_g IS NULL
    ) AS null_weight,

    COUNT(*) FILTER (
        WHERE product_length_cm IS NULL
    ) AS null_length,

    COUNT(*) FILTER (
        WHERE product_height_cm IS NULL
    ) AS null_height,

    COUNT(*) FILTER (
        WHERE product_width_cm IS NULL
    ) AS null_width

FROM products;

-- Results observed:
-- Total products: 32,951
--
-- product_id:                    0 null
-- product_category_name:       610 null
-- product_name_lenght:         610 null
-- product_description_lenght:  610 null
-- product_photos_qty:          610 null
-- product_weight_g:              2 null
-- product_length_cm:             2 null
-- product_height_cm:             2 null
-- product_width_cm:              2 null



-- ------------------------------------------------------------
-- 3.3.3 Sellers
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE seller_id IS NULL
    ) AS null_seller_id,

    COUNT(*) FILTER (
        WHERE seller_zip_code_prefix IS NULL
    ) AS null_zip_code,

    COUNT(*) FILTER (
        WHERE seller_city IS NULL
    ) AS null_city,

    COUNT(*) FILTER (
        WHERE seller_state IS NULL
    ) AS null_state

FROM sellers;

-- Result observed:
-- No null values in the analyzed fields.



-- ------------------------------------------------------------
-- 3.3.4 Order Items
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS null_order_id,

    COUNT(*) FILTER (
        WHERE order_item_id IS NULL
    ) AS null_order_item_id,

    COUNT(*) FILTER (
        WHERE product_id IS NULL
    ) AS null_product_id,

    COUNT(*) FILTER (
        WHERE seller_id IS NULL
    ) AS null_seller_id,

    COUNT(*) FILTER (
        WHERE shipping_limit_date IS NULL
    ) AS null_shipping_limit_date,

    COUNT(*) FILTER (
        WHERE price IS NULL
    ) AS null_price,

    COUNT(*) FILTER (
        WHERE freight_value IS NULL
    ) AS null_freight_value

FROM order_items;

-- Result observed:
-- No null values in the analyzed fields.



-- ------------------------------------------------------------
-- 3.3.5 Order Payments
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS null_order_id,

    COUNT(*) FILTER (
        WHERE payment_sequential IS NULL
    ) AS null_payment_sequential,

    COUNT(*) FILTER (
        WHERE payment_type IS NULL
    ) AS null_payment_type,

    COUNT(*) FILTER (
        WHERE payment_installments IS NULL
    ) AS null_payment_installments,

    COUNT(*) FILTER (
        WHERE payment_value IS NULL
    ) AS null_payment_value

FROM order_payments;

-- Result observed:
-- No null values in the analyzed fields.



-- ------------------------------------------------------------
-- 3.3.6 Order Reviews
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE review_id IS NULL
    ) AS null_review_id,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS null_order_id,

    COUNT(*) FILTER (
        WHERE review_score IS NULL
    ) AS null_review_score,

    COUNT(*) FILTER (
        WHERE review_comment_title IS NULL
    ) AS null_comment_title,

    COUNT(*) FILTER (
        WHERE review_comment_message IS NULL
    ) AS null_comment_message,

    COUNT(*) FILTER (
        WHERE review_creation_date IS NULL
    ) AS null_creation_date,

    COUNT(*) FILTER (
        WHERE review_answer_timestamp IS NULL
    ) AS null_answer_timestamp

FROM order_reviews;

-- Results observed:
-- Total reviews: 99,224
--
-- review_id:                    0 null
-- order_id:                     0 null
-- review_score:                 0 null
-- review_comment_title:    87,656 null
-- review_comment_message:  58,247 null
-- review_creation_date:         0 null
-- review_answer_timestamp:      0 null
--
-- Review title and comment fields are optional and do not
-- prevent the use of review_score in satisfaction analysis.



-- ------------------------------------------------------------
-- 3.3.7 Orders
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS null_order_id,

    COUNT(*) FILTER (
        WHERE customer_id IS NULL
    ) AS null_customer_id,

    COUNT(*) FILTER (
        WHERE order_status IS NULL
    ) AS null_order_status,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp IS NULL
    ) AS null_purchase_date,

    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS null_approved_date,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS null_carrier_date,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS null_delivery_date,

    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date IS NULL
    ) AS null_estimated_delivery_date

FROM orders;

-- Results observed:
-- Total orders: 99,441
--
-- order_id:                           0 null
-- customer_id:                        0 null
-- order_status:                       0 null
-- order_purchase_timestamp:           0 null
-- order_approved_at:                160 null
-- order_delivered_carrier_date:   1,783 null
-- order_delivered_customer_date:  2,965 null
-- order_estimated_delivery_date:      0 null



-- ------------------------------------------------------------
-- 3.3.8 Orders null values by status
-- ------------------------------------------------------------

-- Missing process timestamps must be interpreted together with
-- order_status because not every order reaches every lifecycle
-- stage.

SELECT
    order_status,
    COUNT(*) AS total_orders,

    COUNT(order_approved_at)
        AS approval_date_present,

    COUNT(order_delivered_carrier_date)
        AS carrier_date_present,

    COUNT(order_delivered_customer_date)
        AS delivery_date_present

FROM orders

GROUP BY order_status
ORDER BY total_orders DESC;

-- Results observed:
--
-- Status       Total    Approval   Carrier   Delivery
-- ----------------------------------------------------
-- delivered    96,478    96,464    96,476    96,470
-- shipped       1,107     1,107     1,107         0
-- canceled        625       484        75         6
-- unavailable     609       609         0         0
-- invoiced        314       314         0         0
-- processing      301       301         0         0
-- created           5         0         0         0
-- approved          2         2         0         0
--
-- Most missing lifecycle dates are consistent with the current
-- processing status of the order.
--
-- Detailed logical consistency between order status and dates
-- is evaluated separately in 03_data_quality.sql.



-- ------------------------------------------------------------
-- 3.3.9 Geolocation
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE geolocation_zip_code_prefix IS NULL
    ) AS null_zip_code,

    COUNT(*) FILTER (
        WHERE geolocation_lat IS NULL
    ) AS null_latitude,

    COUNT(*) FILTER (
        WHERE geolocation_lng IS NULL
    ) AS null_longitude,

    COUNT(*) FILTER (
        WHERE geolocation_city IS NULL
    ) AS null_city,

    COUNT(*) FILTER (
        WHERE geolocation_state IS NULL
    ) AS null_state

FROM geolocation;

-- Result observed:
-- No null values in the analyzed fields.



-- ------------------------------------------------------------
-- 3.3.10 Category Translation
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
    ) AS null_category,

    COUNT(*) FILTER (
        WHERE product_category_name_english IS NULL
    ) AS null_category_english

FROM category_translation;

-- Result observed:
-- No null values in the analyzed fields.


-- Treatment decision:
-- No records are removed because of null values at this stage.
--
-- Missing values are interpreted according to their business
-- context and will only be filtered when a specific KPI depends
-- on the affected field.
--
-- Product category nulls should be treated as unknown/not
-- informed when category-level analysis is performed.
--
-- Optional review comments remain unchanged.



-- ============================================================
-- 3.4 REFERENTIAL INTEGRITY
-- ============================================================

-- Objective:
-- Validate relationships between the main dataset tables by
-- identifying orphan records with no corresponding record in
-- the referenced table.
--
-- Note:
-- Foreign key constraints were not implemented in the original
-- analytical schema.
--
-- Referential integrity is therefore validated through SQL
-- checks between related tables.



-- ------------------------------------------------------------
-- 3.4.1 Orders -> Customers
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM orders o

LEFT JOIN customers c
    ON o.customer_id = c.customer_id

WHERE c.customer_id IS NULL;

-- Result observed:
-- 0 orphan records.



-- ------------------------------------------------------------
-- 3.4.2 Order Items -> Orders
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM order_items oi

LEFT JOIN orders o
    ON oi.order_id = o.order_id

WHERE o.order_id IS NULL;

-- Result observed:
-- 0 orphan records.



-- ------------------------------------------------------------
-- 3.4.3 Order Items -> Products
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM order_items oi

LEFT JOIN products p
    ON oi.product_id = p.product_id

WHERE p.product_id IS NULL;

-- Result observed:
-- 0 orphan records.



-- ------------------------------------------------------------
-- 3.4.4 Order Items -> Sellers
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM order_items oi

LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id

WHERE s.seller_id IS NULL;

-- Result observed:
-- 0 orphan records.



-- ------------------------------------------------------------
-- 3.4.5 Order Payments -> Orders
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM order_payments op

LEFT JOIN orders o
    ON op.order_id = o.order_id

WHERE o.order_id IS NULL;

-- Result observed:
-- 0 orphan records.



-- ------------------------------------------------------------
-- 3.4.6 Order Reviews -> Orders
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS orphan_records
FROM order_reviews r

LEFT JOIN orders o
    ON r.order_id = o.order_id

WHERE o.order_id IS NULL;

-- Result observed:
-- 0 orphan records.



-- ------------------------------------------------------------
-- 3.4.7 Products -> Category Translation
-- ------------------------------------------------------------

-- Null product categories are excluded because a missing
-- category is a completeness issue, not a referential integrity
-- failure.

SELECT
    COUNT(*) AS products_without_translation

FROM products p

LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name

WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;

-- Result observed:
-- 13 products without an English category translation.



-- Identify the affected categories.

SELECT
    p.product_category_name,
    COUNT(*) AS total_products

FROM products p

LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name

WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL

GROUP BY p.product_category_name
ORDER BY total_products DESC;

-- Results observed:
--
-- portateis_cozinha_e_preparadores_de_alimentos: 10 products
-- pc_gamer:                                      3 products
--
-- Total:
-- 13 products across 2 untranslated categories.


-- Treatment decision:
-- No orphan records were found in the main transactional
-- relationships.
--
-- The 13 products without an English category translation are
-- preserved because the issue affects only the translation
-- table, not the existence of the products themselves.
--
-- The original Portuguese category may be retained or manually
-- mapped only in the analytical layer if required.



-- ============================================================
-- FINAL DATA VALIDATION NOTES
-- ============================================================

-- Overall conclusions:
--
-- 1. All 9 expected tables were successfully loaded into
--    PostgreSQL, totaling more than 1.5 million records.
--
-- 2. No duplicate keys were found in the 8 tables with defined
--    unique or composite keys.
--
-- 3. Exact duplicate rows were identified in geolocation and
--    documented for possible analytical deduplication.
--
-- 4. Null values are concentrated mainly in optional product
--    and review attributes and in lifecycle dates whose presence
--    depends on order status.
--
-- 5. No orphan records were found in the main relationships
--    between customers, orders, items, products, sellers,
--    payments and reviews.
--
-- 6. Thirteen products across two categories do not have an
--    English translation in category_translation.
--
-- 7. No raw records are deleted during Data Validation.
--
-- 8. Identified issues are preserved and documented so that
--    treatment decisions can be applied only when required by
--    the analytical question or KPI.
--
-- ============================================================
-- END OF DATA VALIDATION SCRIPT
-- ============================================================
