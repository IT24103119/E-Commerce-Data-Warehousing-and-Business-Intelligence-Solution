/* ============================================================
   staging.*  (typed CSV loads)   ods.*  (cleaned)   mart.*  (star schema)
   Every query ends with GO: press F5 once (all
   result grids appear in order) or highlight one query and press F5.
   ============================================================ */
USE DWBI_Project;
GO

/* ------------------------------------------------------------
   Row count of every staging table
   Expected: customers 99441 | orders 99441 | order_items 112650
   order_payments 103886 | order_reviews 99224 | products 32951
   sellers 3095 | geolocation 1000163 | category_translation 71
   ------------------------------------------------------------ */
SELECT v.TableName, v.Row_Count
FROM (VALUES
    ('staging.customers',            (SELECT COUNT(*) FROM staging.customers)),
    ('staging.orders',               (SELECT COUNT(*) FROM staging.orders)),
    ('staging.order_items',          (SELECT COUNT(*) FROM staging.order_items)),
    ('staging.order_payments',       (SELECT COUNT(*) FROM staging.order_payments)),
    ('staging.order_reviews',        (SELECT COUNT(*) FROM staging.order_reviews)),
    ('staging.products',             (SELECT COUNT(*) FROM staging.products)),
    ('staging.sellers',              (SELECT COUNT(*) FROM staging.sellers)),
    ('staging.geolocation',          (SELECT COUNT(*) FROM staging.geolocation)),
    ('staging.category_translation', (SELECT COUNT(*) FROM staging.category_translation))
) AS v(TableName, Row_Count);
GO

/* ------------------------------------------------------------
   NULL counts and duplicate checks in staging
   Three queries; screenshot the three result grids.
   Expected: Null_Delivered_Date ~2,965 | products with no category 610
   customer_id 99,441 vs customer_unique_id 96,096 | order statuses 8
   blank titles ~87,656 | blank messages ~58,247 | not_defined payments 3
   distinct geolocation zip prefixes ~19,000
   ------------------------------------------------------------ */

-- 4a. Missing order dates
SELECT COUNT(*)                                                              AS Total_Orders,
       SUM(CASE WHEN order_approved_at             IS NULL THEN 1 ELSE 0 END) AS Null_Approved,
       SUM(CASE WHEN order_delivered_carrier_date  IS NULL THEN 1 ELSE 0 END) AS Null_Carrier_Date,
       SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS Null_Delivered_Date
FROM staging.orders;
GO

-- 4b. Other data-quality findings
SELECT v.Check_Name, v.Result
FROM (VALUES
    ('Products with no category',
        (SELECT COUNT(*) FROM staging.products WHERE product_category_name IS NULL)),
    ('customer_id values',
        (SELECT COUNT(DISTINCT customer_id) FROM staging.customers)),
    ('customer_unique_id values',
        (SELECT COUNT(DISTINCT customer_unique_id) FROM staging.customers)),
    ('Distinct order statuses',
        (SELECT COUNT(DISTINCT order_status) FROM staging.orders)),
    ('Reviews with blank title',
        (SELECT COUNT(*) FROM staging.order_reviews
         WHERE NULLIF(LTRIM(RTRIM(review_comment_title)), '') IS NULL)),
    ('Reviews with blank message',
        (SELECT COUNT(*) FROM staging.order_reviews
         WHERE NULLIF(LTRIM(RTRIM(review_comment_message)), '') IS NULL)),
    ('Payments of type not_defined',
        (SELECT COUNT(*) FROM staging.order_payments WHERE payment_type = 'not_defined')),
    ('Distinct geolocation zip prefixes',
        (SELECT COUNT(DISTINCT geolocation_zip_code_prefix) FROM staging.geolocation))
) AS v(Check_Name, Result);
GO

