"""
Generate a realistic synthetic Zepto inventory dataset (~3,700 rows).
Mirrors the structure of the real Kaggle zepto_v2.csv.

Deliberate messiness included:
- Prices stored in paise (integers), not rupees
- ~5% null values in weight_in_gms and discount_percent
- Some products with MRP=0 or negative discount
- out_of_stock as string 'True'/'False'
- Duplicate product names with different weights/packaging
- A few encoding-unfriendly characters in product names
"""

import csv
import random
import os

random.seed(42)

# ── Product catalog by category ──────────────────────────────────────────────
PRODUCTS = {
    "Fruits & Vegetables": [
        "Onion", "Tomato - Hybrid", "Potato", "Green Chilli", "Coriander Leaves",
        "Banana - Robusta", "Apple - Shimla", "Carrot - Ooty", "Capsicum - Green",
        "Ladies Finger (Bhindi)", "Cucumber", "Lemon", "Ginger", "Garlic",
        "Beetroot", "Cabbage", "Cauliflower", "Spinach (Palak)", "Brinjal",
        "Sweet Corn", "Tender Coconut", "Pomegranate", "Mango - Alphonso",
        "Grapes - Green", "Papaya", "Mushroom - Button", "Peas - Green",
        "Bottle Gourd (Lauki)", "Ridge Gourd", "Drumstick",
        "Mint Leaves (Pudina)", "Curry Leaves", "Amla (Indian Gooseberry)",
        "Watermelon", "Guava", "Pineapple", "Kiwi - Green", "Avocado",
        "Dragon Fruit", "Sweet Potato", "Radish", "Spring Onion",
    ],
    "Dairy & Bread": [
        "Amul Taaza Toned Milk", "Mother Dairy Full Cream Milk",
        "Amul Gold Milk", "Amul Butter - 100g", "Britannia Cheese Slices",
        "Curd - Plain (400g)", "Paneer - Fresh", "Amul Masti Buttermilk",
        "Greek Yogurt - Plain", "Bread - White (Britannia)",
        "Bread - Brown (Harvest Gold)", "Pav - Ladi", "Milk Bread",
        "Amul Cream - Fresh", "Cheese Spread - Amul", "Hung Curd",
        "Flavoured Yogurt - Strawberry", "Flavoured Yogurt - Mango",
        "Lassi - Mango (Amul)", "Cream Cheese", "Whipped Cream",
        "Paneer - Malai", "Tofu - Firm", "Skimmed Milk Powder",
        "Condensed Milk - Milkmaid", "Ghee - Amul (500ml)",
        "Buttermilk - Masala", "Shrikhand - Kesar", "Dahi - Set",
        "Milkshake - Chocolate",
    ],
    "Snacks & Munchies": [
        "Lay's Classic Salted", "Kurkure Masala Munch", "Bingo Mad Angles",
        "Haldiram's Aloo Bhujia", "Pringles Original", "Doritos Nacho Cheese",
        "Act II Popcorn - Butter", "Cornitos Nachos", "Too Yumm Multigrain",
        "Bikaji Bhujia Sev", "Parle Rusk", "Monaco Biscuit", "Hide & Seek",
        "Oreo - Original", "Bourbon Biscuit", "Dark Fantasy",
        "Jim Jam Biscuit", "Nutri Choice Digestive", "Marie Gold",
        "Good Day Butter Cookies", "Bisk Farm Cream Cracker",
        "Trail Mix - Dry Fruits", "Roasted Almonds - Salted",
        "Cashew Nuts - W320", "Fox Nuts (Makhana)", "Protein Bar - Yoga Bar",
        "Granola Bar - Nature Valley", "Peanut Butter Cups",
        "Namkeen Mixture - Haldiram's", "Mathri",
    ],
    "Beverages": [
        "Coca Cola 750ml", "Pepsi 750ml", "Sprite 750ml", "Thums Up 750ml",
        "Frooti Mango 200ml", "Maaza Mango 600ml", "Real Juice - Mixed Fruit",
        "Tropicana Orange 1L", "Paper Boat Aam Panna", "Red Bull 250ml",
        "Monster Energy 350ml", "Sting Energy Drink", "Bisleri Water 1L",
        "Kinley Water 500ml", "Tonic Water - Schweppes",
        "Green Tea - Lipton", "Chamomile Tea - Twinings",
        "Filter Coffee Decoction", "Cold Coffee - Starbucks",
        "Coconut Water - Raw Pressery", "Kombucha - Bombucha",
        "Lassi - Sweet", "Jaljeera Drink", "Nimbu Pani - Concentrate",
        "Protein Shake - MuscleBlaze", "Horlicks 500g",
        "Bournvita 500g", "Glucon-D Orange", "Electral Powder",
        "Instant Coffee - Nescafé",
    ],
    "Cleaning & Household": [
        "Vim Dishwash Gel - Lemon", "Lizol Floor Cleaner - Citrus",
        "Harpic Toilet Cleaner", "Surf Excel Matic Top Load",
        "Tide Detergent Powder", "Colin Glass Cleaner",
        "Domex Toilet Cleaner", "Scotch-Brite Scrub Pad",
        "Garbage Bags - Large", "Aluminium Foil - 9m",
        "Cling Wrap", "Paper Towel Roll", "Toilet Paper - 4 Pack",
        "Room Freshener - Odonil", "Mosquito Repellent - Good Knight",
        "Hit Cockroach Spray", "Phenyl - White", "Hand Wash - Dettol",
        "Sanitizer - Lifebuoy", "Mop Refill", "Broom - Grass",
        "Dustpan", "Fabric Softener - Comfort", "Bleach - Robin",
        "Steel Wool", "Dish Cloth - 3 Pack",
        "Naphthalene Balls", "Rat Trap - Glue", "Drain Cleaner",
        "Glass Wiper",
    ],
    "Personal Care": [
        "Colgate MaxFresh Toothpaste", "Sensodyne Rapid Relief",
        "Oral-B Toothbrush", "Listerine Mouthwash",
        "Head & Shoulders Shampoo", "Dove Shampoo - Daily Shine",
        "Pantene Conditioner", "Hair Oil - Parachute Coconut",
        "Nivea Body Lotion", "Vaseline Intensive Care",
        "Ponds Face Wash", "Garnier Face Wash - Men",
        "Sunscreen - Lakme SPF50", "Dettol Soap - 125g",
        "Dove Beauty Bar", "Lifebuoy Handwash Refill",
        "Gillette Mach3 Razor", "Gillette Shaving Foam",
        "Deodorant - Fogg", "Perfume - Wild Stone",
        "Sanitary Pads - Whisper", "Cotton Balls", "Ear Buds",
        "Wet Wipes - Himalaya", "Lip Balm - Nivea",
        "Face Cream - Olay", "Body Wash - Dove", "Talcum Powder - Ponds",
        "Hair Gel - Set Wet", "Nail Cutter",
    ],
    "Instant & Frozen Food": [
        "Maggi 2-Minute Noodles", "Yippee Noodles - Classic",
        "Top Ramen - Curry", "Cup Noodles - Masala",
        "MTR Ready-to-Eat Rajma", "MTR Ready-to-Eat Dal Fry",
        "Haldiram's Frozen Paratha", "McCain French Fries",
        "Frozen Peas - Safal", "Frozen Mixed Vegetables",
        "Frozen Chicken Nuggets", "Frozen Fish Fingers",
        "Instant Pasta - Knorr", "Soup - Knorr Hot & Sour",
        "Oats - Quaker", "Muesli - Bagrry's", "Cornflakes - Kellogg's",
        "Poha - Instant", "Upma Mix - MTR", "Dosa Batter - iD",
        "Idli Batter - iD", "Frozen Samosa", "Frozen Spring Roll",
        "Chapati - Ready to Eat", "Roti - Multigrain",
        "Atta Noodles - Patanjali", "Pasta - Barilla Penne",
        "Vermicelli - Bambino", "Instant Rice - Minute",
        "Frozen Momos - Wo Momo",
    ],
    "Bakery & Biscuits": [
        "Britannia Cake - Chocolate", "Parle-G Biscuit",
        "Tiger Glucose Biscuit", "Treat Croissant - Chocolate",
        "Muffin - Blueberry", "Brownie - Chocolate",
        "Bread Roll", "Garlic Bread - Frozen", "Pizza Base",
        "Bun - Sweet", "Khari Biscuit", "Cream Roll",
        "Puff - Veg", "Patties - Chicken", "Donut - Glazed",
        "Cup Cake - Vanilla", "Swiss Roll", "Rusk - Premium",
        "Cake Rusk - Britannia", "Nan Khatai",
        "Cookies - Choco Chip", "Butter Cookies - Danish",
        "Wafer - Chocolate", "Biscotti", "Croissant - Plain",
        "Sourdough Bread", "Focaccia Bread", "Bagel - Plain",
        "Cinnamon Roll", "Eclair - Chocolate",
    ],
    "Baby Care": [
        "Cerelac - Wheat Apple", "Cerelac - Rice", "Lactogen 1",
        "Nan Pro 2", "Pampers Diapers - S", "Pampers Diapers - M",
        "Pampers Diapers - L", "Huggies Diapers - S",
        "MamyPoko Pants - M", "MamyPoko Pants - L",
        "Baby Wipes - Johnson's", "Baby Shampoo - Johnson's",
        "Baby Oil - Johnson's", "Baby Powder - Johnson's",
        "Baby Lotion - Himalaya", "Baby Soap - Dove",
        "Diaper Rash Cream", "Gripe Water - Woodward's",
        "Baby Feeding Bottle", "Sippy Cup", "Teether",
        "Baby Blanket", "Baby Bib", "Baby Towel",
    ],
    "Pet Care": [
        "Pedigree Dog Food - Chicken", "Pedigree Dog Food - Veg",
        "Whiskas Cat Food - Tuna", "Whiskas Cat Food - Chicken",
        "Royal Canin - Maxi Adult", "Drools Dog Treat",
        "Cat Litter - Clumping", "Dog Shampoo", "Cat Shampoo",
        "Dog Biscuit - Milk Bone", "Pet Bowl - Steel",
        "Dog Leash", "Cat Toy - Mouse", "Dog Toy - Ball",
        "Fish Food - Taiyo", "Bird Seed Mix", "Hamster Food",
        "Pet Carrier - Small", "Flea Collar - Dog", "Tick Spray",
    ],
}

