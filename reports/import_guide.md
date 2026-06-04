# Power BI & Tableau Import Guide

This guide explains how to connect your data visualization tools to the cleaned Zepto Inventory dataset to build your own dashboards.

## For Power BI Desktop

### 1. Connecting to the Data
1. Open Power BI Desktop.
2. Click **Get Data** > **Text/CSV**.
3. Select the `zepto_v2.csv` file from the `data/` folder.
4. In the preview window, ensure **File Origin** is set to `65001: Unicode (UTF-8)`.
5. Click **Transform Data** (DO NOT click Load yet).

### 2. Power Query Transformations (Data Cleaning)
*Since the raw CSV contains messiness, you must replicate the SQL cleaning steps in Power Query:*
1. **Handle Nulls**: 
   - Right-click the `discount_percent` column > **Replace Values** > Replace `null` (or empty string) with `0`.
2. **Convert Currency**:
   - The `mrp` and `discounted_selling_price` columns are in paise. 
   - Select both columns > **Transform** tab > **Standard** > **Divide** > Enter `100`.
3. **Change Data Types**:
   - Ensure `sku_id`, `category`, and `name` are **Text**.
   - Ensure `mrp` and `discounted_selling_price` are **Fixed Decimal Number** (Currency).
   - Ensure `out_of_stock` is a **True/False** (Boolean).
4. **Remove Invalid Data**:
   - Click the filter dropdown on `mrp` > Uncheck `0`.
5. Click **Close & Apply** in the top left.

### 3. Creating DAX Measures
Once data is loaded, right-click the table to create these measures:

```dax
Total SKUs = COUNT(zepto_inventory[sku_id])

Est. Revenue = SUMX(
    FILTER(zepto_inventory, zepto_inventory[out_of_stock] = FALSE()), 
    zepto_inventory[discounted_selling_price] * zepto_inventory[available_quantity]
)

Out of Stock Rate = 
DIVIDE(
    CALCULATE(COUNTROWS(zepto_inventory), zepto_inventory[out_of_stock] = TRUE()),
    COUNTROWS(zepto_inventory),
    0
)
```

---

## For Tableau Public

### 1. Data Connection
1. Open Tableau Public.
2. Under Connect, choose **Text file**.
3. Select the `zepto_v2.csv` file.

### 2. Data Preparation
1. **Change Types**: Click the icon above `out_of_stock` and change it to **Boolean**.
2. **Calculated Fields**: Create a new calculated field for prices in rupees.
   - Right-click in the data pane > **Create Calculated Field**.
   - Name it `MRP (Rupees)`: `[mrp] / 100`
   - Name it `Selling Price (Rupees)`: `[discounted_selling_price] / 100`
3. Create a calculated field for Revenue:
   - Name it `Estimated Revenue`: `IF [out_of_stock] = FALSE THEN [Selling Price (Rupees)] * [available_quantity] ELSE 0 END`

### 3. Suggested Visuals
- **Treemap**: `Category` on Detail, `Estimated Revenue` on Size and Color.
- **Bar Chart**: `Category` on Rows, `Out of Stock Rate` on Columns.
- **Histogram**: Use the `discount_percent` to create bins (size 10), put bins on Columns and `CNT(sku_id)` on Rows.
