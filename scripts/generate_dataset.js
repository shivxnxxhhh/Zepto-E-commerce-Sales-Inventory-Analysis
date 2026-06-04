/**
 * Generate a realistic synthetic Zepto inventory dataset (~3,700 rows).
 * Mirrors the structure of the real Kaggle zepto_v2.csv.
 *
 * Deliberate messiness:
 * - Prices stored in paise (integers), not rupees
 * - ~5% null values in weight_in_gms and discount_percent
 * - Some products with MRP=0
 * - out_of_stock as string 'True'/'False'
 * - Duplicate product names with different weights/packaging
 */

const fs = require("fs");
const path = require("path");

// Seeded random for reproducibility
let seed = 42;
function random() {
  seed = (seed * 16807 + 0) % 2147483647;
  return (seed - 1) / 2147483646;
}
function randInt(lo, hi) {
  return Math.floor(random() * (hi - lo + 1)) + lo;
}
function choice(arr) {
  return arr[Math.floor(random() * arr.length)];
}
function weightedChoice(items, weights) {
  const total = weights.reduce((a, b) => a + b, 0);
  let r = random() * total;
  for (let i = 0; i < items.length; i++) {
    r -= weights[i];
    if (r <= 0) return items[i];
  }
  return items[items.length - 1];
}
function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

