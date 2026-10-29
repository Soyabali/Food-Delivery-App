"""Fill an empty (migrated) database with starter data.

    python scripts/seed.py            # refuses if restaurants already exist
    python scripts/seed.py --reset    # DELETES ALL DATA in every table first

Admin credentials come from ADMIN_EMAIL / ADMIN_PASSWORD in backend/.env
(defaults are printed at the end - change them before going live).
"""

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from sqlalchemy import func, select, text  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.core.database import SessionLocal  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.models import (  # noqa: E402
    AddOn,
    Address,
    Base,
    Category,
    DiscountType,
    MenuItem,
    MenuItemVariant,
    Notification,
    NotificationKind,
    Offer,
    Restaurant,
    User,
    UserRole,
)
from seed import catalog  # noqa: E402

NON_VEG = re.compile(
    r"\b(chicken|beef|pork|lamb|mutton|goat|bacon|ham|sausage|shrimp|prawns?|fish|salmon|tuna|crab|"
    r"lobster|anchov\w*|turkey|duck|eggs?|keema|meat)\b",
    re.IGNORECASE,
)
LIGHT_MEALS = {"beverage", "dessert", "snack", "snacks"}


def price_for(recipe: dict) -> int:
    """Starter price (₹) from calories, cooking time and difficulty, rounded to ₹10.
    Edit prices from the dashboard afterwards."""
    minutes = recipe["prepTimeMinutes"] + recipe["cookTimeMinutes"]
    raw = 99 + recipe["caloriesPerServing"] * 0.45 + minutes * 0.8 + (30 if recipe["difficulty"] == "Medium" else 0)
    return max(100, min(550, round(raw / 10) * 10))


def describe(recipe: dict) -> str:
    names = [i.split(",")[0].strip().lower() for i in recipe["ingredients"][:4]]
    listed = names[0] if len(names) == 1 else f"{', '.join(names[:-1])} and {names[-1]}"
    meal = recipe["mealType"][0].lower() if recipe["mealType"] else "dish"
    minutes = recipe["prepTimeMinutes"] + recipe["cookTimeMinutes"]
    return f"A {recipe['cuisine']} {meal} made with {listed}. Freshly prepared in about {minutes} minutes."


def is_veg(recipe: dict) -> bool:
    return not NON_VEG.search(recipe["name"]) and not any(NON_VEG.search(i) for i in recipe["ingredients"])


def pick_restaurant(recipe: dict, veg: bool, restaurants: list[tuple[dict, Restaurant]]) -> Restaurant:
    tags = {t.lower() for t in recipe["tags"]} | {recipe["cuisine"].lower()}
    for spec, model in restaurants:
        if not spec["match_tags"] or (spec.get("is_pure_veg") and not veg):
            continue
        if any(t.lower() in tags for t in spec["match_tags"]):
            return model
    return next(model for spec, model in restaurants if not spec["match_tags"])


def pick_category(recipe: dict, categories: list[tuple[list[str], Category]]) -> Category:
    tags = {t.lower() for t in recipe["tags"]} | {recipe["cuisine"].lower()}
    for match, model in categories:
        if any(m.lower() in tags for m in match):
            return model
    return categories[-1][1]


def reset(db) -> None:
    tables = ", ".join(f'"{t.name}"' for t in reversed(Base.metadata.sorted_tables))
    db.execute(text(f"TRUNCATE {tables} RESTART IDENTITY CASCADE"))
    db.commit()


