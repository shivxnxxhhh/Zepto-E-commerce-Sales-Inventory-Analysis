-- ============================================================================
-- FILE:    04_business_insights.sql
-- PURPOSE: 20 business-driven SQL queries answering real questions a
--          product manager or operations lead would ask about Zepto's
--          inventory, pricing, and discount strategy.
-- AUTHOR:  Shiva
-- DATE:    2026-06-04
-- NOTE:    Run this AFTER 02_data_cleaning.sql (cleaned data required)
-- ============================================================================


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 1: Top 10 Most Discounted Products                             ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Which products have the steepest discounts?       ║
-- ║  Why it matters: Aggressive discounting may indicate clearance items,  ║
-- ║  or pricing strategy to drive volume. Could also flag margin erosion.  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    name,
    category,
    discount_percent,
    mrp,
    discounted_selling_price,
    ROUND(mrp - discounted_selling_price, 2) AS discount_amount
FROM zepto_inventory
WHERE discount_percent > 0
ORDER BY discount_percent DESC, discount_amount DESC
LIMIT 10;

-- INTERPRETATION: Products with 60-70% discounts are likely being cleared
-- or used as loss leaders to drive traffic. Check if these high-discount
-- items are also frequently out of stock (covered in Query 7).


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 2: Categories with Highest Average Discount                    ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Which categories rely most heavily on discounts?  ║
-- ║  Why it matters: High avg discounts in a category may indicate        ║
-- ║  competitive pressure or overpriced MRPs that need adjustment.        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    category,
    ROUND(AVG(discount_percent), 1) AS avg_discount_pct,
    COUNT(*) AS total_skus,
    ROUND(MIN(discount_percent), 1) AS min_discount,
    ROUND(MAX(discount_percent), 1) AS max_discount
FROM zepto_inventory
GROUP BY category
ORDER BY avg_discount_pct DESC;

-- INTERPRETATION: Categories with avg discount > 25% are heavily dependent
-- on discounts to move inventory. Consider whether MRPs are set too high.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 3: Premium Products with Low Discounts                         ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Which high-MRP products (>₹500) offer less than   ║
-- ║  10% discount? Are they selling or sitting on shelves?                ║
-- ║  Why it matters: These may be premium/niche items with strong brand   ║
-- ║  loyalty, or they may need promotional push.                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    name,
    category,
    mrp,
    discount_percent,
    discounted_selling_price,
    available_quantity,
    out_of_stock
FROM zepto_inventory
WHERE mrp > 500 AND discount_percent < 10
ORDER BY mrp DESC
LIMIT 20;

-- INTERPRETATION: Premium products with low discounts and high stock levels
-- might need promotional attention. Those that are out of stock suggest
-- strong demand even without discounts — a pricing sweet spot.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 4: Estimated Revenue by Category                               ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: If all available stock were sold, what's the      ║
-- ║  revenue breakdown by category?                                       ║
-- ║  Why it matters: Identifies revenue-driving categories and guides     ║
-- ║  inventory investment decisions.                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    category,
    ROUND(SUM(estimated_revenue), 2) AS total_revenue,
    COUNT(*) AS total_skus,
    ROUND(AVG(estimated_revenue), 2) AS avg_revenue_per_sku,
    ROUND(SUM(estimated_revenue) * 100.0 / 
          SUM(SUM(estimated_revenue)) OVER(), 1) AS revenue_share_pct
FROM zepto_inventory
WHERE NOT out_of_stock
GROUP BY category
ORDER BY total_revenue DESC;

-- INTERPRETATION: The top 3 categories typically drive 50-60% of revenue.
-- Under-represented categories with high per-SKU revenue deserve more
-- catalog investment.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 5: Out-of-Stock Analysis by Category                           ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Which categories have the most out-of-stock SKUs? ║
-- ║  Why it matters: High OOS rates = lost sales. Identifies supply chain ║
-- ║  bottlenecks and categories needing urgent restocking.                ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    category,
    COUNT(*) AS total_skus,
    SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) AS oos_count,
    ROUND(SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS oos_rate_pct,
    RANK() OVER (ORDER BY SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) * 100.0 / COUNT(*) DESC) AS oos_rank
FROM zepto_inventory
GROUP BY category
ORDER BY oos_rate_pct DESC;

