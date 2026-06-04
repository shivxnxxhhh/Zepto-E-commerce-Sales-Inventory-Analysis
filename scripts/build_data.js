/**
 * Pre-process zepto_v2.csv into a clean JS data object for the dashboard.
 * Runs with Node.js — output is dashboard/data.js
 *
 * Cleaning steps (mirrors the SQL cleaning):
 * - Remove rows with MRP = 0
 * - Fill null discount_percent with 0
 * - Fill null weight_in_gms with category median
 * - Convert paise to rupees
 * - Fix negative discounts
 * - Compute price_per_gram and estimated_revenue
 */

const fs = require("fs");
const path = require("path");

// Read CSV
const csvPath = path.join(__dirname, "..", "data", "zepto_v2.csv");
const raw = fs.readFileSync(csvPath, "utf-8");
const lines = raw.split("\n").filter((l) => l.trim());
const headers = lines[0].split(",");

// Parse CSV (handles quoted fields with commas)
function parseCSVLine(line) {
  const fields = [];
  let current = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === "," && !inQuotes) {
      fields.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  fields.push(current);
  return fields;
}

// Parse all rows
let rows = [];
for (let i = 1; i < lines.length; i++) {
  const fields = parseCSVLine(lines[i]);
  if (fields.length < 9) continue;
  rows.push({
    sku_id: fields[0],
    category: fields[1],
    name: fields[2],
    mrp: fields[3] === "" ? null : parseInt(fields[3]),
    discount_percent: fields[4] === "" ? null : parseInt(fields[4]),
    discounted_selling_price: fields[5] === "" ? null : parseInt(fields[5]),
    weight_in_gms: fields[6] === "" ? null : parseInt(fields[6]),
    available_quantity: fields[7] === "" ? 0 : parseInt(fields[7]),
    out_of_stock: fields[8] === "True",
  });
}

console.log(`Parsed ${rows.length} rows`);

// Clean: remove MRP = 0
rows = rows.filter((r) => r.mrp !== 0 && r.mrp !== null);
console.log(`After removing MRP=0: ${rows.length} rows`);

// Clean: fill null discount with 0
rows.forEach((r) => {
  if (r.discount_percent === null) r.discount_percent = 0;
  if (r.discount_percent < 0) {
    r.discount_percent = 0;
    r.discounted_selling_price = r.mrp;
  }
});

// Clean: fill null weight with category median
const categoryWeights = {};
rows.forEach((r) => {
  if (r.weight_in_gms !== null) {
    if (!categoryWeights[r.category]) categoryWeights[r.category] = [];
    categoryWeights[r.category].push(r.weight_in_gms);
  }
});
const categoryMedianWeight = {};
for (const [cat, weights] of Object.entries(categoryWeights)) {
  weights.sort((a, b) => a - b);
  categoryMedianWeight[cat] = weights[Math.floor(weights.length / 2)];
}
rows.forEach((r) => {
  if (r.weight_in_gms === null) {
    r.weight_in_gms = categoryMedianWeight[r.category] || 500;
  }
});

// Convert paise to rupees
rows.forEach((r) => {
  r.mrp = +(r.mrp / 100).toFixed(2);
  r.discounted_selling_price = +(r.discounted_selling_price / 100).toFixed(2);
});

// Compute derived fields
rows.forEach((r) => {
  r.price_per_gram =
    r.weight_in_gms > 0
      ? +(r.discounted_selling_price / r.weight_in_gms).toFixed(4)
      : 0;
  r.estimated_revenue = +(
    r.discounted_selling_price * r.available_quantity
  ).toFixed(2);
});

// Pre-compute aggregations for the dashboard
const categories = [...new Set(rows.map((r) => r.category))].sort();

// KPI metrics
const totalSKUs = rows.length;
const totalRevenue = rows.reduce((s, r) => s + r.estimated_revenue, 0);
const totalInventoryValue = rows
  .filter((r) => !r.out_of_stock)
  .reduce((s, r) => s + r.mrp * r.available_quantity, 0);
const oosCount = rows.filter((r) => r.out_of_stock).length;
const oosRate = +((oosCount / totalSKUs) * 100).toFixed(1);
const avgDiscount = +(
  rows.reduce((s, r) => s + r.discount_percent, 0) / totalSKUs
).toFixed(1);

// Revenue by category
const revenueByCategory = {};
categories.forEach((c) => (revenueByCategory[c] = 0));
rows.forEach((r) => (revenueByCategory[r.category] += r.estimated_revenue));
Object.keys(revenueByCategory).forEach(
  (k) => (revenueByCategory[k] = +revenueByCategory[k].toFixed(2))
);

