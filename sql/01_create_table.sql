-- ============================================================================
-- FILE:    01_create_table.sql
-- PURPOSE: Create the zepto_inventory table in PostgreSQL
-- AUTHOR:  Shiva
-- DATE:    2026-06-04
-- ============================================================================

-- Create a dedicated schema (optional, keeps things tidy)
-- CREATE SCHEMA IF NOT EXISTS zepto;

-- Drop the table if it already exists (useful during development iterations)
DROP TABLE IF EXISTS zepto_inventory;

-- ============================================================================
-- TABLE: zepto_inventory
-- Each row represents a single SKU (Stock Keeping Unit).
-- The same product may appear multiple times with different weights,
-- packaging, or discount tiers — this is intentional and mirrors how
-- real e-commerce inventory systems work.
-- ============================================================================

CREATE TABLE zepto_inventory (

    -- Unique identifier for each SKU listing (e.g., 'SKU00001')
    -- This is NOT a product ID — the same product can have multiple SKUs
    sku_id VARCHAR(10) PRIMARY KEY,

    -- Product category (e.g., 'Fruits & Vegetables', 'Dairy & Bread')
    -- Used for grouping and aggregation in business analysis
    category VARCHAR(100) NOT NULL,

    -- Human-readable product name
    -- May contain special characters like '&', parentheses, hyphens
    name VARCHAR(255) NOT NULL,

    -- Maximum Retail Price in PAISE (not rupees!)
    -- e.g., 15700 means ₹157.00
    -- IMPORTANT: Must be divided by 100 during cleaning to get rupee values
    -- Some entries may have MRP = 0 (data entry errors — handled in cleaning)
    mrp INTEGER,

    -- Discount percentage applied to MRP
    -- Range: typically 0-70%, but some entries may be NULL or negative
    -- NULL = missing data (about 5% of records)
    -- Negative = likely a data entry error (markup instead of discount)
    discount_percent INTEGER,

    -- Final selling price AFTER discount, in PAISE
    -- Formula: mrp × (1 - discount_percent/100)
    -- Some values may be 0 if MRP is 0
    discounted_selling_price INTEGER,

    -- Product weight or volume in grams
    -- NULL for about 5% of records (missing data)
    -- Used to calculate price-per-gram for value analysis
    weight_in_gms INTEGER,

    -- Number of units currently in stock
    -- 0 when the product is out of stock
    available_quantity INTEGER DEFAULT 0,

    -- Whether the product is currently unavailable
    -- Stored as TEXT ('True'/'False') in the raw CSV — not a proper boolean
    -- Will be cleaned to a proper BOOLEAN in the cleaning phase
    out_of_stock VARCHAR(10)
);

-- ============================================================================
-- DATA IMPORT
-- ============================================================================
-- 
-- Option 1: Using PostgreSQL COPY command (recommended for large files)
-- Run this from psql or pgAdmin's Query Tool:
--
-- COPY zepto_inventory(sku_id, category, name, mrp, discount_percent,
--     discounted_selling_price, weight_in_gms, available_quantity, out_of_stock)
-- FROM 'C:/path/to/your/zepto_v2.csv'
-- WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
--
-- ────────────────────────────────────────────────────────────────────────────
--
-- Option 2: Using pgAdmin's Import/Export wizard
-- 1. Right-click the zepto_inventory table → Import/Export Data
-- 2. Select the zepto_v2.csv file
-- 3. Set Format = CSV, Header = Yes, Encoding = UTF-8
-- 4. Click OK
--
-- ────────────────────────────────────────────────────────────────────────────
--
-- TROUBLESHOOTING COMMON IMPORT ISSUES:
--
-- Issue 1: "invalid byte sequence for encoding UTF8"
--   Fix: Open the CSV in Excel → Save As → CSV UTF-8 (Comma delimited)
--   Or use: ENCODING 'WIN1252' instead of 'UTF8' in the COPY command
--
-- Issue 2: "extra data after last expected column"
--   Fix: Check if product names contain unescaped commas
--   The CSV uses double-quotes for fields with commas, but verify formatting
--
-- Issue 3: NULL values showing as empty strings
--   PostgreSQL COPY handles empty fields as NULL for INTEGER columns
--   For VARCHAR columns, empty strings remain as '' (not NULL)
--
-- ============================================================================

-- Quick verification after import
-- SELECT COUNT(*) AS total_records FROM zepto_inventory;
-- Expected: ~3,475 rows