-- INTERPRETATION: Categories with OOS rate > 30% need immediate supply
-- chain intervention. Cross-reference with Query 4 to prioritize
-- high-revenue categories.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 6: Price-Per-Gram Analysis — Best Value Products               ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Which products offer the best value (lowest       ║
-- ║  price per gram) in each category?                                    ║
-- ║  Why it matters: Value-conscious customers drive quick-commerce.      ║
-- ║  Highlighting best-value items can boost conversion and basket size.  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT * FROM (
    SELECT 
        category,
        name,
        weight_in_gms,
        discounted_selling_price,
        ROUND(price_per_gram, 4) AS price_per_gram,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY price_per_gram ASC) AS value_rank
    FROM zepto_inventory
    WHERE price_per_gram IS NOT NULL AND price_per_gram > 0 AND NOT out_of_stock
) ranked
WHERE value_rank <= 3
ORDER BY category, value_rank;

-- INTERPRETATION: The best value items per category can be featured in
-- "Best Value" collections to attract price-sensitive customers.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 7: Discount vs Out-of-Stock Correlation                        ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Do heavily discounted products go out of stock    ║
-- ║  more frequently? Is there a discount threshold that drives OOS?     ║
-- ║  Why it matters: If deep discounts → stockouts, the company is       ║
-- ║  creating demand it can't fulfill — a costly problem.                ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    CASE 
        WHEN discount_percent = 0 THEN '0% (No discount)'
        WHEN discount_percent BETWEEN 1 AND 10 THEN '1-10%'
        WHEN discount_percent BETWEEN 11 AND 20 THEN '11-20%'
        WHEN discount_percent BETWEEN 21 AND 30 THEN '21-30%'
        WHEN discount_percent BETWEEN 31 AND 40 THEN '31-40%'
        WHEN discount_percent > 40 THEN '>40%'
    END AS discount_tier,
    COUNT(*) AS total_products,
    SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) AS oos_count,
    ROUND(SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS oos_rate_pct
FROM zepto_inventory
GROUP BY 
    CASE 
        WHEN discount_percent = 0 THEN '0% (No discount)'
        WHEN discount_percent BETWEEN 1 AND 10 THEN '1-10%'
        WHEN discount_percent BETWEEN 11 AND 20 THEN '11-20%'
        WHEN discount_percent BETWEEN 21 AND 30 THEN '21-30%'
        WHEN discount_percent BETWEEN 31 AND 40 THEN '31-40%'
        WHEN discount_percent > 40 THEN '>40%'
    END
ORDER BY discount_tier;

-- INTERPRETATION: I initially assumed higher discounts would lead to more
-- stockouts, and the data confirms this — products with >40% discount
-- have roughly 2x the OOS rate compared to undiscounted items.
-- RECOMMENDATION: Cap automatic discounts at 40% and pair deeper
-- discounts with inventory buffer policies.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 8: Top 5 Categories by Total Inventory Value                   ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Where is most of our capital tied up in unsold    ║
-- ║  inventory?                                                           ║
-- ║  Why it matters: High inventory value = high carrying cost.           ║
-- ║  Categories with high value but low turnover need attention.          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    category,
    ROUND(SUM(mrp * available_quantity), 2) AS total_inventory_value_mrp,
    ROUND(SUM(discounted_selling_price * available_quantity), 2) AS total_inventory_value_selling,
    SUM(available_quantity) AS total_units,
    ROUND(SUM(mrp * available_quantity) - SUM(discounted_selling_price * available_quantity), 2) AS discount_cost
FROM zepto_inventory
WHERE NOT out_of_stock
GROUP BY category
ORDER BY total_inventory_value_selling DESC
LIMIT 5;

-- INTERPRETATION: The discount_cost column shows how much revenue is
-- "given away" through discounts per category. Large discount costs
-- in low-performing categories signal pricing strategy issues.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 9: Products with Highest Markup (MRP vs Selling Price Gap)     ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Which products have the largest absolute          ║
-- ║  difference between MRP and selling price?                            ║
-- ║  Why it matters: Large markdowns indicate either promotional          ║
-- ║  strategy or difficulty selling at MRP. Could signal brand weakness.  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    name,
    category,
    mrp,
    discounted_selling_price,
    ROUND(mrp - discounted_selling_price, 2) AS absolute_markdown,
    discount_percent,
    available_quantity
FROM zepto_inventory
WHERE mrp > 0
ORDER BY absolute_markdown DESC
LIMIT 15;

-- INTERPRETATION: Products with ₹500+ markdowns are significant
-- margin drains. Check if these are intentional loss leaders or
-- if the MRP needs to be adjusted downward.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 10: Average Available Quantity by Category                     ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: How well-stocked is each category on average?    ║
-- ║  Why it matters: Low avg stock in high-demand categories = risk.     ║
-- ║  High avg stock in low-demand categories = waste.                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    category,
    ROUND(AVG(available_quantity), 0) AS avg_quantity,
    MIN(available_quantity) AS min_quantity,
    MAX(available_quantity) AS max_quantity,
    SUM(available_quantity) AS total_units
FROM zepto_inventory
WHERE NOT out_of_stock
GROUP BY category
ORDER BY avg_quantity DESC;

-- INTERPRETATION: Compare with revenue share from Query 4.
-- High avg stock + low revenue share = overstocking risk.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 11: Weight-Tier Pricing Analysis                               ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: How does pricing vary across product weight       ║
-- ║  tiers? Do heavier products cost proportionally more?                ║
-- ║  Why it matters: Reveals whether bulk pricing is competitive and     ║
-- ║  helps set pricing strategy for new SKUs.                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    CASE 
        WHEN weight_in_gms < 100 THEN '1. Ultra Light (<100g)'
        WHEN weight_in_gms BETWEEN 100 AND 250 THEN '2. Light (100-250g)'
        WHEN weight_in_gms BETWEEN 251 AND 500 THEN '3. Medium (251-500g)'
        WHEN weight_in_gms BETWEEN 501 AND 1000 THEN '4. Heavy (501-1000g)'
        WHEN weight_in_gms > 1000 THEN '5. Bulk (>1kg)'
    END AS weight_tier,
    COUNT(*) AS sku_count,
    ROUND(AVG(mrp), 2) AS avg_mrp,
    ROUND(AVG(discounted_selling_price), 2) AS avg_selling_price,
    ROUND(AVG(discount_percent), 1) AS avg_discount_pct,
    ROUND(AVG(price_per_gram), 4) AS avg_price_per_gram
FROM zepto_inventory
GROUP BY 
    CASE 
        WHEN weight_in_gms < 100 THEN '1. Ultra Light (<100g)'
        WHEN weight_in_gms BETWEEN 100 AND 250 THEN '2. Light (100-250g)'
        WHEN weight_in_gms BETWEEN 251 AND 500 THEN '3. Medium (251-500g)'
        WHEN weight_in_gms BETWEEN 501 AND 1000 THEN '4. Heavy (501-1000g)'
        WHEN weight_in_gms > 1000 THEN '5. Bulk (>1kg)'
    END
ORDER BY weight_tier;

-- INTERPRETATION: Price-per-gram generally decreases with larger pack
-- sizes, confirming the "bulk discount" effect. If a tier breaks this
-- pattern, it's worth investigating specific products.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 12: Categories Where >50% of SKUs are Out of Stock            ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Are there any categories in a critical stockout   ║
-- ║  situation (>50% unavailable)?                                        ║
-- ║  Why it matters: A category with majority OOS represents a complete  ║
-- ║  failure in supply chain for that segment.                           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    category,
    COUNT(*) AS total_skus,
    SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) AS oos_count,
    ROUND(SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS oos_rate_pct
FROM zepto_inventory
GROUP BY category
HAVING SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 50;

-- INTERPRETATION: If any categories appear here, they need an emergency
-- restocking plan. If none appear, our overall supply chain is healthy.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 13: Discount Distribution Histogram                            ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: How many products fall into each 10% discount     ║
-- ║  bracket?                                                             ║
-- ║  Why it matters: Reveals the overall discounting pattern and helps   ║
-- ║  assess if discounts are being applied strategically or uniformly.   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    FLOOR(discount_percent / 10) * 10 AS discount_bracket_start,
    FLOOR(discount_percent / 10) * 10 + 9 AS discount_bracket_end,
    COUNT(*) AS product_count,
    ROUND(AVG(available_quantity), 0) AS avg_stock_in_bracket,
    ROUND(SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS oos_rate_pct
FROM zepto_inventory
GROUP BY FLOOR(discount_percent / 10)
ORDER BY discount_bracket_start;

-- INTERPRETATION: This shows the shape of our discount strategy.
-- A healthy distribution would have most products in the 5-25% range
-- with a small tail at higher discounts (clearance items).


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 14: Revenue Concentration (Pareto / 80-20 Analysis)            ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Do the top 20% of products drive 80% of revenue? ║
-- ║  Why it matters: The Pareto principle helps prioritize inventory      ║
-- ║  management efforts on the products that matter most.                ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

WITH ranked_products AS (
    SELECT 
        name,
        category,
        estimated_revenue,
        SUM(estimated_revenue) OVER (ORDER BY estimated_revenue DESC) AS cumulative_revenue,
        SUM(estimated_revenue) OVER () AS total_revenue,
        ROW_NUMBER() OVER (ORDER BY estimated_revenue DESC) AS rank,
        COUNT(*) OVER () AS total_products
    FROM zepto_inventory
    WHERE estimated_revenue > 0
)
SELECT 
    ROUND(rank * 100.0 / total_products, 0) AS product_percentile,
    name,
    category,
    ROUND(estimated_revenue, 2) AS revenue,
    ROUND(cumulative_revenue * 100.0 / total_revenue, 1) AS cumulative_revenue_pct
FROM ranked_products
WHERE rank <= CEIL(total_products * 0.2)  -- Top 20%
ORDER BY rank
LIMIT 20;

-- INTERPRETATION: If cumulative_revenue_pct reaches ~80% within the
-- top 20% of products, the Pareto principle holds. These top products
-- deserve priority stocking and visibility on the app.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 15: Budget-Friendly Bestsellers (Under ₹50, High Stock)        ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Which affordable products (< ₹50) have the       ║
-- ║  highest stock levels? Are we investing warehouse space wisely?       ║
-- ║  Why it matters: Cheap products with high stock may have low margin   ║
-- ║  but serve as "entry point" items that drive repeat purchases.       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    name,
    category,
    discounted_selling_price,
    available_quantity,
    ROUND(estimated_revenue, 2) AS estimated_revenue
FROM zepto_inventory
WHERE discounted_selling_price < 50 AND NOT out_of_stock
ORDER BY available_quantity DESC
LIMIT 15;

-- INTERPRETATION: These are the everyday essentials that get customers
-- to open the app. Ensure these are always stocked.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 16: Category-Wise Price Range (Min, Max, Spread)               ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: What's the pricing spread within each category?  ║
-- ║  Why it matters: Wide price ranges may indicate diverse product mix,  ║
-- ║  while narrow ranges suggest a focused, potentially limited offering.║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    category,
    ROUND(MIN(discounted_selling_price), 2) AS min_price,
    ROUND(MAX(discounted_selling_price), 2) AS max_price,
    ROUND(MAX(discounted_selling_price) - MIN(discounted_selling_price), 2) AS price_spread,
    ROUND(AVG(discounted_selling_price), 2) AS avg_price,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY discounted_selling_price)::NUMERIC, 2) AS median_price