const PRODUCTS = {
  "Fruits & Vegetables": [
    "Onion","Tomato - Hybrid","Potato","Green Chilli","Coriander Leaves",
    "Banana - Robusta","Apple - Shimla","Carrot - Ooty","Capsicum - Green",
    "Ladies Finger (Bhindi)","Cucumber","Lemon","Ginger","Garlic",
    "Beetroot","Cabbage","Cauliflower","Spinach (Palak)","Brinjal",
    "Sweet Corn","Tender Coconut","Pomegranate","Mango - Alphonso",
    "Grapes - Green","Papaya","Mushroom - Button","Peas - Green",
    "Bottle Gourd (Lauki)","Ridge Gourd","Drumstick",
    "Mint Leaves (Pudina)","Curry Leaves","Amla (Indian Gooseberry)",
    "Watermelon","Guava","Pineapple","Kiwi - Green","Avocado",
    "Dragon Fruit","Sweet Potato","Radish","Spring Onion",
  ],
  "Dairy & Bread": [
    "Amul Taaza Toned Milk","Mother Dairy Full Cream Milk",
    "Amul Gold Milk","Amul Butter - 100g","Britannia Cheese Slices",
    "Curd - Plain (400g)","Paneer - Fresh","Amul Masti Buttermilk",
    "Greek Yogurt - Plain","Bread - White (Britannia)",
    "Bread - Brown (Harvest Gold)","Pav - Ladi","Milk Bread",
    "Amul Cream - Fresh","Cheese Spread - Amul","Hung Curd",
    "Flavoured Yogurt - Strawberry","Flavoured Yogurt - Mango",
    "Lassi - Mango (Amul)","Cream Cheese","Whipped Cream",
    "Paneer - Malai","Tofu - Firm","Skimmed Milk Powder",
    "Condensed Milk - Milkmaid","Ghee - Amul (500ml)",
    "Buttermilk - Masala","Shrikhand - Kesar","Dahi - Set",
    "Milkshake - Chocolate",
  ],
  "Snacks & Munchies": [
    "Lay's Classic Salted","Kurkure Masala Munch","Bingo Mad Angles",
    "Haldiram's Aloo Bhujia","Pringles Original","Doritos Nacho Cheese",
    "Act II Popcorn - Butter","Cornitos Nachos","Too Yumm Multigrain",
    "Bikaji Bhujia Sev","Parle Rusk","Monaco Biscuit","Hide & Seek",
    "Oreo - Original","Bourbon Biscuit","Dark Fantasy",
    "Jim Jam Biscuit","Nutri Choice Digestive","Marie Gold",
    "Good Day Butter Cookies","Bisk Farm Cream Cracker",
    "Trail Mix - Dry Fruits","Roasted Almonds - Salted",
    "Cashew Nuts - W320","Fox Nuts (Makhana)","Protein Bar - Yoga Bar",
    "Granola Bar - Nature Valley","Peanut Butter Cups",
    "Namkeen Mixture - Haldiram's","Mathri",
  ],
  "Beverages": [
    "Coca Cola 750ml","Pepsi 750ml","Sprite 750ml","Thums Up 750ml",
    "Frooti Mango 200ml","Maaza Mango 600ml","Real Juice - Mixed Fruit",
    "Tropicana Orange 1L","Paper Boat Aam Panna","Red Bull 250ml",
    "Monster Energy 350ml","Sting Energy Drink","Bisleri Water 1L",
    "Kinley Water 500ml","Tonic Water - Schweppes",
    "Green Tea - Lipton","Chamomile Tea - Twinings",
    "Filter Coffee Decoction","Cold Coffee - Starbucks",
    "Coconut Water - Raw Pressery","Kombucha - Bombucha",
    "Lassi - Sweet","Jaljeera Drink","Nimbu Pani - Concentrate",
    "Protein Shake - MuscleBlaze","Horlicks 500g",
    "Bournvita 500g","Glucon-D Orange","Electral Powder",
    "Instant Coffee - Nescafe",
  ],
  "Cleaning & Household": [
    "Vim Dishwash Gel - Lemon","Lizol Floor Cleaner - Citrus",
    "Harpic Toilet Cleaner","Surf Excel Matic Top Load",
    "Tide Detergent Powder","Colin Glass Cleaner",
    "Domex Toilet Cleaner","Scotch-Brite Scrub Pad",
    "Garbage Bags - Large","Aluminium Foil - 9m",
    "Cling Wrap","Paper Towel Roll","Toilet Paper - 4 Pack",
    "Room Freshener - Odonil","Mosquito Repellent - Good Knight",
    "Hit Cockroach Spray","Phenyl - White","Hand Wash - Dettol",
    "Sanitizer - Lifebuoy","Mop Refill","Broom - Grass",
    "Dustpan","Fabric Softener - Comfort","Bleach - Robin",
    "Steel Wool","Dish Cloth - 3 Pack",
    "Naphthalene Balls","Rat Trap - Glue","Drain Cleaner",
    "Glass Wiper",
  ],
  "Personal Care": [
    "Colgate MaxFresh Toothpaste","Sensodyne Rapid Relief",
    "Oral-B Toothbrush","Listerine Mouthwash",
    "Head & Shoulders Shampoo","Dove Shampoo - Daily Shine",
    "Pantene Conditioner","Hair Oil - Parachute Coconut",
    "Nivea Body Lotion","Vaseline Intensive Care",
    "Ponds Face Wash","Garnier Face Wash - Men",
    "Sunscreen - Lakme SPF50","Dettol Soap - 125g",
    "Dove Beauty Bar","Lifebuoy Handwash Refill",
    "Gillette Mach3 Razor","Gillette Shaving Foam",
    "Deodorant - Fogg","Perfume - Wild Stone",
    "Sanitary Pads - Whisper","Cotton Balls","Ear Buds",
    "Wet Wipes - Himalaya","Lip Balm - Nivea",
    "Face Cream - Olay","Body Wash - Dove","Talcum Powder - Ponds",
    "Hair Gel - Set Wet","Nail Cutter",
  ],
  "Instant & Frozen Food": [
    "Maggi 2-Minute Noodles","Yippee Noodles - Classic",
    "Top Ramen - Curry","Cup Noodles - Masala",
    "MTR Ready-to-Eat Rajma","MTR Ready-to-Eat Dal Fry",
    "Haldiram's Frozen Paratha","McCain French Fries",
    "Frozen Peas - Safal","Frozen Mixed Vegetables",
    "Frozen Chicken Nuggets","Frozen Fish Fingers",
    "Instant Pasta - Knorr","Soup - Knorr Hot & Sour",
    "Oats - Quaker","Muesli - Bagrry's","Cornflakes - Kellogg's",
    "Poha - Instant","Upma Mix - MTR","Dosa Batter - iD",
    "Idli Batter - iD","Frozen Samosa","Frozen Spring Roll",
    "Chapati - Ready to Eat","Roti - Multigrain",
    "Atta Noodles - Patanjali","Pasta - Barilla Penne",
    "Vermicelli - Bambino","Instant Rice - Minute",
    "Frozen Momos - Wo Momo",
  ],
  "Bakery & Biscuits": [
    "Britannia Cake - Chocolate","Parle-G Biscuit",
    "Tiger Glucose Biscuit","Treat Croissant - Chocolate",
    "Muffin - Blueberry","Brownie - Chocolate",
    "Bread Roll","Garlic Bread - Frozen","Pizza Base",
    "Bun - Sweet","Khari Biscuit","Cream Roll",
    "Puff - Veg","Patties - Chicken","Donut - Glazed",
    "Cup Cake - Vanilla","Swiss Roll","Rusk - Premium",
    "Cake Rusk - Britannia","Nan Khatai",
    "Cookies - Choco Chip","Butter Cookies - Danish",
    "Wafer - Chocolate","Biscotti","Croissant - Plain",
    "Sourdough Bread","Focaccia Bread","Bagel - Plain",
    "Cinnamon Roll","Eclair - Chocolate",
  ],
  "Baby Care": [
    "Cerelac - Wheat Apple","Cerelac - Rice","Lactogen 1",
    "Nan Pro 2","Pampers Diapers - S","Pampers Diapers - M",
    "Pampers Diapers - L","Huggies Diapers - S",
    "MamyPoko Pants - M","MamyPoko Pants - L",
    "Baby Wipes - Johnson's","Baby Shampoo - Johnson's",
    "Baby Oil - Johnson's","Baby Powder - Johnson's",
    "Baby Lotion - Himalaya","Baby Soap - Dove",
    "Diaper Rash Cream","Gripe Water - Woodward's",
    "Baby Feeding Bottle","Sippy Cup","Teether",
    "Baby Blanket","Baby Bib","Baby Towel",
  ],
  "Pet Care": [
    "Pedigree Dog Food - Chicken","Pedigree Dog Food - Veg",
    "Whiskas Cat Food - Tuna","Whiskas Cat Food - Chicken",
    "Royal Canin - Maxi Adult","Drools Dog Treat",
    "Cat Litter - Clumping","Dog Shampoo","Cat Shampoo",
    "Dog Biscuit - Milk Bone","Pet Bowl - Steel",
    "Dog Leash","Cat Toy - Mouse","Dog Toy - Ball",
    "Fish Food - Taiyo","Bird Seed Mix","Hamster Food",
    "Pet Carrier - Small","Flea Collar - Dog","Tick Spray",
  ],
};

