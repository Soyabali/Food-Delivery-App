from typing import Annotated, Literal

from fastapi import APIRouter, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import selectinload

from app.api.deps import DbSession, OptionalUser
from app.core.errors import ApiError
from app.models import Category, MenuItem, Notification, Offer, Restaurant
from app.schemas import public as s
from app.services import serializers as ser

router = APIRouter(tags=["catalogue"])


def _restaurants_query():
    return (
        select(Restaurant)
        .where(Restaurant.is_active.is_(True))
        .options(selectinload(Restaurant.add_ons), selectinload(Restaurant.menu_items))
    )


@router.get("/restaurants", response_model=list[s.RestaurantOut])
def list_restaurants(
    db: DbSession,
    user: OptionalUser,
    popular: bool = False,
    sort: Literal["distance", "rating"] | None = None,
    q: Annotated[str | None, Query(max_length=60)] = None,
):
    stmt = _restaurants_query()
    if popular:
        stmt = stmt.where(Restaurant.is_popular.is_(True))
    if q and q.strip():
        term = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(Restaurant.name.ilike(term), func.array_to_string(Restaurant.cuisines, " ").ilike(term))
        )
    ref = ser.reference_point(user)
    items = [ser.restaurant_out(r, ref) for r in db.scalars(stmt.order_by(Restaurant.id))]
    if sort == "distance":
        items.sort(key=lambda r: r.distance_km)
    elif sort == "rating":
        items.sort(key=lambda r: -r.rating)
    return items


@router.get("/restaurants/{slug}", response_model=s.RestaurantOut)
def get_restaurant(slug: str, db: DbSession, user: OptionalUser):
    r = db.scalar(_restaurants_query().where(Restaurant.slug == slug))
    if r is None:
        raise ApiError(404, "This restaurant is no longer available.")
    return ser.restaurant_out(r, ser.reference_point(user))


def _menu_query():
    return (
        select(MenuItem)
        .join(MenuItem.restaurant)
        .where(MenuItem.is_available.is_(True), Restaurant.is_active.is_(True))
        .options(
            selectinload(MenuItem.restaurant).selectinload(Restaurant.add_ons),
            selectinload(MenuItem.category),
            selectinload(MenuItem.variants),
        )
    )


@router.get("/restaurants/{slug}/menu", response_model=list[s.MenuItemOut])
def restaurant_menu(slug: str, db: DbSession):
    exists = db.scalar(select(Restaurant.id).where(Restaurant.slug == slug, Restaurant.is_active.is_(True)))
    if exists is None:
        raise ApiError(404, "This restaurant is no longer available.")
    stmt = _menu_query().where(Restaurant.slug == slug).order_by(MenuItem.sort_order, MenuItem.id)
    return [ser.menu_item_out(m) for m in db.scalars(stmt)]


@router.get("/menu-items", response_model=list[s.MenuItemOut])
def search_menu_items(
    db: DbSession,
    q: Annotated[str | None, Query(max_length=60, description="Search dish name, cuisine or tag")] = None,
    category: Annotated[str | None, Query(description="Category slug or name")] = None,
    tag: str | None = None,
    meal_type: Annotated[str | None, Query(alias="mealType")] = None,
    restaurant: Annotated[str | None, Query(description="Restaurant slug")] = None,
    veg: bool | None = None,
    sort: Literal["rating", "price", "name"] = "rating",
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
):
    stmt = _menu_query()
    if q and q.strip():
        term = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(
                MenuItem.name.ilike(term),
                MenuItem.cuisine.ilike(term),
                func.array_to_string(MenuItem.tags, " ").ilike(term),
            )
        )
    if category:
        # The app links categories by display name; the dashboard by slug.
        stmt = stmt.join(MenuItem.category).where(
            or_(Category.slug == category, func.lower(Category.name) == category.strip().lower())
        )
    if tag:
        stmt = stmt.where(MenuItem.tags.contains([tag]))  # uses the GIN index
    if meal_type:
        stmt = stmt.where(MenuItem.meal_types.contains([meal_type.title()]))
    if restaurant:
        stmt = stmt.where(Restaurant.slug == restaurant)
    if veg is not None:
        stmt = stmt.where(MenuItem.is_veg.is_(veg))
    order = {
        "rating": (MenuItem.rating.desc(), MenuItem.rating_count.desc()),
        "price": (MenuItem.price.asc(),),
        "name": (MenuItem.name.asc(),),
    }[sort]
    return [ser.menu_item_out(m) for m in db.scalars(stmt.order_by(*order, MenuItem.id).limit(limit))]


@router.get("/menu-items/{item_id}", response_model=s.MenuItemOut)
def get_menu_item(item_id: int, db: DbSession):
    m = db.scalar(_menu_query().where(MenuItem.id == item_id))
    if m is None:
        raise ApiError(404, "This dish is no longer on the menu.")
    return ser.menu_item_out(m)


@router.get("/categories", response_model=list[s.CategoryOut])
def list_categories(db: DbSession):
    stmt = select(Category).where(Category.is_active.is_(True)).order_by(Category.sort_order, Category.name)
    return [s.CategoryOut.model_validate(c) for c in db.scalars(stmt)]


@router.get("/offers", response_model=list[s.OfferOut])
def list_offers(db: DbSession):
    stmt = (
        select(Offer)
        .where(
            Offer.is_active.is_(True),
            (Offer.starts_at.is_(None)) | (Offer.starts_at <= func.now()),
            (Offer.ends_at.is_(None)) | (Offer.ends_at > func.now()),
        )
        .order_by(Offer.is_featured.desc(), Offer.id)
    )
    return [ser.offer_out(o) for o in db.scalars(stmt)]


@router.get("/notifications", response_model=list[s.NotificationOut])
def list_notifications(db: DbSession, user: OptionalUser):
    """Broadcast notifications plus, when signed in, the user's own."""
    cond = Notification.user_id.is_(None)
    if user is not None:
        cond = cond | (Notification.user_id == user.id)
    stmt = select(Notification).where(cond).order_by(Notification.created_at.desc()).limit(50)
    return [ser.notification_out(n) for n in db.scalars(stmt)]
