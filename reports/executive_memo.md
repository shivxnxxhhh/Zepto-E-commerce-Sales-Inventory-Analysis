# Executive Memo: Zepto Inventory & Pricing Strategy

**To:** Head of Quick-Commerce Operations  
**From:** Data Analyst  
**Date:** June 4, 2026  
**Subject:** Inventory Optimization & Discount Strategy Analysis  

---

## 1. Executive Summary
We conducted a comprehensive analysis of 3,439 SKUs across 10 categories to evaluate inventory health and pricing efficiency. The analysis revealed that while discounting drives volume, aggressive discounting (>40%) is causing severe stockout issues, leading to an estimated ₹81.1M in potential lost revenue across the catalog. We recommend a tiered discount cap and supply-chain realignment for high-velocity categories.

## 2. Key Findings

*   **Deep Discounts Drive Stockouts:** There is a direct, negative correlation between heavy discounts and inventory availability. Products discounted at >40% have an out-of-stock (OOS) rate nearly double that of undiscounted items. 
*   **Critical Category Vulnerabilities:** *Snacks & Munchies* and *Instant & Frozen Food* suffer from the highest OOS rates (>30%). These categories represent high-frequency customer purchases; stockouts here risk driving users to competitor apps.
*   **Revenue Concentration:** The *Baby Care* and *Personal Care* categories hold the highest potential revenue due to high unit costs, yet *Personal Care* suffers from excessive, inefficient discounting (avg. 26%).
*   **Margin Erosion on Clearance:** Over 150 items are being sold at >60% discount. While effective for clearing perishable stock, a significant portion of these are non-perishable household items, indicating a pricing strategy error rather than intentional clearance.

## 3. Strategic Recommendations

**A. Implement a Tiered Discount Cap**
Cease blanket discounting. Implement a hard cap of 35% on all non-perishable categories (e.g., Household, Personal Care). Discounts above 35% should require manual override and be restricted to items with expiration dates within 14 days (e.g., Dairy & Bread).

**B. Supply Chain Realignment for High-Velocity Goods**
Immediately increase safety stock thresholds for *Snacks & Munchies* and *Instant Food*. If an item historically requires a >30% discount to move, it should be delisted rather than restocked, freeing up warehouse space for full-margin essentials.

**C. Promote "Value Tier" Bulk Items**
Our price-per-gram analysis confirms that larger packaging offers significantly better value to the customer while maintaining our absolute margins. The app UI should dynamically promote these bulk items (e.g., 2kg vs 500g produce) when a user searches for the smaller variant.
