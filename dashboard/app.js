/**
 * Zepto Inventory Dashboard - Main Application Logic
 * Renders Chart.js visualizations using data from data.js
 */

// Format utilities
const formatCurrency = (val) => '₹' + val.toLocaleString('en-IN');
const formatNumber = (val) => val.toLocaleString('en-IN');
const formatPct = (val) => val + '%';

// Chart Theme Configuration
Chart.defaults.color = '#94a3b8';
Chart.defaults.font.family = "'Inter', sans-serif";
Chart.defaults.plugins.tooltip.backgroundColor = 'rgba(15, 23, 42, 0.9)';
Chart.defaults.plugins.tooltip.titleColor = '#f8fafc';
Chart.defaults.plugins.tooltip.bodyColor = '#e2e8f0';
Chart.defaults.plugins.tooltip.borderColor = '#334155';
Chart.defaults.plugins.tooltip.borderWidth = 1;
Chart.defaults.plugins.tooltip.padding = 12;
Chart.defaults.plugins.tooltip.cornerRadius = 8;
Chart.defaults.scale.grid.color = '#334155';

// Color Palettes
const COLORS = {
    primary: 'rgba(59, 130, 246, 0.8)',
    primaryBorder: '#3b82f6',
    success: 'rgba(16, 185, 129, 0.8)',
    warning: 'rgba(245, 158, 11, 0.8)',
    danger: 'rgba(239, 68, 68, 0.8)',
    purple: 'rgba(139, 92, 246, 0.8)',
    cyan: 'rgba(6, 182, 212, 0.8)',
    slate: 'rgba(100, 116, 139, 0.8)'
};

const CATEGORY_COLORS = [
    '#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6',
    '#ec4899', '#06b6d4', '#14b8a6', '#f97316', '#6366f1'
];

let charts = {};

document.addEventListener('DOMContentLoaded', () => {
    // 1. Populate Filter
    const filterSelect = document.getElementById('category-filter');
    ZEPTO_DATA.categories.forEach(cat => {
        const option = document.createElement('option');
        option.value = cat;
        option.textContent = cat;
        filterSelect.appendChild(option);
    });

    // 2. Initialize Dashboard
    updateKPIs();
    renderCharts();
    populateTable();

    // 3. Filter Event Listener
    filterSelect.addEventListener('change', (e) => {
        const selectedCat = e.target.value;
        if (selectedCat === 'all') {
            updateKPIs();
            renderCharts();
            populateTable();
        } else {
            updateKPIsFiltered(selectedCat);
            // In a full app, we would re-render charts based on filtered data.
            // For this static dashboard, we'll just filter the table.
            populateTableFiltered(selectedCat);
        }
    });
});

function updateKPIs() {
    document.getElementById('kpi-skus').textContent = formatNumber(ZEPTO_DATA.kpis.totalSKUs);
    document.getElementById('kpi-revenue').textContent = formatCurrency(ZEPTO_DATA.kpis.totalRevenue);
    document.getElementById('kpi-inventory').textContent = formatCurrency(ZEPTO_DATA.kpis.totalInventoryValue);
    document.getElementById('kpi-oos').textContent = formatPct(ZEPTO_DATA.kpis.oosRate);
}

function updateKPIsFiltered(category) {
    const rows = ZEPTO_DATA.allRows.filter(r => r.category === category);
    const rev = rows.reduce((s, r) => s + r.estimated_revenue, 0);
    const inv = rows.filter(r => !r.out_of_stock).reduce((s, r) => s + (r.mrp * r.available_quantity), 0);
    const oos = rows.filter(r => r.out_of_stock).length;
    const oosRate = rows.length > 0 ? (oos / rows.length * 100).toFixed(1) : 0;

    document.getElementById('kpi-skus').textContent = formatNumber(rows.length);
    document.getElementById('kpi-revenue').textContent = formatCurrency(rev);
    document.getElementById('kpi-inventory').textContent = formatCurrency(inv);
    document.getElementById('kpi-oos').textContent = formatPct(oosRate);
}

