-- ============================================================================
-- FILE:    03_exploratory_analysis.sql
-- PURPOSE: Understand the shape, distribution, and key statistics of the data
-- AUTHOR:  Shiva
-- DATE:    2026-06-04
-- NOTE:    Run this AFTER 02_data_cleaning.sql
-- ============================================================================


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  1. SUMMARY STATISTICS FOR PRICE COLUMNS                              ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Understanding the central tendency and spread of pricing data
-- helps identify anomalies and set expectations for the business queries.

SELECT 
    'MRP (₹)' AS metric,
    COUNT(mrp) AS count,
    ROUND(MIN(mrp), 2) AS min_val,
    ROUND(MAX(mrp), 2) AS max_val,
    ROUND(AVG(mrp), 2) AS mean_val,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mrp)::NUMERIC, 2) AS median_val,
    ROUND(STDDEV(mrp)::NUMERIC, 2) AS std_dev
FROM zepto_inventory

UNION ALL

SELECT 
    'Selling Price (₹)',
    COUNT(discounted_selling_price),
    ROUND(MIN(discounted_selling_price), 2),
    ROUND(MAX(discounted_selling_price), 2),
    ROUND(AVG(discounted_selling_price), 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY discounted_selling_price)::NUMERIC, 2),
    ROUND(STDDEV(discounted_selling_price)::NUMERIC, 2)
FROM zepto_inventory

UNION ALL

SELECT 
    'Discount %',
    COUNT(discount_percent),
    MIN(discount_percent),
    MAX(discount_percent),
    ROUND(AVG(discount_percent), 2),
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY discount_percent),
    ROUND(STDDEV(discount_percent)::NUMERIC, 2)
FROM zepto_inventory;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  2. PRODUCT DISTRIBUTION ACROSS CATEGORIES                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Which categories have the most SKUs? This tells us where the catalog
-- is concentrated and where there might be gaps.

SELECT 
    category,
    COUNT(*) AS total_skus,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_total
FROM zepto_inventory
GROUP BY category
ORDER BY total_skus DESC;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  3. DISCOUNT DISTRIBUTION                                             ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- How are discounts spread? Are most products lightly discounted,
-- or is there a heavy-discount tail?

SELECT 
    CASE 
        WHEN discount_percent = 0 THEN '0% (No discount)'
        WHEN discount_percent BETWEEN 1 AND 10 THEN '1-10%'
        WHEN discount_percent BETWEEN 11 AND 20 THEN '11-20%'
        WHEN discount_percent BETWEEN 21 AND 30 THEN '21-30%'
        WHEN discount_percent BETWEEN 31 AND 40 THEN '31-40%'
        WHEN discount_percent BETWEEN 41 AND 50 THEN '41-50%'
        WHEN discount_percent BETWEEN 51 AND 60 THEN '51-60%'
        WHEN discount_percent BETWEEN 61 AND 70 THEN '61-70%'
        WHEN discount_percent > 70 THEN '70%+'
    END AS discount_bracket,
    COUNT(*) AS product_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_total
FROM zepto_inventory
GROUP BY 
    CASE 
        WHEN discount_percent = 0 THEN '0% (No discount)'
        WHEN discount_percent BETWEEN 1 AND 10 THEN '1-10%'
        WHEN discount_percent BETWEEN 11 AND 20 THEN '11-20%'
        WHEN discount_percent BETWEEN 21 AND 30 THEN '21-30%'
        WHEN discount_percent BETWEEN 31 AND 40 THEN '31-40%'
        WHEN discount_percent BETWEEN 41 AND 50 THEN '41-50%'
        WHEN discount_percent BETWEEN 51 AND 60 THEN '51-60%'
        WHEN discount_percent BETWEEN 61 AND 70 THEN '61-70%'
        WHEN discount_percent > 70 THEN '70%+'
    END
ORDER BY discount_bracket;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  4. STOCK AVAILABILITY OVERVIEW                                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- What percentage of our catalog is currently available vs. out of stock?

SELECT 
    CASE WHEN out_of_stock THEN 'Out of Stock' ELSE 'In Stock' END AS stock_status,
    COUNT(*) AS sku_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_total
FROM zepto_inventory
GROUP BY out_of_stock;

-- Stock availability by category
SELECT 
    category,
    COUNT(*) AS total_skus,
    SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) AS oos_skus,
    ROUND(SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS oos_rate_pct
FROM zepto_inventory
GROUP BY category
ORDER BY oos_rate_pct DESC;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  5. WEIGHT DISTRIBUTION ANALYSIS                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Understanding product weight tiers helps with logistics planning
-- and value-for-money analysis.

SELECT 
    CASE 
        WHEN weight_in_gms < 100 THEN 'Ultra Light (<100g)'
        WHEN weight_in_gms BETWEEN 100 AND 250 THEN 'Light (100-250g)'
        WHEN weight_in_gms BETWEEN 251 AND 500 THEN 'Medium (251-500g)'
        WHEN weight_in_gms BETWEEN 501 AND 1000 THEN 'Heavy (501-1000g)'
        WHEN weight_in_gms > 1000 THEN 'Bulk (>1kg)'
    END AS weight_tier,
    COUNT(*) AS product_count,
    ROUND(AVG(mrp), 2) AS avg_mrp,
    ROUND(AVG(discounted_selling_price), 2) AS avg_selling_price
FROM zepto_inventory
GROUP BY 
    CASE 
        WHEN weight_in_gms < 100 THEN 'Ultra Light (<100g)'
        WHEN weight_in_gms BETWEEN 100 AND 250 THEN 'Light (100-250g)'
        WHEN weight_in_gms BETWEEN 251 AND 500 THEN 'Medium (251-500g)'
        WHEN weight_in_gms BETWEEN 501 AND 1000 THEN 'Heavy (501-1000g)'
        WHEN weight_in_gms > 1000 THEN 'Bulk (>1kg)'
    END
ORDER BY 
    CASE weight_tier
        WHEN 'Ultra Light (<100g)' THEN 1
        WHEN 'Light (100-250g)' THEN 2
        WHEN 'Medium (251-500g)' THEN 3
        WHEN 'Heavy (501-1000g)' THEN 4
        WHEN 'Bulk (>1kg)' THEN 5
    END;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  6. PRICE-PER-GRAM OVERVIEW                                           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Which categories offer the best value per gram?

SELECT 
    category,
    ROUND(AVG(price_per_gram), 4) AS avg_price_per_gram,
    ROUND(MIN(price_per_gram), 4) AS min_price_per_gram,
    ROUND(MAX(price_per_gram), 4) AS max_price_per_gram
FROM zepto_inventory
WHERE price_per_gram IS NOT NULL
GROUP BY category
ORDER BY avg_price_per_gram DESC;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  7. REVENUE POTENTIAL OVERVIEW                                        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Total estimated revenue if all in-stock items were sold

SELECT 
    ROUND(SUM(estimated_revenue), 2) AS total_potential_revenue,
    ROUND(AVG(estimated_revenue), 2) AS avg_revenue_per_sku,
    COUNT(CASE WHEN estimated_revenue > 0 THEN 1 END) AS revenue_generating_skus
FROM zepto_inventory;

-- Revenue potential by category
SELECT 
    category,
    ROUND(SUM(estimated_revenue), 2) AS category_revenue,
    ROUND(SUM(estimated_revenue) * 100.0 / 
          SUM(SUM(estimated_revenue)) OVER(), 1) AS pct_of_total_revenue
FROM zepto_inventory
GROUP BY category
ORDER BY category_revenue DESC;