-- 4c. Duplicate keys (review_id and geolocation zip are expected to repeat)
SELECT v.Check_Name, v.Duplicate_Keys
FROM (VALUES
    ('staging.orders - order_id',
        (SELECT COUNT(*) FROM (SELECT order_id FROM staging.orders
                               GROUP BY order_id HAVING COUNT(*) > 1) d)),
    ('staging.customers - customer_id',
        (SELECT COUNT(*) FROM (SELECT customer_id FROM staging.customers
                               GROUP BY customer_id HAVING COUNT(*) > 1) d)),
    ('staging.products - product_id',
        (SELECT COUNT(*) FROM (SELECT product_id FROM staging.products
                               GROUP BY product_id HAVING COUNT(*) > 1) d)),
    ('staging.order_items - order_id + order_item_id',
        (SELECT COUNT(*) FROM (SELECT order_id, order_item_id FROM staging.order_items
                               GROUP BY order_id, order_item_id HAVING COUNT(*) > 1) d)),
    ('staging.order_payments - order_id + payment_sequential',
        (SELECT COUNT(*) FROM (SELECT order_id, payment_sequential FROM staging.order_payments
                               GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1) d)),
    ('staging.order_reviews - review_id',
        (SELECT COUNT(*) FROM (SELECT review_id FROM staging.order_reviews
                               GROUP BY review_id HAVING COUNT(*) > 1) d)),
    ('staging.geolocation - zip prefix',
        (SELECT COUNT(*) FROM (SELECT geolocation_zip_code_prefix FROM staging.geolocation
                               GROUP BY geolocation_zip_code_prefix HAVING COUNT(*) > 1) d))
) AS v(Check_Name, Duplicate_Keys);
GO

/* ------------------------------------------------------------
   Foreign keys of the fact tables
   ------------------------------------------------------------ */
SELECT OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id) AS Fact_Table,
       fk.name                                                      AS Foreign_Key_Name,
       COL_NAME(fkc.parent_object_id, fkc.parent_column_id)         AS FK_Column,
       OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id) AS Dimension_Table,
       COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS Dimension_Key
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = 'mart'
  AND OBJECT_NAME(fk.parent_object_id) LIKE 'Fact[_]%'
ORDER BY Fact_Table, FK_Column;
GO


/* ------------------------------------------------------------
   Staging tables with row counts
   Screenshot Object Explorer (Tables, staging.* expanded) beside this.
   ------------------------------------------------------------ */
SELECT s.name AS SchemaName, t.name AS TableName, SUM(p.rows) AS Row_Count
FROM sys.tables t
JOIN sys.schemas s    ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE s.name = 'staging'
GROUP BY s.name, t.name
ORDER BY t.name;
GO


/* ------------------------------------------------------------
   FIGURE 11 - Derived attribute validation (Task 5.4)
   Fact_Delivery: delivery_days, estimate_days, delay_days, is_delayed
   (8 late orders + 7 on-time orders, so both cases are visible)
   ------------------------------------------------------------ */
SELECT x.order_id, x.purchase_date, x.delivery_days, x.estimate_days, x.delay_days, x.is_delayed
FROM (SELECT f.order_id, d.full_date AS purchase_date,
             f.delivery_days, f.estimate_days, f.delay_days, f.is_delayed,
             ROW_NUMBER() OVER (PARTITION BY f.is_delayed ORDER BY f.delivery_key) AS rn
      FROM mart.Fact_Delivery f
      JOIN mart.Dim_Date d ON d.date_key = f.date_key) x
WHERE (x.is_delayed = 1 AND x.rn <= 8) OR (x.is_delayed = 0 AND x.rn <= 7)
ORDER BY x.is_delayed DESC, x.rn;
GO

/* ------------------------------------------------------------
   ETL reconciliation: staging -> ods -> mart
   Fills the validation table in 5.6.
   Small drops between layers are expected (de-duplication, e.g.
   repeated review_id values); mention them under the screenshot.
   ------------------------------------------------------------ */
SELECT v.Measure, v.Staging, v.ODS, v.Mart
FROM (VALUES
    ('Customers',
        (SELECT COUNT(*) FROM staging.customers), (SELECT COUNT(*) FROM ods.customers), (SELECT COUNT(*) FROM mart.Dim_Customer)),
    ('Sellers',
        (SELECT COUNT(*) FROM staging.sellers),   (SELECT COUNT(*) FROM ods.sellers),   (SELECT COUNT(*) FROM mart.Dim_Seller)),
    ('Products',
        (SELECT COUNT(*) FROM staging.products),  (SELECT COUNT(*) FROM ods.products),  (SELECT COUNT(*) FROM mart.Dim_Product)),
    ('Orders',
        (SELECT COUNT(*) FROM staging.orders),    (SELECT COUNT(*) FROM ods.orders),    NULL),
    ('Order items (Fact_Sales)',
        (SELECT COUNT(*) FROM staging.order_items), (SELECT COUNT(*) FROM ods.order_items), (SELECT COUNT(*) FROM mart.Fact_Sales)),
    ('Delivered orders (Fact_Delivery)',
        (SELECT COUNT(*) FROM staging.orders WHERE order_delivered_customer_date IS NOT NULL),
        (SELECT COUNT(*) FROM ods.orders     WHERE order_delivered_customer_date IS NOT NULL),
        (SELECT COUNT(*) FROM mart.Fact_Delivery)),
    ('Reviews (Fact_Satisfaction)',
        (SELECT COUNT(*) FROM staging.order_reviews), (SELECT COUNT(*) FROM ods.order_reviews), (SELECT COUNT(*) FROM mart.Fact_Satisfaction))
) AS v(Measure, Staging, ODS, Mart);
GO