# ── Weight templates (grams) per category ────────────────────────────────────
WEIGHT_OPTIONS = {
    "Fruits & Vegetables": [250, 500, 1000, 1500, 2000],
    "Dairy & Bread": [100, 200, 400, 500, 1000],
    "Snacks & Munchies": [30, 50, 90, 150, 200, 400],
    "Beverages": [200, 250, 350, 500, 750, 1000],
    "Cleaning & Household": [200, 400, 500, 750, 1000, 2000],
    "Personal Care": [50, 75, 100, 150, 200, 250, 500],
    "Instant & Frozen Food": [50, 70, 140, 200, 400, 500, 1000],
    "Bakery & Biscuits": [40, 60, 100, 150, 200, 300],
    "Baby Care": [100, 200, 300, 400, 500],
    "Pet Care": [100, 200, 400, 500, 1000, 3000],
}

# ── MRP ranges (in paise) per category ───────────────────────────────────────
MRP_RANGE = {
    "Fruits & Vegetables": (1500, 25000),
    "Dairy & Bread": (2000, 55000),
    "Snacks & Munchies": (1000, 40000),
    "Beverages": (1000, 60000),
    "Cleaning & Household": (3000, 80000),
    "Personal Care": (3000, 120000),
    "Instant & Frozen Food": (1000, 50000),
    "Bakery & Biscuits": (1500, 35000),
    "Baby Care": (5000, 200000),
    "Pet Care": (5000, 150000),
}


