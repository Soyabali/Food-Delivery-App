"""Seed data that is not in recipes.json: restaurants, categories, offers,
notifications and starter users. Edit freely before running scripts/seed.py.
Coordinates are around Indiranagar, Bengaluru."""

CDN = "https://cdn.dummyjson.com/recipe-images/{}.webp"

RESTAURANTS = [
    {
        "slug": "royal-biryani", "name": "Royal Biryani House", "cuisines": ["Biryani", "Pakistani", "Mughlai"],
        "description": "Slow-cooked dum biryanis and rich curries.", "image_url": CDN.format(11),
        "address_line": "80 Feet Road, Koramangala", "latitude": 12.9580, "longitude": 77.6480,
        "rating": 4.8, "rating_count": 2400, "delivery_time_min": 25, "delivery_time_max": 30,
        "cost_for_one": 250, "delivery_fee": 0, "is_popular": True, "has_spice_levels": True,
        "match_tags": ["Pakistani"],
        "add_ons": [
            ("Extra Mirchi Ka Salan", "Spicy peanut-sesame gravy", 30),
            ("Mint Raita", "Cooling yoghurt with fresh mint", 25),
            ("Roasted Papad & Salad", "Crisp papad + onion lemon rings", 20),
        ],
    },
    {
        "slug": "pizza-roma", "name": "Pizza Roma Cucina", "cuisines": ["Italian", "Wood-fired Pizza"],
        "description": "Neapolitan pizza and fresh pasta.", "image_url": CDN.format(1),
        "address_line": "100 Feet Road, Indiranagar", "latitude": 12.9790, "longitude": 77.6200,
        "rating": 4.6, "rating_count": 1800, "delivery_time_min": 20, "delivery_time_max": 25,
        "cost_for_one": 350, "delivery_fee": 20, "is_popular": True,
        "match_tags": ["Italian", "Pizza", "Pasta", "Pesto pasta", "Caprese"],
        "add_ons": [("Extra Mozzarella", None, 60), ("Black Olives", None, 40), ("Garlic Dip", None, 30)],
    },
    {
        "slug": "wok-spice", "name": "Wok & Spice", "cuisines": ["Asian", "Thai", "Korean"],
        "description": "Fiery woks, Thai curries and Korean bowls.", "image_url": CDN.format(21),
        "address_line": "CMH Road, Indiranagar", "latitude": 12.9665, "longitude": 77.6365,
        "rating": 4.7, "rating_count": 1500, "delivery_time_min": 15, "delivery_time_max": 20,
        "cost_for_one": 300, "delivery_fee": 25, "badge": "Trending", "is_popular": True, "has_spice_levels": True,
        "match_tags": ["Stir-fry", "Thai", "Korean", "Vietnamese", "Shrimp stir-fry"],
        "add_ons": [("Steamed Jasmine Rice", None, 40), ("Chilli Oil", None, 15)],
    },
    {
        "slug": "green-bowl", "name": "Green Bowl Kitchen", "cuisines": ["Healthy", "Salads", "Smoothies"],
        "description": "100% vegetarian bowls, salads and smoothies.", "image_url": CDN.format(6),
        "address_line": "12th Main, HAL 2nd Stage", "latitude": 12.9750, "longitude": 77.6450,
        "rating": 4.9, "rating_count": 950, "delivery_time_min": 10, "delivery_time_max": 15,
        "cost_for_one": 180, "delivery_fee": 15, "is_pure_veg": True,
        "match_tags": ["Salad", "Vegetarian", "Smoothie", "Quinoa salad", "Chickpea salad"],
        "add_ons": [("Grilled Tofu", None, 50), ("Feta Crumble", None, 40)],
    },
    {
        "slug": "tokyo-ramen", "name": "Tokyo Ramen Bar", "cuisines": ["Japanese", "Ramen", "Sushi"],
        "description": "Ramen, sushi rolls and matcha desserts.", "image_url": CDN.format(16),
        "address_line": "Old Madras Road, Halasuru", "latitude": 12.9950, "longitude": 77.6350,
        "rating": 4.5, "rating_count": 700, "delivery_time_min": 25, "delivery_time_max": 30,
        "cost_for_one": 400, "delivery_fee": 30, "match_tags": ["Japanese"],
        "add_ons": [("Extra Noodles", None, 50), ("Toasted Nori", None, 20)],
    },
    {
        "slug": "casa-mexicana", "name": "Casa Mexicana", "cuisines": ["Mexican", "Street Food"],
        "description": "Tacos, enchiladas and street-style elote.", "image_url": CDN.format(36),
        "address_line": "Ejipura Main Road", "latitude": 12.9500, "longitude": 77.6250,
        "rating": 4.4, "rating_count": 620, "delivery_time_min": 20, "delivery_time_max": 25,
        "cost_for_one": 280, "delivery_fee": 0, "has_spice_levels": True,
        "match_tags": ["Mexican", "Salsa", "Mango salsa", "Elote"],
        "add_ons": [("Guacamole", None, 50), ("Sour Cream", None, 30)],
    },
    {
        "slug": "mezze-house", "name": "Mezze House", "cuisines": ["Lebanese", "Greek", "Moroccan"],
        "description": "Mezze platters, wraps and tagines.", "image_url": CDN.format(29),
        "address_line": "Hosur Road, Adugodi", "latitude": 12.9350, "longitude": 77.6250,
        "rating": 4.6, "rating_count": 540, "delivery_time_min": 25, "delivery_time_max": 30,
        "cost_for_one": 320, "delivery_fee": 25,
        "match_tags": ["Lebanese", "Greek", "Moroccan", "Turkish", "Mediterranean"],
        "add_ons": [("Hummus", None, 40), ("Warm Pita", None, 30)],
    },
    {
        "slug": "apna-kitchen", "name": "Apna Cloud Kitchen", "cuisines": ["Desserts", "Drinks", "Global"],
        "description": "Desserts, drinks and global favourites.", "image_url": CDN.format(35),
        "address_line": "Domlur Layout", "latitude": 12.9600, "longitude": 77.6390,
        "rating": 4.3, "rating_count": 410, "delivery_time_min": 20, "delivery_time_max": 25,
        "cost_for_one": 220, "delivery_fee": 20, "match_tags": [],  # catch-all for everything else
        "add_ons": [],
    },
]