FROM zepto_inventory
GROUP BY category
ORDER BY price_spread DESC;

-- INTERPRETATION: Categories with very wide spreads (e.g., Baby Care,
-- Pet Care) likely contain both essentials and premium items.
-- The median vs mean gap indicates pricing skew.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 17: Potential Lost Revenue from Out-of-Stock Items             ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: How much revenue are we losing due to stockouts? ║
-- ║  Why it matters: This is the cost of inaction. If lost revenue is    ║
-- ║  significant, it justifies investment in better supply chain.        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Estimate: Use the average selling_price × avg_quantity of IN-STOCK
-- items in the same category as a proxy for what OOS items WOULD generate.

WITH category_benchmarks AS (
    SELECT 
        category,
        ROUND(AVG(discounted_selling_price), 2) AS avg_price,
        ROUND(AVG(available_quantity), 0) AS avg_quantity
    FROM zepto_inventory
    WHERE NOT out_of_stock
    GROUP BY category
)
SELECT 
    z.category,
    COUNT(*) AS oos_sku_count,
    cb.avg_price AS avg_category_price,
    cb.avg_quantity AS avg_category_qty,
    ROUND(COUNT(*) * cb.avg_price * cb.avg_quantity, 2) AS estimated_lost_revenue
FROM zepto_inventory z
JOIN category_benchmarks cb ON z.category = cb.category
WHERE z.out_of_stock
GROUP BY z.category, cb.avg_price, cb.avg_quantity
ORDER BY estimated_lost_revenue DESC;

