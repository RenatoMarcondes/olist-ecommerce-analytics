-- ============================================================
-- OLIST E-COMMERCE ANALYTICS
-- Data Validation
-- ============================================================
-- Author: Renato Marcondes de Souza
-- Database: PostgreSQL
-- Project: Brazilian E-Commerce Analytics
--
-- Description:
-- Performs the initial validation of the Olist dataset after
-- data import, following Sections 3.1 to 3.4 of the project
-- documentation.
--
-- Validation scope:
-- 3.1 Data Load and Volume
-- 3.2 Duplicate Records
-- 3.3 Null Values
-- 3.4 Referential Integrity
-- ============================================================

-- ============================================================
-- 3.1 DATA LOAD AND VOLUME VALIDATION
-- ============================================================
-- Objective:
-- Validate the successful import of all 9 dataset tables
-- by checking the total number of records in each table.

SELECT 'orders' AS table_name, COUNT(*) AS total_records FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'category_translation', COUNT(*) FROM category_translation;

-- ============================================================
-- 3.2 DUPLICATE RECORDS ANALYSIS
-- ============================================================
-- Objective:
-- Identify duplicate records based on primary or composite keys
-- and detect exact duplicate rows in tables without a unique key.

-- ------------------------------------------------------------
-- 3.2.1 Tables with single-column keys
-- ------------------------------------------------------------
-- Orders
SELECT
    order_id,
    COUNT(*) AS occurrences
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Customers
SELECT
    customer_id,
    COUNT(*) AS occurrences
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Products
SELECT
    product_id,
    COUNT(*) AS occurrences
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Sellers
SELECT
    seller_id,
    COUNT(*) AS occurrences
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- Category Translation
SELECT
    product_category_name,
    COUNT(*) AS occurrences
FROM category_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;

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

-- ------------------------------------------------------------
-- 3.2.3 Geolocation exact duplicate records
-- ------------------------------------------------------------
-- The geolocation table does not have a primary key.
-- Multiple records for the same ZIP code prefix are expected,
-- so duplicate analysis must consider all columns.
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

-- Count duplicate rows beyond the first occurrence
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

-- ============================================================
-- 3.3 NULL VALUES ANALYSIS
-- ============================================================
-- Objective:
-- Evaluate data completeness by identifying null values across
-- the dataset and determine whether missing values require
-- further investigation or treatment.

-- ------------------------------------------------------------
-- 3.3.1 Customers
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS null_customer_unique_id,
    COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) AS null_zip_code,
    COUNT(*) FILTER (WHERE customer_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS null_state
FROM customers;


-- ------------------------------------------------------------
-- 3.3.2 Products
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS null_category,
    COUNT(*) FILTER (WHERE product_name_lenght IS NULL) AS null_name_length,
    COUNT(*) FILTER (WHERE product_description_lenght IS NULL) AS null_description_length,
    COUNT(*) FILTER (WHERE product_photos_qty IS NULL) AS null_photos_qty,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS null_weight,
    COUNT(*) FILTER (WHERE product_length_cm IS NULL) AS null_length,
    COUNT(*) FILTER (WHERE product_height_cm IS NULL) AS null_height,
    COUNT(*) FILTER (WHERE product_width_cm IS NULL) AS null_width
FROM products;


-- ------------------------------------------------------------
-- 3.3.3 Sellers
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS null_seller_id,
    COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL) AS null_zip_code,
    COUNT(*) FILTER (WHERE seller_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE seller_state IS NULL) AS null_state
FROM sellers;

-- ------------------------------------------------------------
-- 3.3.4 Order Items
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE order_item_id IS NULL) AS null_order_item_id,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS null_seller_id,
    COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) AS null_shipping_limit_date,
    COUNT(*) FILTER (WHERE price IS NULL) AS null_price,
    COUNT(*) FILTER (WHERE freight_value IS NULL) AS null_freight_value
FROM order_items;


-- ------------------------------------------------------------
-- 3.3.5 Order Payments
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE payment_sequential IS NULL) AS null_payment_sequential,
    COUNT(*) FILTER (WHERE payment_type IS NULL) AS null_payment_type,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS null_payment_installments,
    COUNT(*) FILTER (WHERE payment_value IS NULL) AS null_payment_value
FROM order_payments;


-- ------------------------------------------------------------
-- 3.3.6 Order Reviews
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE review_id IS NULL) AS null_review_id,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE review_score IS NULL) AS null_review_score,
    COUNT(*) FILTER (WHERE review_comment_title IS NULL) AS null_comment_title,
    COUNT(*) FILTER (WHERE review_comment_message IS NULL) AS null_comment_message,
    COUNT(*) FILTER (WHERE review_creation_date IS NULL) AS null_creation_date,
    COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL) AS null_answer_timestamp
FROM order_reviews;


-- ------------------------------------------------------------
-- 3.3.7 Orders
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS null_order_status,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS null_purchase_date,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS null_approved_date,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS null_carrier_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS null_delivery_date,
    COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS null_estimated_delivery_date
FROM orders;


-- ------------------------------------------------------------
-- 3.3.8 Geolocation
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL) AS null_zip_code,
    COUNT(*) FILTER (WHERE geolocation_lat IS NULL) AS null_latitude,
    COUNT(*) FILTER (WHERE geolocation_lng IS NULL) AS null_longitude,
    COUNT(*) FILTER (WHERE geolocation_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE geolocation_state IS NULL) AS null_state
FROM geolocation;


-- ------------------------------------------------------------
-- 3.3.9 Category Translation
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS null_category,
    COUNT(*) FILTER (WHERE product_category_name_english IS NULL) AS null_category_english
FROM category_translation;

-- ============================================================
-- 3.4 REFERENTIAL INTEGRITY
-- ============================================================
-- Objective:
-- Validate the relationships between the main dataset tables
-- by identifying orphan records with no corresponding record
-- in the referenced table.

-- Note:
-- Foreign key constraints were not implemented in the original
-- schema. Referential integrity is therefore validated through
-- SQL checks between related tables.

-- ------------------------------------------------------------
-- 3.4.1 Orders -> Customers
-- ------------------------------------------------------------
SELECT COUNT(*) AS orphan_records
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- ------------------------------------------------------------
-- 3.4.2 Order Items -> Orders
-- ------------------------------------------------------------
SELECT COUNT(*) AS orphan_records
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- ------------------------------------------------------------
-- 3.4.3 Order Items -> Products
-- ------------------------------------------------------------
SELECT COUNT(*) AS orphan_records
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- ------------------------------------------------------------
-- 3.4.4 Order Items -> Sellers
-- ------------------------------------------------------------
SELECT COUNT(*) AS orphan_records
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- ------------------------------------------------------------
-- 3.4.5 Order Payments -> Orders
-- ------------------------------------------------------------
SELECT COUNT(*) AS orphan_records
FROM order_payments op
LEFT JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;

-- ------------------------------------------------------------
-- 3.4.6 Order Reviews -> Orders
-- ------------------------------------------------------------
SELECT COUNT(*) AS orphan_records
FROM order_reviews r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- ------------------------------------------------------------
-- 3.4.7 Products -> Category Translation
-- ------------------------------------------------------------
SELECT COUNT(*) AS products_without_translation
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;

-- Identify categories without English translation
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