def generate_row(sku_id, category, product_name):
    """Generate one row of inventory data with realistic messiness."""
    mrp_lo, mrp_hi = MRP_RANGE[category]
    mrp = random.randint(mrp_lo, mrp_hi)

    # ── Discount ─────────────────────────────────────────────────────────
    # Most products get 0-30% discount; some get heavy 40-70%
    if random.random() < 0.15:
        discount = random.randint(35, 70)
    elif random.random() < 0.05:
        discount = 0
    else:
        discount = random.randint(1, 35)

    # Deliberate messiness: ~5% chance of null discount
    discount_val = discount
    if random.random() < 0.05:
        discount_val = None

    # Calculate discounted selling price
    if discount_val is not None:
        selling_price = int(mrp * (1 - discount_val / 100))
    else:
        selling_price = int(mrp * (1 - discount / 100))

    # ── Weight ───────────────────────────────────────────────────────────
    weights = WEIGHT_OPTIONS[category]
    weight = random.choice(weights)
    # ~5% chance of null weight
    if random.random() < 0.05:
        weight = None

    # ── Stock ────────────────────────────────────────────────────────────
    # Higher discount → higher chance of out-of-stock
    oos_threshold = 0.12 + (discount / 200)  # 12-47% base OOS chance
    out_of_stock = random.random() < oos_threshold

    if out_of_stock:
        available_qty = 0
    else:
        available_qty = random.randint(1, 200)

    # ── Deliberate anomalies ─────────────────────────────────────────────
    # ~1% chance of MRP = 0 (data entry error)
    if random.random() < 0.01:
        mrp = 0
        selling_price = 0

    # ~0.5% chance of negative discount (markup error in data)
    if random.random() < 0.005:
        discount_val = -random.randint(1, 10)

    return {
        "sku_id": f"SKU{sku_id:05d}",
        "category": category,
        "name": product_name,
        "mrp": mrp,
        "discount_percent": discount_val,
        "discounted_selling_price": selling_price,
        "weight_in_gms": weight,
        "available_quantity": available_qty,
        "out_of_stock": str(out_of_stock),
    }