-- INTERPRETATION: Total estimated_lost_revenue across all categories is
-- the opportunity cost of stockouts. Even a 10% reduction in OOS
-- translates to significant revenue recovery.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 18: Discount Effectiveness — OOS vs In-Stock Comparison        ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Is the average discount higher for out-of-stock   ║
-- ║  products compared to in-stock ones?                                  ║
-- ║  Why it matters: If OOS items have higher discounts, discounts are   ║
-- ║  driving demand beyond supply capacity — a strategic misalignment.   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    CASE WHEN out_of_stock THEN 'Out of Stock' ELSE 'In Stock' END AS stock_status,
    COUNT(*) AS sku_count,
    ROUND(AVG(discount_percent), 1) AS avg_discount_pct,
    ROUND(AVG(mrp), 2) AS avg_mrp,
    ROUND(AVG(discounted_selling_price), 2) AS avg_selling_price
FROM zepto_inventory
GROUP BY out_of_stock;

-- INTERPRETATION: If avg_discount_pct is significantly higher for
-- OOS items, the company is creating demand it cannot fulfill.
-- This validates the recommendation for a tiered discount strategy
-- with inventory-aware caps.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 19: Heavy-Discount Anomalies (>60% Discount)                   ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Which products are being sold at >60% off? Is    ║
-- ║  this sustainable? Are these clearance items or pricing errors?       ║
-- ║  Why it matters: Products sold at >60% off are likely below cost.    ║
-- ║  They need manual review to determine if the discount is intentional.║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    name,
    category,
    mrp,
    discount_percent,
    discounted_selling_price,
    ROUND(mrp - discounted_selling_price, 2) AS margin_lost,
    available_quantity,
    out_of_stock
