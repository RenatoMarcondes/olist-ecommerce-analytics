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
-- primary keys, and composite primary keys.
-- ============================================================

-- ============================================================
-- 1. ORDERS
-- ============================================================
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
CREATE TABLE category_translation (
    product_category_name VARCHAR(100) NOT NULL,
    product_category_name_english VARCHAR(100),
    PRIMARY KEY (product_category_name)
);
