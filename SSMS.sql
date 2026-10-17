-- ============================================
-- IT3101 DWBI Project — Database Creation
-- Dataset: Olist Brazilian E-Commerce
-- ============================================

CREATE DATABASE DWBI_Project;
GO

USE DWBI_Project;
GO

-- Schemas to separate the three pipeline layers
CREATE SCHEMA staging;  -- raw CSV loads, no transformation
GO
CREATE SCHEMA ods;      -- cleaned, deduplicated, typed
GO
CREATE SCHEMA mart;     -- final star-schema dims & facts
GO



-- ============================================
-- Staging Layer
-- Dataset: Olist Brazilian E-Commerce (Kaggle)
-- Step 1: CREATE TABLE statements
-- Step 2: BULK INSERT statements
-- ============================================

USE DWBI_Project;
GO

-- ============================================
-- STEP 1: CREATE TABLES
-- ============================================

CREATE TABLE staging.customers (
    customer_id                VARCHAR(50),
    customer_unique_id         VARCHAR(50),
    customer_zip_code_prefix   VARCHAR(10),
    customer_city              VARCHAR(100),
    customer_state             VARCHAR(5)
);
GO

CREATE TABLE staging.orders (
    order_id                       VARCHAR(50),
    customer_id                    VARCHAR(50),
    order_status                   VARCHAR(30),
    order_purchase_timestamp       DATETIME,
    order_approved_at              DATETIME NULL,
    order_delivered_carrier_date   DATETIME NULL,
    order_delivered_customer_date  DATETIME NULL,
    order_estimated_delivery_date  DATETIME NULL
);
GO

CREATE TABLE staging.order_items (
    order_id            VARCHAR(50),
    order_item_id       INT,
    product_id          VARCHAR(50),
    seller_id           VARCHAR(50),
    shipping_limit_date DATETIME,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2)
);
GO

CREATE TABLE staging.order_payments (
    order_id             VARCHAR(50),
    payment_sequential   INT,
    payment_type         VARCHAR(30),
    payment_installments INT,
    payment_value        DECIMAL(10,2)
);
GO

CREATE TABLE staging.order_reviews (
    review_id               VARCHAR(50),
    order_id                VARCHAR(50),
    review_score            INT,
    review_comment_title    NVARCHAR(200) NULL,
    review_comment_message  NVARCHAR(MAX) NULL,
    review_creation_date    DATETIME,
    review_answer_timestamp DATETIME
);
GO

CREATE TABLE staging.products (
    product_id                  VARCHAR(50),
    product_category_name       VARCHAR(100) NULL,
    product_name_lenght         INT NULL,
    product_description_lenght  INT NULL,
    product_photos_qty          INT NULL,
    product_weight_g            INT NULL,
    product_length_cm           INT NULL,
    product_height_cm           INT NULL,
    product_width_cm            INT NULL
);
GO

CREATE TABLE staging.sellers (
    seller_id                VARCHAR(50),
    seller_zip_code_prefix   VARCHAR(10),
    seller_city              VARCHAR(100),
    seller_state             VARCHAR(5)
);
GO

CREATE TABLE staging.geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat              DECIMAL(10,6),
    geolocation_lng              DECIMAL(10,6),
    geolocation_city             VARCHAR(100),
    geolocation_state            VARCHAR(5)
);
GO

CREATE TABLE staging.category_translation (
    product_category_name          VARCHAR(100),
    product_category_name_english  VARCHAR(100)
);
GO

-- ============================================
-- STEP 2: BULK INSERT (adjust file paths to where
-- your CSVs live on the machine running SSMS)
-- ============================================

USE DWBI_Project;
GO

BULK INSERT staging.customers
FROM 'C:\Users\chris\OneDrive - Sri Lanka Institute of Information Technology\Uni\Y3S1\BI\Assignment\archive\olist_customers_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK,
    CODEPAGE = '65001'
);
GO

BULK INSERT staging.orders
FROM 'C:\Users\chris\OneDrive - Sri Lanka Institute of Information Technology\Uni\Y3S1\BI\Assignment\archive\olist_orders_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK,
    CODEPAGE = '65001'
);
GO

BULK INSERT staging.order_items
FROM 'C:\Users\chris\OneDrive - Sri Lanka Institute of Information Technology\Uni\Y3S1\BI\Assignment\archive\olist_order_items_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK,
    CODEPAGE = '65001'
);
GO

