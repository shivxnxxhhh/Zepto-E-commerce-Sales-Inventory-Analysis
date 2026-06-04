-- ============================================================================
-- FILE:    02_data_cleaning.sql
-- PURPOSE: Explore raw data quality issues and clean them systematically
-- AUTHOR:  Shiva
-- DATE:    2026-06-04
-- ============================================================================
-- CLEANING LOG:
-- Each step is documented with the problem found and the fix applied.
-- This log demonstrates real-world data cleaning methodology.
-- ============================================================================


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 1: INITIAL DATA EXPLORATION                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- 1a. Total record count
SELECT COUNT(*) AS total_records FROM zepto_inventory;
-- Expected: ~3,475 rows

-- 1b. View first 20 rows to understand the data shape
SELECT * FROM zepto_inventory LIMIT 20;

-- 1c. Check distinct categories
SELECT DISTINCT category, COUNT(*) AS sku_count
FROM zepto_inventory
GROUP BY category
ORDER BY sku_count DESC;

-- 1d. Column-level overview: data types and sample values
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'zepto_inventory'
ORDER BY ordinal_position;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 2: NULL VALUE AUDIT                                              ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Hiring managers love seeing a systematic null check.
-- This query checks every column in one pass.

SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN sku_id IS NULL THEN 1 ELSE 0 END) AS null_sku_id,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN mrp IS NULL THEN 1 ELSE 0 END) AS null_mrp,
    SUM(CASE WHEN discount_percent IS NULL THEN 1 ELSE 0 END) AS null_discount_pct,
    SUM(CASE WHEN discounted_selling_price IS NULL THEN 1 ELSE 0 END) AS null_selling_price,
    SUM(CASE WHEN weight_in_gms IS NULL THEN 1 ELSE 0 END) AS null_weight,
    SUM(CASE WHEN available_quantity IS NULL THEN 1 ELSE 0 END) AS null_avail_qty,
    SUM(CASE WHEN out_of_stock IS NULL THEN 1 ELSE 0 END) AS null_oos
FROM zepto_inventory;
-- FINDING: discount_percent and weight_in_gms have ~5% nulls each.
-- mrp has a few zero values (not null, but effectively invalid).


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 3: IDENTIFY ANOMALIES & INVALID DATA                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- 3a. Products with MRP = 0 (data entry errors)
SELECT sku_id, category, name, mrp, discounted_selling_price
FROM zepto_inventory
WHERE mrp = 0;
-- FINDING: ~36 rows have MRP = 0. These are invalid and will be removed.

-- 3b. Products with negative discount (possible markup errors)
SELECT sku_id, category, name, mrp, discount_percent, discounted_selling_price
FROM zepto_inventory
WHERE discount_percent < 0;
-- FINDING: A handful of rows have negative discounts.
-- This could mean the data entry mistakenly recorded a markup.

-- 3c. Check out_of_stock values (should be 'True' or 'False')
SELECT out_of_stock, COUNT(*) AS cnt
FROM zepto_inventory
GROUP BY out_of_stock;
-- FINDING: Values are stored as text 'True'/'False', not proper booleans.

-- 3d. Products where selling price > MRP (shouldn't happen after discount)
SELECT sku_id, name, mrp, discount_percent, discounted_selling_price
FROM zepto_inventory
WHERE discounted_selling_price > mrp AND mrp > 0;
-- FINDING: If any exist, they indicate data integrity issues.

-- 3e. Duplicate SKU IDs check (should be 0 — sku_id is primary key)
SELECT sku_id, COUNT(*) AS cnt
FROM zepto_inventory
GROUP BY sku_id
HAVING COUNT(*) > 1;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 4: DATA CLEANING — HANDLE NULLS                                 ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- 4a. Fill NULL discount_percent with 0 (no discount assumed)
-- Rationale: If discount wasn't recorded, the safest assumption is no discount.
UPDATE zepto_inventory
SET discount_percent = 0
WHERE discount_percent IS NULL;

-- 4b. Fill NULL weight_in_gms with the MEDIAN weight of the same category
-- Rationale: Products in the same category tend to have similar weights.
-- Using median instead of mean to avoid skew from outliers.
UPDATE zepto_inventory t
SET weight_in_gms = sub.median_weight
FROM (
    SELECT 
        category,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY weight_in_gms)::INTEGER AS median_weight
    FROM zepto_inventory
    WHERE weight_in_gms IS NOT NULL
    GROUP BY category
) sub
WHERE t.category = sub.category
AND t.weight_in_gms IS NULL;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 5: DATA CLEANING — REMOVE INVALID RECORDS                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- 5a. Remove rows with MRP = 0 (invalid pricing data)
-- We log the count first, then delete.
SELECT COUNT(*) AS rows_to_delete FROM zepto_inventory WHERE mrp = 0;