const WEIGHT_OPTIONS = {
  "Fruits & Vegetables": [250,500,1000,1500,2000],
  "Dairy & Bread": [100,200,400,500,1000],
  "Snacks & Munchies": [30,50,90,150,200,400],
  "Beverages": [200,250,350,500,750,1000],
  "Cleaning & Household": [200,400,500,750,1000,2000],
  "Personal Care": [50,75,100,150,200,250,500],
  "Instant & Frozen Food": [50,70,140,200,400,500,1000],
  "Bakery & Biscuits": [40,60,100,150,200,300],
  "Baby Care": [100,200,300,400,500],
  "Pet Care": [100,200,400,500,1000,3000],
};

const MRP_RANGE = {
  "Fruits & Vegetables": [1500,25000],
  "Dairy & Bread": [2000,55000],
  "Snacks & Munchies": [1000,40000],
  "Beverages": [1000,60000],
  "Cleaning & Household": [3000,80000],
  "Personal Care": [3000,120000],
  "Instant & Frozen Food": [1000,50000],
  "Bakery & Biscuits": [1500,35000],
  "Baby Care": [5000,200000],
  "Pet Care": [5000,150000],
};

function generateRow(skuId, category, productName) {
  const [mrpLo, mrpHi] = MRP_RANGE[category];
  let mrp = randInt(mrpLo, mrpHi);

  // Discount
  let discount;
  if (random() < 0.15) {
    discount = randInt(35, 70);
  } else if (random() < 0.05) {
    discount = 0;
  } else {
    discount = randInt(1, 35);
  }

  // ~5% null discount
  let discountVal = discount;
  let discountOut = String(discount);
  if (random() < 0.05) {
    discountOut = "";
    // still use discount for selling price calc
  }

  let sellingPrice = Math.floor(mrp * (1 - discount / 100));

  // Weight
  const weights = WEIGHT_OPTIONS[category];
  let weight = choice(weights);
  let weightOut = String(weight);
  if (random() < 0.05) {
    weightOut = "";
  }

  // Out of stock
  const oosThreshold = 0.12 + discount / 200;
  const outOfStock = random() < oosThreshold;
  const availableQty = outOfStock ? 0 : randInt(1, 200);

  // Anomalies: ~1% MRP = 0
  if (random() < 0.01) {
    mrp = 0;
    sellingPrice = 0;
  }

  // ~0.5% negative discount
  if (random() < 0.005) {
    discountOut = String(-randInt(1, 10));
  }

  return {
    sku_id: `SKU${String(skuId).padStart(5, "0")}`,
    category,
    name: productName,
    mrp,
    discount_percent: discountOut,
    discounted_selling_price: sellingPrice,
    weight_in_gms: weightOut,
    available_quantity: availableQty,
    out_of_stock: outOfStock ? "True" : "False",
  };
}