BULK INSERT staging.order_payments
FROM 'C:\Users\chris\OneDrive - Sri Lanka Institute of Information Technology\Uni\Y3S1\BI\Assignment\archive\olist_order_payments_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK,
    CODEPAGE = '65001'
);
GO

BULK INSERT staging.products
FROM 'C:\Users\chris\OneDrive - Sri Lanka Institute of Information Technology\Uni\Y3S1\BI\Assignment\archive\olist_products_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK,
    CODEPAGE = '65001'
);
GO

BULK INSERT staging.sellers
FROM 'C:\Users\chris\OneDrive - Sri Lanka Institute of Information Technology\Uni\Y3S1\BI\Assignment\archive\olist_sellers_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK,
    CODEPAGE = '65001'
);
GO

BULK INSERT staging.geolocation
FROM 'C:\Users\chris\OneDrive - Sri Lanka Institute of Information Technology\Uni\Y3S1\BI\Assignment\archive\olist_geolocation_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK,
    CODEPAGE = '65001'
);
GO

BULK INSERT staging.category_translation
FROM 'C:\Users\chris\OneDrive - Sri Lanka Institute of Information Technology\Uni\Y3S1\BI\Assignment\archive\product_category_name_translation.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK,
    CODEPAGE = '65001'
);
GO

INSERT INTO staging.order_reviews
SELECT * FROM staging.order_reviews_temp;

DROP TABLE staging.order_reviews_temp;





-- ============================================
-- IT3101 DWBI Project — ODS Layer
-- Cleaned, deduplicated, standardized tables
-- ============================================

USE DWBI_Project;
GO

-- ============================================
-- ods.customers
-- ============================================
CREATE TABLE ods.customers (
    customer_id               VARCHAR(50) PRIMARY KEY,
    customer_unique_id        VARCHAR(50),
    customer_zip_code_prefix  VARCHAR(10),
    customer_city             VARCHAR(100),
    customer_state            CHAR(2)
);
GO

INSERT INTO ods.customers
SELECT DISTINCT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    LTRIM(RTRIM(customer_city)),
    UPPER(LTRIM(RTRIM(customer_state)))
FROM staging.customers
WHERE customer_id IS NOT NULL;
GO

-- ============================================
-- ods.sellers
-- ============================================
CREATE TABLE ods.sellers (
    seller_id               VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix  VARCHAR(10),
    seller_city             VARCHAR(100),
    seller_state            CHAR(2)
);
GO

INSERT INTO ods.sellers
SELECT DISTINCT
    seller_id,
    seller_zip_code_prefix,
    LTRIM(RTRIM(seller_city)),
    UPPER(LTRIM(RTRIM(seller_state)))
FROM staging.sellers
WHERE seller_id IS NOT NULL;
GO

-- ============================================
-- ods.category_translation
-- ============================================
CREATE TABLE ods.category_translation (
    product_category_name         VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);
GO

INSERT INTO ods.category_translation
SELECT DISTINCT product_category_name, product_category_name_english
FROM staging.category_translation
WHERE product_category_name IS NOT NULL;
GO

-- ============================================
-- ods.products (joined to English category name)
-- ============================================
CREATE TABLE ods.products (
    product_id                  VARCHAR(50) PRIMARY KEY,
    product_category_name       VARCHAR(100),
    product_category_name_english VARCHAR(100),
    product_weight_g            INT,
    product_length_cm           INT,
    product_height_cm           INT,
    product_width_cm            INT
);
GO

INSERT INTO ods.products
SELECT
    p.product_id,
    p.product_category_name,
    ISNULL(t.product_category_name_english, 'unknown'),
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) rn
    FROM staging.products
    WHERE product_id IS NOT NULL
) p
LEFT JOIN ods.category_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.rn = 1;
GO

-- ============================================
-- ods.orders
-- ============================================
CREATE TABLE ods.orders (
    order_id                       VARCHAR(50) PRIMARY KEY,
    customer_id                    VARCHAR(50),
    order_status                   VARCHAR(30),
    order_purchase_timestamp       DATETIME,
    order_approved_at              DATETIME NULL,
    order_delivered_carrier_date   DATETIME NULL,
    order_delivered_customer_date  DATETIME NULL,
    order_estimated_delivery_date  DATETIME NULL
);
GO