def seed(db) -> dict:
    recipes = json.loads((ROOT / "seed" / "recipes.json").read_text(encoding="utf-8"))["recipes"]

    settings = get_settings()
    admin_email, admin_password = settings.admin_email, settings.admin_password
    db.add(User(full_name="Apna Admin", email=admin_email.lower(), password_hash=hash_password(admin_password),
                role=UserRole.admin))

    demo = catalog.DEMO_CUSTOMER
    customer = User(full_name=demo["full_name"], email=demo["email"], phone=demo["phone"],
                    password_hash=hash_password(demo["password"]))
    customer.addresses = [Address(**a) for a in catalog.DEMO_ADDRESSES]
    db.add(customer)

    categories = []
    for order, (name, slug, emoji, match) in enumerate(catalog.CATEGORIES):
        c = Category(name=name, slug=slug, emoji=emoji, sort_order=order)
        db.add(c)
        categories.append((match, c))

    restaurants = []
    for spec in catalog.RESTAURANTS:
        fields = {k: v for k, v in spec.items() if k not in ("match_tags", "add_ons")}
        r = Restaurant(**fields)
        r.add_ons = [AddOn(name=n, subtitle=sub, price=p, sort_order=i) for i, (n, sub, p) in enumerate(spec["add_ons"])]
        db.add(r)
        restaurants.append((spec, r))
    db.flush()

    for recipe in recipes:
        veg = is_veg(recipe)
        restaurant = pick_restaurant(recipe, veg, restaurants)
        light = any(m.lower() in LIGHT_MEALS for m in recipe["mealType"])
        price = price_for(recipe)
        item = MenuItem(
            id=recipe["id"],  # keep ids stable (matches the app's current dish ids)
            restaurant=restaurant,
            category=pick_category(recipe, categories),
            name=recipe["name"],
            description=describe(recipe),
            price=price,
            image_url=recipe["image"],
            is_veg=veg,
            has_spice_levels=not light and restaurant.has_spice_levels,
            allows_add_ons=not light,
            cuisine=recipe["cuisine"],
            tags=recipe["tags"],
            meal_types=recipe["mealType"],
            ingredients=recipe["ingredients"],
            prep_time_minutes=recipe["prepTimeMinutes"] + recipe["cookTimeMinutes"],
            calories=recipe["caloriesPerServing"],
            difficulty=recipe["difficulty"],
            servings=recipe["servings"],
            rating=recipe["rating"],
            rating_count=recipe["reviewCount"],
            badge="Top Rated" if recipe["rating"] >= 4.8 else ("Popular" if recipe["reviewCount"] >= 90 else None),
        )
        if not light:
            item.variants = [
                MenuItemVariant(name="Regular (Serves 1)", subtitle="Standard single portion", is_default=True),
                MenuItemVariant(name="Large (Serves 2)", subtitle="Double portion for sharing",
                                price_delta=round(price * 0.6 / 10) * 10, sort_order=1),
            ]
        db.add(item)
    db.flush()
    # Explicit ids were used, so move the sequence past them.
    db.execute(text("SELECT setval(pg_get_serial_sequence('menu_items', 'id'), (SELECT MAX(id) FROM menu_items))"))

    for o in catalog.OFFERS:
        db.add(Offer(**{**o, "discount_type": DiscountType(o["discount_type"])}))
    for title, body, kind in catalog.NOTIFICATIONS:
        db.add(Notification(title=title, body=body, kind=NotificationKind(kind)))

    db.flush()
    customer.selected_address_id = next(a.id for a in customer.addresses if a.is_default)
    db.commit()
    return {"admin_email": admin_email, "admin_password": admin_password}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--reset", action="store_true", help="delete all existing data first")
    args = parser.parse_args()
    db = SessionLocal()
    try:
        if args.reset:
            reset(db)
        elif db.scalar(select(func.count(Restaurant.id))):
            sys.exit("Database already has data. Use --reset to wipe it and seed again.")
        creds = seed(db)
        counts = {m.__tablename__: db.scalar(select(func.count()).select_from(m))
                  for m in (Restaurant, MenuItem, Category, Offer, User)}
        print("Seeded:", ", ".join(f"{v} {k}" for k, v in counts.items()))
        print(f"Admin login: {creds['admin_email']} / {creds['admin_password']}  <- change in production")
        print(f"Demo customer: {catalog.DEMO_CUSTOMER['email']} / {catalog.DEMO_CUSTOMER['password']}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