SELECT v.Measure, v.Staging, v.ODS, v.Mart
FROM (VALUES
    ('Total price (sum)',
        (SELECT SUM(price) FROM staging.order_items), (SELECT SUM(price) FROM ods.order_items), (SELECT SUM(price) FROM mart.Fact_Sales)),
    ('Total freight (sum)',
        (SELECT SUM(freight_value) FROM staging.order_items), (SELECT SUM(freight_value) FROM ods.order_items), (SELECT SUM(freight_value) FROM mart.Fact_Sales)),
    ('Total payment value (sum)',
        (SELECT SUM(payment_value) FROM staging.order_payments), (SELECT SUM(payment_value) FROM ods.order_payments), NULL)
) AS v(Measure, Staging, ODS, Mart);
GO

/* ------------------------------------------------------------
   Mart validation
   Row counts + orphan check (every Orphan_Rows value must be 0)
   ------------------------------------------------------------ */
SELECT v.TableName, v.Row_Count
FROM (VALUES
    ('Dim_Date',          (SELECT COUNT(*) FROM mart.Dim_Date)),
    ('Dim_Customer',      (SELECT COUNT(*) FROM mart.Dim_Customer)),
    ('Dim_Seller',        (SELECT COUNT(*) FROM mart.Dim_Seller)),
    ('Dim_Product',       (SELECT COUNT(*) FROM mart.Dim_Product)),
    ('Dim_Geography',     (SELECT COUNT(*) FROM mart.Dim_Geography)),
    ('Fact_Sales',        (SELECT COUNT(*) FROM mart.Fact_Sales)),
    ('Fact_Delivery',     (SELECT COUNT(*) FROM mart.Fact_Delivery)),
    ('Fact_Satisfaction', (SELECT COUNT(*) FROM mart.Fact_Satisfaction))
) AS v(TableName, Row_Count);
GO

SELECT v.Check_Name, v.Orphan_Rows
FROM (VALUES
    ('Fact_Sales -> Dim_Customer',
        (SELECT COUNT(*) FROM mart.Fact_Sales f LEFT JOIN mart.Dim_Customer d ON d.customer_key = f.customer_key WHERE d.customer_key IS NULL)),
    ('Fact_Sales -> Dim_Seller',
        (SELECT COUNT(*) FROM mart.Fact_Sales f LEFT JOIN mart.Dim_Seller d ON d.seller_key = f.seller_key WHERE d.seller_key IS NULL)),
    ('Fact_Sales -> Dim_Product',
        (SELECT COUNT(*) FROM mart.Fact_Sales f LEFT JOIN mart.Dim_Product d ON d.product_key = f.product_key WHERE d.product_key IS NULL)),
    ('Fact_Sales -> Dim_Date',
        (SELECT COUNT(*) FROM mart.Fact_Sales f LEFT JOIN mart.Dim_Date d ON d.date_key = f.date_key WHERE d.date_key IS NULL)),
    ('Fact_Delivery -> Dim_Customer',
        (SELECT COUNT(*) FROM mart.Fact_Delivery f LEFT JOIN mart.Dim_Customer d ON d.customer_key = f.customer_key WHERE d.customer_key IS NULL)),
    ('Fact_Delivery -> Dim_Date',
        (SELECT COUNT(*) FROM mart.Fact_Delivery f LEFT JOIN mart.Dim_Date d ON d.date_key = f.date_key WHERE d.date_key IS NULL)),
    ('Fact_Satisfaction -> Dim_Customer',
        (SELECT COUNT(*) FROM mart.Fact_Satisfaction f LEFT JOIN mart.Dim_Customer d ON d.customer_key = f.customer_key WHERE d.customer_key IS NULL)),
    ('Fact_Satisfaction -> Dim_Date',
        (SELECT COUNT(*) FROM mart.Fact_Satisfaction f LEFT JOIN mart.Dim_Date d ON d.date_key = f.date_key WHERE d.date_key IS NULL))
) AS v(Check_Name, Orphan_Rows);
GO