INSERT INTO ods.orders
SELECT
    order_id, customer_id, LOWER(LTRIM(RTRIM(order_status))),
    order_purchase_timestamp, order_approved_at,
    order_delivered_carrier_date, order_delivered_customer_date,
    order_estimated_delivery_date
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_purchase_timestamp) rn
    FROM staging.orders
    WHERE order_id IS NOT NULL
) o
WHERE rn = 1;
GO

-- ============================================
-- ods.order_items
-- ============================================
CREATE TABLE ods.order_items (
    order_id            VARCHAR(50),
    order_item_id       INT,
    product_id          VARCHAR(50),
    seller_id           VARCHAR(50),
    shipping_limit_date DATETIME,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);
GO

INSERT INTO ods.order_items
SELECT DISTINCT order_id, order_item_id, product_id, seller_id,
       shipping_limit_date, price, freight_value
FROM staging.order_items
WHERE order_id IS NOT NULL AND price >= 0 AND freight_value >= 0;
GO

-- ============================================
-- ods.order_payments
-- ============================================
CREATE TABLE ods.order_payments (
    order_id             VARCHAR(50),
    payment_sequential   INT,
    payment_type         VARCHAR(30),
    payment_installments INT,
    payment_value        DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);
GO

INSERT INTO ods.order_payments
SELECT DISTINCT order_id, payment_sequential, LOWER(LTRIM(RTRIM(payment_type))),
       payment_installments, payment_value
FROM staging.order_payments
WHERE order_id IS NOT NULL AND payment_value >= 0;
GO

-- ============================================
-- ods.order_reviews
-- ============================================
CREATE TABLE ods.order_reviews (
    review_id               VARCHAR(50) PRIMARY KEY,
    order_id                VARCHAR(50),
    review_score            INT,
    review_comment_title    NVARCHAR(200) NULL,
    review_comment_message  NVARCHAR(MAX) NULL,
    review_creation_date    DATETIME,
    review_answer_timestamp DATETIME
);
GO

INSERT INTO ods.order_reviews
SELECT review_id, order_id, review_score, review_comment_title,
       review_comment_message,
       TRY_CONVERT(datetime, review_creation_date),
       TRY_CONVERT(datetime, review_answer_timestamp)
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY review_id ORDER BY review_creation_date) rn
    FROM staging.order_reviews
    WHERE review_id IS NOT NULL AND review_score BETWEEN 1 AND 5
) r
WHERE rn = 1;
GO

-- ============================================
-- ods.geolocation (averaged per zip prefix — raw has many
-- duplicate/near-duplicate lat/lng rows per zip)
-- ============================================
CREATE TABLE ods.geolocation (
    geolocation_zip_code_prefix VARCHAR(10) PRIMARY KEY,
    geolocation_lat             DECIMAL(10,6),
    geolocation_lng             DECIMAL(10,6),
    geolocation_city            VARCHAR(100),
    geolocation_state           CHAR(2)
);
GO

INSERT INTO ods.geolocation
SELECT
    geolocation_zip_code_prefix,
    AVG(geolocation_lat),
    AVG(geolocation_lng),
    MAX(geolocation_city),
    UPPER(MAX(geolocation_state))
FROM staging.geolocation
WHERE geolocation_zip_code_prefix IS NOT NULL
GROUP BY geolocation_zip_code_prefix;
GO



-- ============================================
-- IT3101 DWBI Project — Mart Layer (Star Schema)
-- Dims: Date, Customer, Seller, Product, Geography
-- Facts: Fact_Sales, Fact_Delivery, Fact_Satisfaction
-- ============================================

USE DWBI_Project;
GO

-- ============================================
-- Dim_Date
-- ============================================
CREATE TABLE mart.Dim_Date (
    date_key      INT PRIMARY KEY,   -- yyyymmdd
    full_date     DATE,
    day           INT,
    month         INT,
    month_name    VARCHAR(15),
    quarter       INT,
    year          INT,
    day_of_week   VARCHAR(15)
);
GO

