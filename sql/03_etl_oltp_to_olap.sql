-- ETL: loads the ecommerce_olap data warehouse from the ecommerce_oltp source database
-- Run order: 01_oltp -> 02_olap -> this script

USE ecommerce_olap;

-- 1. Independent dimensions (no foreign keys)
INSERT INTO dim_categories (id, category_name)
SELECT id, category_name
FROM ecommerce_oltp.categories;

INSERT INTO dim_locations (id, city, country)
SELECT id, city, country
FROM ecommerce_oltp.locations;

-- 2. Dependent dimensions (reference the ones above)
INSERT INTO dim_customers (id, first_name, last_name, email, dim_locations_id)
SELECT id, first_name, last_name, email, locations_id
FROM ecommerce_oltp.customers;

INSERT INTO dim_products (id, product_name, price, dim_categories_id)
SELECT id, product_name, price, categories_id
FROM ecommerce_oltp.products;

-- 3. Date dimension (derived from order dates)
INSERT INTO dim_date (date_key, full_date, day, month, quarter, year)
SELECT DISTINCT
    CAST(DATE_FORMAT(order_date, '%Y%m%d') AS SIGNED),
    DATE(order_date),
    DAY(order_date),
    MONTH(order_date),
    QUARTER(order_date),
    YEAR(order_date)
FROM ecommerce_oltp.orders;

-- 4. Fact table (joins order_items, orders, products, customers)
INSERT INTO fact_sales
    (quantity, total_price, dim_products_id, dim_customers_id, dim_date_id, dim_locations_id)
SELECT
    oi.quantity,
    oi.quantity * p.price,
    oi.products_id,
    o.customers_id,
    CAST(DATE_FORMAT(o.order_date, '%Y%m%d') AS SIGNED),
    c.locations_id
FROM ecommerce_oltp.order_items oi
JOIN ecommerce_oltp.orders o    ON oi.orders_id = o.id
JOIN ecommerce_oltp.products p  ON oi.products_id = p.id
JOIN ecommerce_oltp.customers c ON o.customers_id = c.id;

-- Check: expected 7100.00
SELECT SUM(total_price) AS total_revenue FROM fact_sales;