function renderCharts() {
    // Destroy existing charts if they exist
    Object.values(charts).forEach(c => c.destroy());

    // 1. Revenue by Category (Horizontal Bar)
    const revCtx = document.getElementById('revenueChart').getContext('2d');
    const sortedCats = Object.keys(ZEPTO_DATA.revenueByCategory).sort((a,b) => ZEPTO_DATA.revenueByCategory[b] - ZEPTO_DATA.revenueByCategory[a]);
    charts.revenue = new Chart(revCtx, {
        type: 'bar',
        data: {
            labels: sortedCats,
            datasets: [{
                label: 'Est. Revenue',
                data: sortedCats.map(c => ZEPTO_DATA.revenueByCategory[c]),
                backgroundColor: COLORS.primary,
                borderRadius: 4
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    callbacks: {
                        label: (ctx) => formatCurrency(ctx.raw)
                    }
                }
            }
        }
    });

    // 2. OOS Rate by Category (Doughnut)
    const oosCtx = document.getElementById('oosChart').getContext('2d');
    const topOosCats = Object.keys(ZEPTO_DATA.oosByCategory)
        .sort((a,b) => ZEPTO_DATA.oosByCategory[b] - ZEPTO_DATA.oosByCategory[a])
        .slice(0, 5); // Top 5 critical
    
    charts.oos = new Chart(oosCtx, {
        type: 'doughnut',
        data: {
            labels: topOosCats,
            datasets: [{
                data: topOosCats.map(c => ZEPTO_DATA.oosByCategory[c]),
                backgroundColor: [COLORS.danger, COLORS.warning, COLORS.primary, COLORS.purple, COLORS.cyan],
                borderWidth: 0,
                cutout: '70%'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { position: 'right' },
                tooltip: {
                    callbacks: {
                        label: (ctx) => `${ctx.label}: ${formatPct(ctx.raw)} OOS`
                    }
                }
            }
        }
    });

    // 3. Stock Status Stacked Bar
    const stockCtx = document.getElementById('stockStatusChart').getContext('2d');
    const stockLabels = Object.keys(ZEPTO_DATA.stockByCategory);
    const inStockData = stockLabels.map(c => ZEPTO_DATA.stockByCategory[c].inStock);
    const oosData = stockLabels.map(c => ZEPTO_DATA.stockByCategory[c].outOfStock);

    charts.stock = new Chart(stockCtx, {
        type: 'bar',
        data: {
            labels: stockLabels,
            datasets: [
                {
                    label: 'In Stock',
                    data: inStockData,
                    backgroundColor: COLORS.success,
                    stack: 'Stack 0',
                },
                {
                    label: 'Out of Stock',
                    data: oosData,
                    backgroundColor: COLORS.danger,
                    stack: 'Stack 0',
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: { stacked: true },
                y: { stacked: true }
            }
        }
    });

    // 4. Discount Distribution Histogram
    const distCtx = document.getElementById('discountDistChart').getContext('2d');
    const distLabels = Object.keys(ZEPTO_DATA.discountDistribution);
    
    charts.dist = new Chart(distCtx, {
        type: 'bar',
        data: {
            labels: distLabels,
            datasets: [{
                label: 'SKUs Count',
                data: distLabels.map(k => ZEPTO_DATA.discountDistribution[k]),
                backgroundColor: COLORS.purple,
                borderRadius: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } }
        }
    });

    // 5. Discount vs OOS Line
    const dOosCtx = document.getElementById('discountOosChart').getContext('2d');
    const dOosLabels = Object.keys(ZEPTO_DATA.discountVsOOS);
    
    charts.dOos = new Chart(dOosCtx, {
        type: 'line',
        data: {
            labels: dOosLabels,
            datasets: [{
                label: 'OOS Rate (%)',
                data: dOosLabels.map(k => ZEPTO_DATA.discountVsOOS[k].rate),
                borderColor: COLORS.warning,
                backgroundColor: 'transparent',
                borderWidth: 3,
                tension: 0.4,
                pointBackgroundColor: COLORS.warning,
                pointRadius: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: { beginAtZero: true, max: 100 }
            }
        }
    });

    // 6. Price vs Discount Scatter
    const scatterCtx = document.getElementById('scatterChart').getContext('2d');
    
    // Group scatter data by category to create separate datasets for legend colors
    const datasets = ZEPTO_DATA.categories.map((cat, i) => {
        const catData = ZEPTO_DATA.scatterData.filter(d => d.category === cat);
        return {
            label: cat,
            data: catData,
            backgroundColor: CATEGORY_COLORS[i % CATEGORY_COLORS.length] + '80', // Add transparency
            borderColor: CATEGORY_COLORS[i % CATEGORY_COLORS.length],
            pointRadius: 4,
            pointHoverRadius: 6
        };
    });

    charts.scatter = new Chart(scatterCtx, {
        type: 'scatter',
        data: { datasets: datasets },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: {
                    title: { display: true, text: 'MRP (₹)' },
                    type: 'logarithmic' // Log scale better for wide price ranges
                },
                y: {
                    title: { display: true, text: 'Discount %' },
                    beginAtZero: true,
                    max: 100
                }
            },
            plugins: {
                legend: { position: 'right', labels: { boxWidth: 12 } },
                tooltip: {
                    callbacks: {
                        label: (ctx) => {
                            const d = ctx.raw;
                            return `${d.name}: ₹${d.x} @ ${d.y}% off`;
                        }
                    }
                }
            }
        }
    });
}

function renderTableRows(data) {
    const tbody = document.querySelector('#topProductsTable tbody');
    tbody.innerHTML = '';
    
    data.forEach(p => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td><strong>${p.name}</strong></td>
            <td><span style="color: var(--text-secondary)">${p.category}</span></td>
            <td style="color: var(--accent-success); font-weight: 600;">${formatCurrency(p.revenue)}</td>
            <td>${formatPct(p.discount)}</td>
            <td>${p.quantity} units</td>
        `;
        tbody.appendChild(tr);
    });
}

function populateTable() {
    renderTableRows(ZEPTO_DATA.topProducts);
}

function populateTableFiltered(category) {
    const rows = ZEPTO_DATA.allRows
        .filter(r => r.category === category)
        .sort((a, b) => b.estimated_revenue - a.estimated_revenue)
        .slice(0, 10)
        .map(r => ({
            name: r.name,
            category: r.category,
            revenue: r.estimated_revenue,
            discount: r.discount_percent,
            quantity: r.available_quantity
        }));
    renderTableRows(rows);
}