DECLARE @start DATE = '2016-01-01', @end DATE = '2018-12-31';
WITH dates AS (
    SELECT @start AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d) FROM dates WHERE d < @end
)
INSERT INTO mart.Dim_Date
SELECT
    CAST(FORMAT(d, 'yyyyMMdd') AS INT),
    d,
    DAY(d),
    MONTH(d),
    DATENAME(MONTH, d),
    DATEPART(QUARTER, d),
    YEAR(d),
    DATENAME(WEEKDAY, d)
FROM dates
OPTION (MAXRECURSION 1500);
GO

-- ============================================
-- Dim_Geography (one row per zip prefix)
-- ============================================
CREATE TABLE mart.Dim_Geography (
    geography_key INT IDENTITY(1,1) PRIMARY KEY,
    zip_code_prefix VARCHAR(10),
    city            VARCHAR(100),
    state           CHAR(2),
    latitude        DECIMAL(10,6),
    longitude       DECIMAL(10,6)
);
GO

INSERT INTO mart.Dim_Geography (zip_code_prefix, city, state, latitude, longitude)
SELECT geolocation_zip_code_prefix, geolocation_city, geolocation_state,
       geolocation_lat, geolocation_lng
FROM ods.geolocation;
GO

-- ============================================
-- Dim_Customer
-- ============================================
CREATE TABLE mart.Dim_Customer (
    customer_key   INT IDENTITY(1,1) PRIMARY KEY,
    customer_id    VARCHAR(50),
    customer_unique_id VARCHAR(50),
    city           VARCHAR(100),
    state          CHAR(2),
    zip_code_prefix VARCHAR(10)
);
GO

INSERT INTO mart.Dim_Customer (customer_id, customer_unique_id, city, state, zip_code_prefix)
SELECT customer_id, customer_unique_id, customer_city, customer_state, customer_zip_code_prefix
FROM ods.customers;
GO

-- ============================================
-- Dim_Seller
-- ============================================
CREATE TABLE mart.Dim_Seller (
    seller_key     INT IDENTITY(1,1) PRIMARY KEY,
    seller_id      VARCHAR(50),
    city           VARCHAR(100),
    state          CHAR(2),
    zip_code_prefix VARCHAR(10)
);
GO

INSERT INTO mart.Dim_Seller (seller_id, city, state, zip_code_prefix)
SELECT seller_id, seller_city, seller_state, seller_zip_code_prefix
FROM ods.sellers;
GO

-- ============================================
-- Dim_Product
-- ============================================
CREATE TABLE mart.Dim_Product (
    product_key    INT IDENTITY(1,1) PRIMARY KEY,
    product_id     VARCHAR(50),
    category_name  VARCHAR(100),
    category_name_english VARCHAR(100),
    weight_g       INT,
    length_cm      INT,
    height_cm      INT,
    width_cm       INT
);
GO

INSERT INTO mart.Dim_Product (product_id, category_name, category_name_english, weight_g, length_cm, height_cm, width_cm)
SELECT product_id, product_category_name, product_category_name_english,
       product_weight_g, product_length_cm, product_height_cm, product_width_cm
FROM ods.products;
GO

-- ============================================
-- Fact_Sales  (grain: order item)
-- ============================================
CREATE TABLE mart.Fact_Sales (
    sales_key      INT IDENTITY(1,1) PRIMARY KEY,
    order_id       VARCHAR(50),
    order_item_id  INT,
    date_key       INT,
    customer_key   INT,
    seller_key     INT,
    product_key    INT,
    price          DECIMAL(10,2),
    freight_value  DECIMAL(10,2),
    order_status   VARCHAR(30)
);
GO

INSERT INTO mart.Fact_Sales (order_id, order_item_id, date_key, customer_key, seller_key, product_key, price, freight_value, order_status)
SELECT
    oi.order_id, oi.order_item_id,
    CAST(FORMAT(o.order_purchase_timestamp, 'yyyyMMdd') AS INT),
    dc.customer_key, ds.seller_key, dp.product_key,
    oi.price, oi.freight_value, o.order_status
FROM ods.order_items oi
JOIN ods.orders o        ON oi.order_id = o.order_id
JOIN mart.Dim_Customer dc ON o.customer_id = dc.customer_id
JOIN mart.Dim_Seller ds   ON oi.seller_id = ds.seller_id
JOIN mart.Dim_Product dp  ON oi.product_id = dp.product_id;
GO