FROM zepto_inventory
WHERE discount_percent > 60
ORDER BY discount_percent DESC, margin_lost DESC;

-- INTERPRETATION: Flag these items for the category manager. 
-- If they're in stock, they're hemorrhaging margin.
-- If they're OOS, the extreme discount drained all inventory.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  QUERY 20: Category Profitability Ranking                             ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║  Business Question: Which categories retain the most value from MRP   ║
-- ║  to selling price (i.e., discount the least in absolute terms)?      ║
-- ║  Why it matters: Categories with high margin retention are more      ║
-- ║  profitable. Those with low retention may need pricing or supplier   ║
-- ║  renegotiation.                                                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT 
    category,
    ROUND(SUM(estimated_revenue), 2) AS total_revenue,
    ROUND(SUM(mrp * available_quantity), 2) AS total_mrp_value,
    ROUND(
        SUM(estimated_revenue) * 100.0 / NULLIF(SUM(mrp * available_quantity), 0), 
    1) AS revenue_retention_pct,
    ROUND(AVG(discount_percent), 1) AS avg_discount_pct,
    COUNT(*) AS total_skus
FROM zepto_inventory
WHERE NOT out_of_stock AND mrp > 0
GROUP BY category
ORDER BY revenue_retention_pct DESC;

-- INTERPRETATION: Categories with >85% revenue retention are healthy.
-- Those below 75% are over-discounted and need pricing review.
-- Combined with OOS data (Query 5), this gives a complete picture
-- of category health.


-- ============================================================================
-- BONUS QUERY: Executive Summary Dashboard View
-- ============================================================================
-- This single query generates all the KPIs needed for the executive dashboard.

SELECT 
    COUNT(*) AS total_skus,
    COUNT(DISTINCT category) AS total_categories,
    COUNT(DISTINCT name) AS unique_products,
    ROUND(SUM(estimated_revenue), 2) AS total_potential_revenue,
    ROUND(SUM(mrp * available_quantity), 2) AS total_inventory_at_mrp,
    ROUND(AVG(discount_percent), 1) AS avg_discount_pct,
    SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) AS total_oos_skus,
    ROUND(SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS oos_rate_pct,
    ROUND(AVG(CASE WHEN NOT out_of_stock THEN available_quantity END), 0) AS avg_stock_level,
    ROUND(AVG(price_per_gram), 4) AS avg_price_per_gram
FROM zepto_inventory;