def main():
    rows = []
    sku_counter = 1

    for category, products in PRODUCTS.items():
        for product in products:
            # Each product gets 1-3 SKU variations (different weights/packaging)
            num_variations = random.choices([1, 2, 3], weights=[0.4, 0.4, 0.2])[0]
            for _ in range(num_variations):
                row = generate_row(sku_counter, category, product)
                rows.append(row)
                sku_counter += 1

    # Shuffle to mix categories (realistic export from a DB)
    random.shuffle(rows)

    # Write CSV
    fieldnames = [
        "sku_id", "category", "name", "mrp", "discount_percent",
        "discounted_selling_price", "weight_in_gms", "available_quantity",
        "out_of_stock",
    ]

    output_path = os.path.join(os.path.dirname(__file__), "zepto_v2.csv")
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Generated {len(rows)} rows → {output_path}")

    # Print some stats
    nulls_discount = sum(1 for r in rows if r["discount_percent"] is None)
    nulls_weight = sum(1 for r in rows if r["weight_in_gms"] is None)
    zero_mrp = sum(1 for r in rows if r["mrp"] == 0)
    oos = sum(1 for r in rows if r["out_of_stock"] == "True")
    print(f"  Null discounts: {nulls_discount}")
    print(f"  Null weights:   {nulls_weight}")
    print(f"  Zero MRP:       {zero_mrp}")
    print(f"  Out of stock:   {oos}")
    print(f"  Categories:     {len(PRODUCTS)}")


if __name__ == "__main__":
    main()