# (name, slug, emoji, tags that put a dish in this category). First match wins.
CATEGORIES = [
    ("Desserts", "desserts", "🍰", ["Dessert", "Tiramisu", "Brigadeiros", "Matcha ice cream", "Cookies"]),
    ("Drinks", "drinks", "🥤", ["Smoothie", "Lassi", "Cocktail", "Mojito", "Caipirinha"]),
    ("Pizza", "pizza", "🍕", ["Pizza", "Margherita pizza"]),
    ("Biryani", "biryani", "🍛", ["Biryani"]),
    ("Curries", "curries", "🍲", ["Curry", "Butter chicken", "Karahi", "Keema", "Saag", "Shrimp curry", "Tagine"]),
    ("Pasta", "pasta", "🍝", ["Pasta", "Pesto pasta"]),
    ("Salads", "salads", "🥗", ["Salad", "Quinoa salad", "Chickpea salad", "Couscous salad", "Caprese"]),
    ("Asian", "asian", "🥡", ["Stir-fry", "Bibimbap", "Spring rolls", "Teriyaki chicken", "Shrimp stir-fry"]),
    ("Japanese", "japanese", "🍣", ["Ramen", "Sushi rolls"]),
    ("Kebabs & Grills", "kebabs-grills", "🍢", ["Kebabs", "Grilling", "Chicken skewers"]),
    ("Soups", "soups", "🍜", ["Soup", "Borscht"]),
    ("Mexican", "mexican", "🌮", ["Mexican", "Enchiladas", "Elote", "Salsa", "Mango salsa"]),
    ("Snacks & Sides", "snacks-sides", "🥙", []),  # fallback
]

OFFERS = [
    {
        "code": "APNA50", "title": "50% OFF", "subtitle": "Up to ₹150 on first 3 orders",
        "discount_type": "percent", "value": 50, "max_discount": 150, "min_order": 0,
        "valid_for_first_n_orders": 3, "image_url": CDN.format(11), "is_featured": True,
    },
    {
        "code": "APNA100", "title": "₹100 OFF", "subtitle": "On orders above ₹300",
        "discount_type": "flat", "value": 100, "min_order": 300, "image_url": CDN.format(20),
    },
]

NOTIFICATIONS = [
    ("50% OFF on your first 3 orders", "Use code APNA50 at checkout. Up to ₹150 off.", "offer"),
    ("Free delivery above ₹199", "Orders above ₹199 ship free from every restaurant.", "delivery"),
]

DEMO_CUSTOMER = {
    "full_name": "Rahul Sharma", "email": "rahul.sharma@example.com", "phone": "98765 43210",
    "password": "supersecret123",
}

DEMO_ADDRESSES = [
    {"label": "Home", "line": "123 Main Street, Sector 4, Indiranagar, Bengaluru", "icon": "home",
     "latitude": 12.9719, "longitude": 77.6412, "is_default": True},
    {"label": "Work", "line": "4th Floor, Prestige Tech Park, Outer Ring Road, Bengaluru", "icon": "work",
     "latitude": 12.9352, "longitude": 77.6950, "is_default": False},
]