-- ============================================
-- Fact_Delivery  (grain: order)
-- ============================================
CREATE TABLE mart.Fact_Delivery (
    delivery_key   INT IDENTITY(1,1) PRIMARY KEY,
    order_id       VARCHAR(50),
    date_key       INT,          -- purchase date
    customer_key   INT,
    delivery_days  INT,          -- purchase -> delivered
    estimate_days  INT,          -- purchase -> estimated
    delay_days     INT,          -- delivered - estimated (positive = late)
    is_delayed     BIT
);
GO

INSERT INTO mart.Fact_Delivery (order_id, date_key, customer_key, delivery_days, estimate_days, delay_days, is_delayed)
SELECT
    o.order_id,
    CAST(FORMAT(o.order_purchase_timestamp, 'yyyyMMdd') AS INT),
    dc.customer_key,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date),
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_estimated_delivery_date),
    DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date),
    CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END
FROM ods.orders o
JOIN mart.Dim_Customer dc ON o.customer_id = dc.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL;
GO

-- ============================================
-- Fact_Satisfaction  (grain: order/review)
-- ============================================
CREATE TABLE mart.Fact_Satisfaction (
    satisfaction_key INT IDENTITY(1,1) PRIMARY KEY,
    order_id         VARCHAR(50),
    date_key         INT,          -- review creation date
    customer_key     INT,
    review_score     INT,
    response_days    INT           -- creation -> answer
);
GO

INSERT INTO mart.Fact_Satisfaction (order_id, date_key, customer_key, review_score, response_days)
SELECT
    r.order_id,
    CAST(FORMAT(r.review_creation_date, 'yyyyMMdd') AS INT),
    dc.customer_key,
    r.review_score,
    DATEDIFF(DAY, r.review_creation_date, r.review_answer_timestamp)
FROM ods.order_reviews r
JOIN ods.orders o        ON r.order_id = o.order_id
JOIN mart.Dim_Customer dc ON o.customer_id = dc.customer_id
WHERE r.review_creation_date IS NOT NULL;
GO



-- ============================================
-- IT3101 DWBI Project — Mart Layer Validation
-- Run each section; every query should return 0 rows
-- (except the summary counts at the top)
-- ============================================

USE DWBI_Project;
GO

-- ============================================
-- 1. Row counts (sanity check vs expected ranges)
-- ============================================
SELECT 'Dim_Date' AS TableName, COUNT(*) AS RowCnt FROM mart.Dim_Date
UNION ALL SELECT 'Dim_Customer', COUNT(*) FROM mart.Dim_Customer
UNION ALL SELECT 'Dim_Seller', COUNT(*) FROM mart.Dim_Seller
UNION ALL SELECT 'Dim_Product', COUNT(*) FROM mart.Dim_Product
UNION ALL SELECT 'Dim_Geography', COUNT(*) FROM mart.Dim_Geography
UNION ALL SELECT 'Fact_Sales', COUNT(*) FROM mart.Fact_Sales
UNION ALL SELECT 'Fact_Delivery', COUNT(*) FROM mart.Fact_Delivery
UNION ALL SELECT 'Fact_Satisfaction', COUNT(*) FROM mart.Fact_Satisfaction;
GO

-- ============================================
-- 2. Orphan check: Fact_Sales keys that don't match a dim
-- (should return 0 rows each)
-- ============================================
SELECT * FROM mart.Fact_Sales f
LEFT JOIN mart.Dim_Customer d ON f.customer_key = d.customer_key
WHERE d.customer_key IS NULL;

SELECT * FROM mart.Fact_Sales f
LEFT JOIN mart.Dim_Seller d ON f.seller_key = d.seller_key
WHERE d.seller_key IS NULL;

SELECT * FROM mart.Fact_Sales f
LEFT JOIN mart.Dim_Product d ON f.product_key = d.product_key
WHERE d.product_key IS NULL;

SELECT * FROM mart.Fact_Sales f
LEFT JOIN mart.Dim_Date d ON f.date_key = d.date_key
WHERE d.date_key IS NULL;
GO

-- ============================================
-- 3. Orphan check: Fact_Delivery / Fact_Satisfaction
-- ============================================
SELECT * FROM mart.Fact_Delivery f
LEFT JOIN mart.Dim_Customer d ON f.customer_key = d.customer_key
WHERE d.customer_key IS NULL;