/* ------------------------------------------------------------
   Example analysis on the mart: top 10 states by revenue
   ------------------------------------------------------------ */
SELECT TOP 10 dc.state AS CustomerState,
       COUNT(DISTINCT f.order_id) AS Orders,
       SUM(f.price)               AS Revenue
FROM mart.Fact_Sales f
JOIN mart.Dim_Customer dc ON dc.customer_key = f.customer_key
GROUP BY dc.state
ORDER BY Revenue DESC;
GO


/* ============================================================
   FOR POWER BI
   Your mart has no flat table, but the report's DAX measures use
   one. Run this ONCE to create it as a view, then in Power BI
   import mart.SalesDeliveryAnalysis. Column names match the DAX.
   ============================================================ */
CREATE OR ALTER VIEW mart.SalesDeliveryAnalysis AS
SELECT fs.sales_key          AS SalesKey,
       fs.order_id           AS OrderID,
       fs.order_item_id      AS OrderItemID,
       fs.order_status       AS OrderStatus,
       dd.full_date          AS PurchaseDate,
       dd.[year]             AS PurchaseYear,
       dd.[quarter]          AS PurchaseQuarter,
       dd.month_name         AS PurchaseMonth,
       dc.customer_unique_id AS CustomerUniqueID,
       dc.city               AS CustomerCity,
       dc.state              AS CustomerState,
       dp.category_name_english AS ProductCategory,
       ds.seller_id          AS SellerID,
       ds.city               AS SellerCity,
       ds.state              AS SellerState,
       fs.price              AS Price,
       fs.freight_value      AS FreightValue,
       fs.price + fs.freight_value AS ItemTotalValue,
       1                     AS ItemCount,
       fd.delivery_days      AS DeliveryDays,
       fd.delay_days         AS DeliveryDelayDays,
       fd.is_delayed         AS IsLateDelivery,
       rv.AvgReviewScore     AS AvgReviewScore
FROM mart.Fact_Sales fs
JOIN mart.Dim_Date dd     ON dd.date_key     = fs.date_key
JOIN mart.Dim_Customer dc ON dc.customer_key = fs.customer_key
JOIN mart.Dim_Seller ds   ON ds.seller_key   = fs.seller_key
JOIN mart.Dim_Product dp  ON dp.product_key  = fs.product_key
LEFT JOIN mart.Fact_Delivery fd ON fd.order_id = fs.order_id
LEFT JOIN (SELECT order_id, AVG(CAST(review_score AS DECIMAL(4,2))) AS AvgReviewScore
           FROM mart.Fact_Satisfaction GROUP BY order_id) rv ON rv.order_id = fs.order_id;
GO

-- Check: view rows must equal Fact_Sales rows, totals must match
SELECT v.Check_Name, v.[View], v.Fact_Sales
FROM (VALUES
    ('Rows',          CAST((SELECT COUNT(*)   FROM mart.SalesDeliveryAnalysis) AS DECIMAL(18,2)), CAST((SELECT COUNT(*)   FROM mart.Fact_Sales) AS DECIMAL(18,2))),
    ('Total price',   (SELECT SUM(Price)        FROM mart.SalesDeliveryAnalysis), (SELECT SUM(price)         FROM mart.Fact_Sales)),
    ('Total freight', (SELECT SUM(FreightValue) FROM mart.SalesDeliveryAnalysis), (SELECT SUM(freight_value) FROM mart.Fact_Sales))
) AS v(Check_Name, [View], Fact_Sales);
GO

/* ============================================================
   "SQL data mart" column (same logic as the DAX)
   ============================================================ */
SELECT SUM(Price)                                             AS Total_Revenue,
       SUM(FreightValue)                                      AS Total_Freight,
       COUNT(DISTINCT OrderID)                                AS Total_Orders,
       SUM(Price) / COUNT(DISTINCT OrderID)                   AS Avg_Order_Value,
       (SELECT AVG(s) FROM (SELECT MAX(AvgReviewScore) AS s
                            FROM mart.SalesDeliveryAnalysis GROUP BY OrderID) x)  AS Avg_Review_Score,
       (SELECT AVG(CAST(d AS FLOAT)) FROM (SELECT MAX(DeliveryDays) AS d
                            FROM mart.SalesDeliveryAnalysis GROUP BY OrderID) y)  AS Avg_Delivery_Days,
       COUNT(DISTINCT CASE WHEN IsLateDelivery = 1 THEN OrderID END) * 1.0
         / NULLIF(COUNT(DISTINCT CASE WHEN OrderStatus = 'delivered' THEN OrderID END), 0) AS Late_Delivery_Rate