function main() {
  const rows = [];
  let skuCounter = 1;

  // We have ~296 unique products across 10 categories.
  // To reach ~3,700 rows, each product needs ~12-13 variations on average.
  // We'll use 8-16 variations (different weights, packaging, discounts).
  for (const [category, products] of Object.entries(PRODUCTS)) {
    for (const product of products) {
      const numVariations = randInt(8, 16);
      for (let v = 0; v < numVariations; v++) {
        rows.push(generateRow(skuCounter, category, product));
        skuCounter++;
      }
    }
  }

  shuffle(rows);

  // Build CSV
  const headers = [
    "sku_id","category","name","mrp","discount_percent",
    "discounted_selling_price","weight_in_gms","available_quantity","out_of_stock",
  ];

  const escapeField = (val) => {
    const s = String(val);
    if (s.includes(",") || s.includes('"') || s.includes("\n") || s.includes("(") || s.includes("&")) {
      return '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
  };

  const csvLines = [headers.join(",")];
  for (const row of rows) {
    csvLines.push(headers.map((h) => escapeField(row[h])).join(","));
  }

  const outputPath = path.join(__dirname, "zepto_v2.csv");
  fs.writeFileSync(outputPath, csvLines.join("\n"), "utf-8");
  console.log(`Generated ${rows.length} rows -> ${outputPath}`);

  // Stats
  const nullDiscount = rows.filter((r) => r.discount_percent === "").length;
  const nullWeight = rows.filter((r) => r.weight_in_gms === "").length;
  const zeroMrp = rows.filter((r) => r.mrp === 0).length;
  const oos = rows.filter((r) => r.out_of_stock === "True").length;
  console.log(`  Null discounts: ${nullDiscount}`);
  console.log(`  Null weights:   ${nullWeight}`);
  console.log(`  Zero MRP:       ${zeroMrp}`);
  console.log(`  Out of stock:   ${oos}`);
  console.log(`  Categories:     ${Object.keys(PRODUCTS).length}`);
}

main();