SELECT * FROM mart.Fact_Delivery f
LEFT JOIN mart.Dim_Date d ON f.date_key = d.date_key
WHERE d.date_key IS NULL;

SELECT * FROM mart.Fact_Satisfaction f
LEFT JOIN mart.Dim_Customer d ON f.customer_key = d.customer_key
WHERE d.customer_key IS NULL;

SELECT * FROM mart.Fact_Satisfaction f
LEFT JOIN mart.Dim_Date d ON f.date_key = d.date_key
WHERE d.date_key IS NULL;
GO

-- ============================================
-- 4. Duplicate key checks in dimensions (should be 0 rows)
-- ============================================
SELECT customer_id, COUNT(*) FROM mart.Dim_Customer GROUP BY customer_id HAVING COUNT(*) > 1;
SELECT seller_id, COUNT(*) FROM mart.Dim_Seller GROUP BY seller_id HAVING COUNT(*) > 1;
SELECT product_id, COUNT(*) FROM mart.Dim_Product GROUP BY product_id HAVING COUNT(*) > 1;
GO

-- ============================================
-- 5. Value sanity checks (should be 0 rows)
-- ============================================
-- Negative price/freight in Fact_Sales
SELECT * FROM mart.Fact_Sales WHERE price < 0 OR freight_value < 0;

-- Review score out of 1-5 range
SELECT * FROM mart.Fact_Satisfaction WHERE review_score NOT BETWEEN 1 AND 5;

-- Delivery/estimate days wildly out of range (e.g. negative or over a year)
SELECT * FROM mart.Fact_Delivery WHERE delivery_days < 0 OR delivery_days > 365;
GO

-- ============================================
-- 6. Date range check (confirms Dim_Date covers all fact dates)
-- ============================================
SELECT MIN(date_key) AS MinDateKey, MAX(date_key) AS MaxDateKey FROM mart.Fact_Sales;
SELECT MIN(full_date) AS MinDate, MAX(full_date) AS MaxDate FROM mart.Dim_Date;
GO




-- ============================================
-- IT3101 DWBI Project — Mart Layer Foreign Keys
-- Links Fact tables to their Dimension tables
-- so relationships show up in DB diagrams and
-- referential integrity is enforced going forward
-- ============================================

USE DWBI_Project;
GO

-- ============================================
-- Fact_Sales -> Dim_Customer / Dim_Seller / Dim_Product / Dim_Date
-- ============================================
ALTER TABLE mart.Fact_Sales ADD CONSTRAINT FK_Sales_Customer FOREIGN KEY (customer_key) REFERENCES mart.Dim_Customer(customer_key);
ALTER TABLE mart.Fact_Sales ADD CONSTRAINT FK_Sales_Seller   FOREIGN KEY (seller_key)   REFERENCES mart.Dim_Seller(seller_key);
ALTER TABLE mart.Fact_Sales ADD CONSTRAINT FK_Sales_Product  FOREIGN KEY (product_key)  REFERENCES mart.Dim_Product(product_key);
ALTER TABLE mart.Fact_Sales ADD CONSTRAINT FK_Sales_Date     FOREIGN KEY (date_key)     REFERENCES mart.Dim_Date(date_key);
GO

-- ============================================
-- Fact_Delivery -> Dim_Customer / Dim_Date
-- ============================================
ALTER TABLE mart.Fact_Delivery ADD CONSTRAINT FK_Delivery_Customer FOREIGN KEY (customer_key) REFERENCES mart.Dim_Customer(customer_key);
ALTER TABLE mart.Fact_Delivery ADD CONSTRAINT FK_Delivery_Date     FOREIGN KEY (date_key)     REFERENCES mart.Dim_Date(date_key);
GO

-- ============================================
-- Fact_Satisfaction -> Dim_Customer / Dim_Date
-- ============================================
ALTER TABLE mart.Fact_Satisfaction ADD CONSTRAINT FK_Satisfaction_Customer FOREIGN KEY (customer_key) REFERENCES mart.Dim_Customer(customer_key);
ALTER TABLE mart.Fact_Satisfaction ADD CONSTRAINT FK_Satisfaction_Date     FOREIGN KEY (date_key)     REFERENCES mart.Dim_Date(date_key);
GO