// OOS rate by category
const oosByCategory = {};
categories.forEach((c) => {
  const catRows = rows.filter((r) => r.category === c);
  const catOOS = catRows.filter((r) => r.out_of_stock).length;
  oosByCategory[c] = +((catOOS / catRows.length) * 100).toFixed(1);
});

// Discount distribution (10% brackets)
const discountDistribution = {};
for (let i = 0; i <= 70; i += 10) {
  const label = `${i}-${i + 9}%`;
  discountDistribution[label] = rows.filter(
    (r) => r.discount_percent >= i && r.discount_percent < i + 10
  ).length;
}

// Discount vs OOS
const discountVsOOS = {};
const tiers = [
  { label: "0%", min: 0, max: 0 },
  { label: "1-10%", min: 1, max: 10 },
  { label: "11-20%", min: 11, max: 20 },
  { label: "21-30%", min: 21, max: 30 },
  { label: "31-40%", min: 31, max: 40 },
  { label: ">40%", min: 41, max: 100 },
];
tiers.forEach((t) => {
  const tierRows = rows.filter(
    (r) => r.discount_percent >= t.min && r.discount_percent <= t.max
  );
  const tierOOS = tierRows.filter((r) => r.out_of_stock).length;
  discountVsOOS[t.label] = {
    total: tierRows.length,
    oos: tierOOS,
    rate: tierRows.length > 0 ? +((tierOOS / tierRows.length) * 100).toFixed(1) : 0,
  };
});

// Average discount by category
const avgDiscountByCategory = {};
categories.forEach((c) => {
  const catRows = rows.filter((r) => r.category === c);
  avgDiscountByCategory[c] = +(
    catRows.reduce((s, r) => s + r.discount_percent, 0) / catRows.length
  ).toFixed(1);
});

// Stock status by category (for stacked bar)
const stockByCategory = {};
categories.forEach((c) => {
  const catRows = rows.filter((r) => r.category === c);
  stockByCategory[c] = {
    inStock: catRows.filter((r) => !r.out_of_stock).length,
    outOfStock: catRows.filter((r) => r.out_of_stock).length,
  };
});

// Top products by estimated revenue
const topProducts = [...rows]
  .sort((a, b) => b.estimated_revenue - a.estimated_revenue)
  .slice(0, 10)
  .map((r) => ({
    name: r.name,
    category: r.category,
    revenue: r.estimated_revenue,
    discount: r.discount_percent,
    quantity: r.available_quantity,
  }));

// Price scatter data (sample for performance)
const scatterData = rows
  .filter((r) => !r.out_of_stock && r.mrp > 0)
  .map((r) => ({
    x: r.mrp,
    y: r.discount_percent,
    category: r.category,
    name: r.name,
  }));

// Write output
const output = `// Auto-generated from zepto_v2.csv — DO NOT EDIT MANUALLY
// Generated: ${new Date().toISOString()}
// Rows: ${rows.length} (after cleaning)

const ZEPTO_DATA = {
  kpis: {
    totalSKUs: ${totalSKUs},
    totalRevenue: ${totalRevenue.toFixed(2)},
    totalInventoryValue: ${totalInventoryValue.toFixed(2)},
    oosCount: ${oosCount},
    oosRate: ${oosRate},
    avgDiscount: ${avgDiscount},
  },
  categories: ${JSON.stringify(categories)},
  revenueByCategory: ${JSON.stringify(revenueByCategory, null, 2)},
  oosByCategory: ${JSON.stringify(oosByCategory, null, 2)},
  discountDistribution: ${JSON.stringify(discountDistribution, null, 2)},
  discountVsOOS: ${JSON.stringify(discountVsOOS, null, 2)},
  avgDiscountByCategory: ${JSON.stringify(avgDiscountByCategory, null, 2)},
  stockByCategory: ${JSON.stringify(stockByCategory, null, 2)},
  topProducts: ${JSON.stringify(topProducts, null, 2)},
  scatterData: ${JSON.stringify(scatterData)},
  allRows: ${JSON.stringify(rows)},
};
`;

const outPath = path.join(__dirname, "..", "dashboard", "data.js");
fs.writeFileSync(outPath, output, "utf-8");
console.log(`Dashboard data written to ${outPath}`);
console.log(`KPIs: ${JSON.stringify({ totalSKUs, totalRevenue: totalRevenue.toFixed(2), oosRate, avgDiscount })}`);