FROM mart.SalesDeliveryAnalysis;
GO


/* ============================================================
   cross-check values for the six insights (Power BI visuals)
   ============================================================ */

-- Insight 1: top 10 categories and share of revenue
WITH c AS (SELECT ProductCategory, SUM(Price) AS Revenue
           FROM mart.SalesDeliveryAnalysis GROUP BY ProductCategory)
SELECT TOP 10 ProductCategory, Revenue,
       100.0 * Revenue / SUM(Revenue) OVER () AS Pct_Of_Total
FROM c ORDER BY Revenue DESC;
GO

WITH c AS (SELECT ProductCategory, SUM(Price) AS Revenue
           FROM mart.SalesDeliveryAnalysis GROUP BY ProductCategory),
     t AS (SELECT TOP 10 Revenue FROM c ORDER BY Revenue DESC)
SELECT 100.0 * (SELECT SUM(Revenue) FROM t) / (SELECT SUM(Revenue) FROM c) AS Top10_Pct;
GO

-- Insight 2: revenue and orders by state with share
SELECT TOP 5 CustomerState,
       SUM(Price)              AS Revenue,
       100.0 * SUM(Price) / SUM(SUM(Price)) OVER ()                 AS Pct_Revenue,
       COUNT(DISTINCT OrderID) AS Orders,
       100.0 * COUNT(DISTINCT OrderID)
             / (SELECT COUNT(DISTINCT OrderID) FROM mart.SalesDeliveryAnalysis) AS Pct_Orders
FROM mart.SalesDeliveryAnalysis
GROUP BY CustomerState
ORDER BY Revenue DESC;
GO

-- Insight 3: average actual vs estimated delivery time (delivered orders)
SELECT AVG(CAST(DeliveryDays AS FLOAT))                     AS Avg_Delivery_Days,
       AVG(CAST(DeliveryDays - DeliveryDelayDays AS FLOAT)) AS Avg_Estimated_Days
FROM (SELECT OrderID, MAX(DeliveryDays) AS DeliveryDays, MAX(DeliveryDelayDays) AS DeliveryDelayDays
      FROM mart.SalesDeliveryAnalysis WHERE OrderStatus = 'delivered' GROUP BY OrderID) o;
GO

-- Insight 4: slowest and fastest states (min 100 delivered orders)
SELECT CustomerState, COUNT(*) AS Delivered_Orders, AVG(CAST(DeliveryDays AS FLOAT)) AS Avg_Delivery_Days
FROM (SELECT OrderID, MAX(CustomerState) AS CustomerState, MAX(DeliveryDays) AS DeliveryDays
      FROM mart.SalesDeliveryAnalysis WHERE DeliveryDays IS NOT NULL GROUP BY OrderID) o
GROUP BY CustomerState HAVING COUNT(*) >= 100
ORDER BY Avg_Delivery_Days DESC;
GO

-- Insight 5: review score, on-time vs late
SELECT CASE IsLateDelivery WHEN 1 THEN 'Late' ELSE 'On time' END AS Delivery,
       COUNT(*) AS Orders, AVG(AvgReviewScore) AS Avg_Review_Score
FROM (SELECT OrderID, MAX(CAST(IsLateDelivery AS INT)) AS IsLateDelivery, MAX(AvgReviewScore) AS AvgReviewScore
      FROM mart.SalesDeliveryAnalysis WHERE IsLateDelivery IS NOT NULL GROUP BY OrderID) o
GROUP BY IsLateDelivery;
GO

-- Insight 6: top 10 sellers and combined share of revenue
WITH s AS (SELECT SellerID, SUM(Price) AS Revenue FROM mart.SalesDeliveryAnalysis GROUP BY SellerID)
SELECT TOP 10 SellerID, Revenue, 100.0 * Revenue / SUM(Revenue) OVER () AS Pct_Of_Total
FROM s ORDER BY Revenue DESC;
GO

WITH s AS (SELECT SellerID, SUM(Price) AS Revenue FROM mart.SalesDeliveryAnalysis GROUP BY SellerID),
     t AS (SELECT TOP 10 Revenue FROM s ORDER BY Revenue DESC)
SELECT 100.0 * (SELECT SUM(Revenue) FROM t) / (SELECT SUM(Revenue) FROM s) AS Top10_Pct;
GO
