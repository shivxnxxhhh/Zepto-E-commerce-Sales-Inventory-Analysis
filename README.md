# 🛒 Zepto Inventory & Pricing Analysis

An end-to-end data analytics portfolio project simulating a real-world quick-commerce operational analysis. Built to answer the question: **how does Zepto's discount strategy affect stockouts, and where is revenue being lost?**

---

## 📊 Business Problem

Quick-commerce platforms like Zepto operate on razor-thin margins with 10-minute delivery promises. Two operational traps exist simultaneously:

- **Stockouts** → customer churn, lost revenue, damaged brand trust
- **Overstocking** → capital lockup, spoilage, increased holding cost

This project analyzes **3,439 SKUs across 10 categories** to identify inefficiencies in discounting strategy, pinpoint categories vulnerable to supply chain bottlenecks, and surface actionable pricing recommendations.

---

## 💡 Key Findings

| # | Insight | Impact |
|---|---------|--------|
| 1 | Products discounted **>40%** have an OOS rate nearly **2× higher** than undiscounted items | Demand artificially spiked beyond supply capacity |
| 2 | **Baby Care** and **Personal Care** drive ~39% of total revenue potential | Priority categories for stock protection |
| 3 | **150+ SKUs** operating at >60% discount — many are non-perishable household goods | Margin erosion, not intentional clearance |
| 4 | Estimated **₹81.1M in potential lost revenue** from out-of-stock items | Quantified cost of supply chain inaction |
| 5 | Overall OOS rate: **24.3%** — 1 in 4 SKUs unavailable at any given time | Systemic restocking problem |

---

## 🛠️ Tools & Stack

| Tool | Usage |
|------|-------|
| **PostgreSQL** | Schema design, data cleaning, EDA, 20 business queries |
| **Chart.js** | Interactive web dashboard (no server required) |
| **Node.js** | Data preprocessing (`build_data.js`) |
| **Python** | Synthetic dataset generation |
| **HTML / CSS** | Dashboard UI — dark theme, responsive layout |

---

## 📁 Repository Structure

```
zepto-inventory-analysis/
│
├── README.md
│
├── data/
│   └── zepto_v2.csv              # Synthetic dataset (~3,500 rows)
│
├── sql/
│   ├── 01_create_table.sql       # Schema definition & import instructions
│   ├── 02_data_cleaning.sql      # 10-step cleaning pipeline (documented)
│   ├── 03_exploratory_analysis.sql  # Distribution & summary statistics
│   └── 04_business_insights.sql  # 20 business-driven queries + bonus KPI view
│
├── dashboard/
│   ├── index.html                # Main dashboard (open in browser)
│   ├── style.css                 # Dark theme styling
│   ├── app.js                    # Chart.js rendering logic
│   └── data.js                   # Pre-aggregated data (auto-generated)
│
├── scripts/
│   ├── build_data.js             # Node.js: CSV → dashboard data.js
│   ├── generate_dataset.js       # Synthetic data generator (JS)
│   └── generate_dataset.py       # Synthetic data generator (Python)
│
└── reports/
    ├── executive_memo.md         # 1-page business recommendation
    └── import_guide.md           # Power BI & Tableau setup guide
```

---

## 🚀 How to Run

### Option 1 — Just view the dashboard (fastest)
```
Open dashboard/index.html in any modern browser.
No server, no dependencies required.
```

### Option 2 — SQL Analysis (PostgreSQL)
```sql
-- 1. Install PostgreSQL + pgAdmin 4
-- 2. Run in order:
\i sql/01_create_table.sql
-- 3. Import data/zepto_v2.csv using pgAdmin Import Wizard or COPY command
\i sql/02_data_cleaning.sql
\i sql/03_exploratory_analysis.sql
\i sql/04_business_insights.sql
```

### Option 3 — Regenerate the dataset
```bash
# Python
python scripts/generate_dataset.py

# Node.js
node scripts/generate_dataset.js

# Rebuild dashboard data from CSV
node scripts/build_data.js
```

---

## 🧠 SQL Highlights

The SQL work demonstrates production-grade practices:

- **Systematic null audit** — single-pass query checking every column simultaneously
- **Median imputation via window functions** — `PERCENTILE_CONT(0.5)` for weight nulls, grouped by category
- **Paise-to-rupee conversion** — `ALTER COLUMN ... TYPE DECIMAL USING col / 100.0`
- **Boolean standardization** — TEXT `'True'/'False'` → proper `BOOLEAN`
- **CTEs for lost revenue estimation** — category-level benchmarks joined against OOS items
- **`RANK()` and `ROW_NUMBER()` window functions** — best-value products per category
- **Revenue retention %** — `SUM(revenue) / NULLIF(SUM(mrp_value), 0)` per category

---

## 📊 Dashboard Preview

6 interactive visualizations:

1. **Revenue by Category** — horizontal bar, sorted by revenue potential
2. **OOS Rate by Category** — doughnut chart, top 5 critical categories
3. **Inventory Depth Check** — stacked bar, in-stock vs OOS per category
4. **Discount Distribution** — histogram across 10% brackets
5. **Discount → Stockout Correlation** — line chart showing OOS rate per discount tier
6. **MRP vs Discount Scatter** — logarithmic scale, color-coded by category

All charts support category filtering via the sidebar.

---

## 🧗 Challenges & Real Decisions Made

**The Paise-to-Rupee Trap**
During initial EDA, revenue estimates appeared astronomically high. The dataset stored MRP and selling prices as integers in paise (e.g., `2500` = ₹25.00). Added a cleaning step to `ALTER COLUMN ... TYPE DECIMAL USING col / 100.0`.

**Null Value Strategy**
~5% of `weight_in_gms` was NULL. Dropping rows would lose valid pricing data. Used `PERCENTILE_CONT(0.5)` window function to impute with category median — more robust than mean due to weight outliers in categories like Baby Care.

**Tooling Pivot**
Originally planned Power BI exclusively, but that requires the viewer to have the software installed. Pivoted to a self-contained Chart.js dashboard — zero dependencies, opens in any browser, shareable as a single folder.

---

## 📝 Resume Bullet

> **Zepto E-commerce Inventory Analysis** | PostgreSQL · Chart.js · Node.js  
> Analyzed 3,439 SKUs across 10 categories to quantify discount-driven stockout risk and revenue leakage. Built a 10-step SQL cleaning pipeline (null imputation, unit conversion, boolean standardization) and delivered 20 business insight queries using window functions and CTEs. Developed a self-contained interactive web dashboard. Identified ₹81.1M in potential lost revenue and recommended a tiered discount cap strategy.

---

## ⚠️ Dataset Note

Dataset is synthetic, generated to mirror the structure of the [Kaggle Zepto inventory dataset](https://www.kaggle.com/). Deliberate messiness was introduced (nulls, paise pricing, negative discounts, MRP=0 anomalies) to simulate real-world data quality issues.

---

*Built by [Kaushtubh Mishra](https://github.com/shivxnxxhhh) · June 2026*