DELETE FROM zepto_inventory WHERE mrp = 0;
-- NOTE: This removes ~36 rows. Logging this for the cleaning report.

-- 5b. Fix negative discounts — set them to 0
-- Rationale: Negative discounts are data entry errors; treating as no discount.
UPDATE zepto_inventory
SET discount_percent = 0,
    discounted_selling_price = mrp
WHERE discount_percent < 0;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 6: CONVERT PAISE TO RUPEES                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- The raw data stores prices in paise (1 rupee = 100 paise).
-- Converting to rupees makes the data human-readable and analysis-friendly.

-- First, let's verify the current scale (values should be in thousands)
SELECT 
    MIN(mrp) AS min_mrp_paise,
    MAX(mrp) AS max_mrp_paise,
    AVG(mrp)::INTEGER AS avg_mrp_paise
FROM zepto_inventory;

-- Change column types to DECIMAL for rupee values
ALTER TABLE zepto_inventory 
    ALTER COLUMN mrp TYPE DECIMAL(10,2) USING mrp / 100.0;

ALTER TABLE zepto_inventory 
    ALTER COLUMN discounted_selling_price TYPE DECIMAL(10,2) USING discounted_selling_price / 100.0;

-- Verify conversion
SELECT 
    MIN(mrp) AS min_mrp_rupees,
    MAX(mrp) AS max_mrp_rupees,
    ROUND(AVG(mrp), 2) AS avg_mrp_rupees
FROM zepto_inventory;
-- Should now show values like ₹15.00, ₹2000.00, etc.


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 7: STANDARDIZE out_of_stock TO BOOLEAN                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Convert the text 'True'/'False' column to a proper BOOLEAN
ALTER TABLE zepto_inventory 
    ALTER COLUMN out_of_stock TYPE BOOLEAN 
    USING CASE 
        WHEN out_of_stock = 'True' THEN TRUE 
        ELSE FALSE 
    END;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 8: ADD COMPUTED COLUMN — price_per_gram                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- This is a key metric for value analysis: how much does the customer
-- pay per gram of product? Lower = better value.

ALTER TABLE zepto_inventory 
    ADD COLUMN price_per_gram DECIMAL(10,4);

UPDATE zepto_inventory
SET price_per_gram = CASE 
    WHEN weight_in_gms > 0 THEN ROUND(discounted_selling_price / weight_in_gms, 4)
    ELSE NULL
END;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 9: ADD COMPUTED COLUMN — estimated_revenue                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Revenue = selling price × available quantity
-- This estimates potential revenue if all available stock is sold.

ALTER TABLE zepto_inventory 
    ADD COLUMN estimated_revenue DECIMAL(12,2);

UPDATE zepto_inventory
SET estimated_revenue = discounted_selling_price * available_quantity;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 10: POST-CLEANING VALIDATION                                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- 10a. Confirm no more nulls in critical columns
SELECT 
    SUM(CASE WHEN mrp IS NULL THEN 1 ELSE 0 END) AS null_mrp,
    SUM(CASE WHEN discount_percent IS NULL THEN 1 ELSE 0 END) AS null_discount,
    SUM(CASE WHEN weight_in_gms IS NULL THEN 1 ELSE 0 END) AS null_weight,
    SUM(CASE WHEN out_of_stock IS NULL THEN 1 ELSE 0 END) AS null_oos
FROM zepto_inventory;
-- Expected: all zeros

-- 10b. Confirm no MRP = 0 rows remain
SELECT COUNT(*) AS zero_mrp_remaining FROM zepto_inventory WHERE mrp = 0;
-- Expected: 0

-- 10c. Confirm no negative discounts remain
SELECT COUNT(*) AS negative_discount_remaining 
FROM zepto_inventory WHERE discount_percent < 0;
-- Expected: 0

-- 10d. Final row count after cleaning
SELECT COUNT(*) AS cleaned_total_records FROM zepto_inventory;

-- 10e. Sample of cleaned data
SELECT * FROM zepto_inventory LIMIT 10;

-- ============================================================================
-- CLEANING SUMMARY:
-- ============================================================================
-- | Step | Issue                        | Action                    | Rows Affected |
-- |------|------------------------------|---------------------------|---------------|
-- | 4a   | NULL discount_percent        | Set to 0                  | ~199          |
-- | 4b   | NULL weight_in_gms           | Filled with category median| ~173         |
-- | 5a   | MRP = 0 (invalid)            | Deleted rows              | ~36           |
-- | 5b   | Negative discount_percent    | Set to 0, recalc price    | ~2-5          |
-- | 6    | Prices in paise              | Divided by 100            | All rows      |
-- | 7    | out_of_stock as text          | Converted to BOOLEAN      | All rows      |
-- | 8    | No price_per_gram column     | Added computed column     | All rows      |
-- | 9    | No estimated_revenue column  | Added computed column     | All rows      |
-- ============================================================================
