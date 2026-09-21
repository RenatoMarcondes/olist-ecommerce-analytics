-- ============================================================
-- OLIST E-COMMERCE ANALYTICS
-- Database Schema
-- ============================================================
-- Author: Renato Marcondes de Souza
-- Database: PostgreSQL
-- Project: Brazilian E-Commerce Analytics
--
-- Description:
-- Creates the 9 database tables used in the Olist Analytics
-- project, including data types, NOT NULL constraints,
-- primary keys and composite primary keys.
--
-- Notes:
-- - Foreign key constraints are intentionally not implemented
--   in this schema.
-- - Referential integrity is validated separately through SQL
--   checks in 02_data_validation.sql.
-- - The geolocation table has no primary key because ZIP code
--   prefixes are not unique and exact duplicate rows exist in
--   the source dataset.
-- - Original Olist column names are preserved, including the
--   source spelling "lenght" in product attribute columns.
-- ============================================================



-- ============================================================
-- 1. ORDERS
-- ============================================================
-- Stores one record per order, including its current status
-- and the main timestamps of the order lifecycle.

CREATE TABLE orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL
);



-- ============================================================
-- 2. ORDER ITEMS
-- ============================================================
-- Stores the individual items associated with each order.
--
-- Composite primary key:
-- order_id + order_item_id

CREATE TABLE order_items (
    order_id VARCHAR(32) NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10,2) NOT NULL,
    freight_value NUMERIC(10,2) NOT NULL,

    PRIMARY KEY (order_id, order_item_id)
);



-- ============================================================
-- 3. ORDER PAYMENTS
-- ============================================================
-- Stores payment records associated with each order.
--
-- An order may contain more than one payment record.
--
-- Composite primary key:
-- order_id + payment_sequential

CREATE TABLE order_payments (
    order_id VARCHAR(32) NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type VARCHAR(20) NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value NUMERIC(10,2) NOT NULL,

    PRIMARY KEY (order_id, payment_sequential)
);



-- ============================================================
-- 4. ORDER REVIEWS
-- ============================================================
-- Stores customer reviews associated with orders.
--
-- Review titles and messages are optional fields.
--
-- Composite primary key:
-- review_id + order_id

CREATE TABLE order_reviews (
    review_id VARCHAR(32) NOT NULL,
    order_id VARCHAR(32) NOT NULL,
    review_score INTEGER NOT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,

    PRIMARY KEY (review_id, order_id)
);



-- ============================================================
-- 5. CUSTOMERS
-- ============================================================
-- Stores customer identifiers and geographic information.
--
-- customer_id identifies the customer record associated with
-- an order, while customer_unique_id represents the same
-- customer across multiple purchases.

CREATE TABLE customers (
    customer_id VARCHAR(32) NOT NULL,
    customer_unique_id VARCHAR(32) NOT NULL,
    customer_zip_code_prefix INTEGER,
    customer_city VARCHAR(100),
    customer_state VARCHAR(2),

    PRIMARY KEY (customer_id)
);



-- ============================================================
-- 6. PRODUCTS
-- ============================================================
-- Stores product categories, descriptive attributes and
-- physical dimensions.
--
-- Note:
-- The original Olist dataset uses the spelling "lenght" in
-- product_name_lenght and product_description_lenght.
-- These column names are intentionally preserved.

CREATE TABLE products (
    product_id VARCHAR(32) NOT NULL,
    product_category_name VARCHAR(100),
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER,

    PRIMARY KEY (product_id)
);



-- ============================================================
-- 7. SELLERS
-- ============================================================
-- Stores seller identifiers and geographic information.

CREATE TABLE sellers (
    seller_id VARCHAR(32) NOT NULL,
    seller_zip_code_prefix INTEGER,
    seller_city VARCHAR(100),
    seller_state VARCHAR(2),

    PRIMARY KEY (seller_id)
);



-- ============================================================
-- 8. GEOLOCATION
-- ============================================================
-- Stores geographic coordinates associated with Brazilian ZIP
-- code prefixes.
--
-- No primary key is defined because geolocation_zip_code_prefix
-- is not unique and the source dataset contains multiple records
-- for the same geographic area, including exact duplicate rows.
--
-- A deduplicated or aggregated analytical version may be created
-- later when geographic relationships are required.

CREATE TABLE geolocation (
    geolocation_zip_code_prefix INTEGER NOT NULL,
    geolocation_lat NUMERIC(10,7),
    geolocation_lng NUMERIC(10,7),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(2)
);



-- ============================================================
-- 9. CATEGORY TRANSLATION
-- ============================================================
-- Maps the original Portuguese product category names to their
-- English translations.

CREATE TABLE category_translation (
    product_category_name VARCHAR(100) NOT NULL,
    product_category_name_english VARCHAR(100),

    PRIMARY KEY (product_category_name)
);



-- ============================================================
-- SCHEMA NOTES
-- ============================================================

-- 1. Nine tables are created in this script.
--
-- 2. Primary keys are defined for all tables except geolocation.
--
-- 3. Composite primary keys are used in:
--      - order_items
--      - order_payments
--      - order_reviews
--
-- 4. Foreign key constraints are not enforced at database level.
--    Relationships are validated through SQL in:
--      sql/02_data_validation.sql
--
-- 5. Data quality and business consistency checks are performed
--    separately in:
--      sql/03_data_quality.sql
--
-- 6. No transformation or cleaning is performed in this script.
--    Its only purpose is to reproduce the relational structure
--    used to import and analyze the Olist dataset.
--
-- ============================================================
-- END OF DATABASE SCHEMA
-- ============================================================
