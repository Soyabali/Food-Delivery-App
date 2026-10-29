"""Dashboard CRUD for restaurants, menu items and categories."""

from typing import Annotated

from fastapi import APIRouter, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.api.deps import AdminUser, DbSession
from app.api.routes.admin.common import apply_patch, paginate, sync_children
from app.core.errors import ApiError
from app.models import AddOn, Category, MenuItem, MenuItemVariant, Restaurant
from app.schemas import admin as a
from app.schemas.common import Page

router = APIRouter(tags=["admin: catalogue"])


def _commit(db, conflict_message: str) -> None:
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise ApiError(409, conflict_message) from exc


def _check_times(r: Restaurant) -> None:
    if r.delivery_time_max < r.delivery_time_min:
        raise ApiError(400, "deliveryTimeMax must be >= deliveryTimeMin.")


# ----------------------------------------------------------- restaurants


def _restaurant_out(db, r: Restaurant) -> a.AdminRestaurantOut:
    count = db.scalar(select(func.count(MenuItem.id)).where(MenuItem.restaurant_id == r.id)) or 0
    return a.AdminRestaurantOut.model_validate(
        {
            **{c.key: getattr(r, c.key) for c in Restaurant.__table__.columns},
            "menu_item_count": count,
            "add_ons": r.add_ons,
        }
    )


def _get_restaurant(db, restaurant_id: int) -> Restaurant:
    r = db.get(Restaurant, restaurant_id, options=[selectinload(Restaurant.add_ons)])
    if r is None:
        raise ApiError(404, "Restaurant not found.")
    return r


@router.get("/restaurants", response_model=Page[a.AdminRestaurantOut])
def list_restaurants(
    db: DbSession,
    _: AdminUser,
    q: str | None = None,
    active: bool | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100, alias="pageSize")] = 20,
):
    stmt = select(Restaurant).options(selectinload(Restaurant.add_ons)).order_by(Restaurant.id)
    if q:
        stmt = stmt.where(or_(Restaurant.name.ilike(f"%{q}%"), Restaurant.slug.ilike(f"%{q}%")))
    if active is not None:
        stmt = stmt.where(Restaurant.is_active.is_(active))
    rows, total = paginate(db, stmt, page, page_size)
    return Page(items=[_restaurant_out(db, r) for r in rows], total=total, page=page, page_size=page_size)


@router.post("/restaurants", response_model=a.AdminRestaurantOut, status_code=status.HTTP_201_CREATED)
def create_restaurant(body: a.RestaurantIn, db: DbSession, _: AdminUser):
    data = body.model_dump(exclude={"add_ons"})
    r = Restaurant(**data)
    r.add_ons = [AddOn(**x.model_dump(exclude={"id"})) for x in body.add_ons]
    _check_times(r)
    db.add(r)
    _commit(db, f"Slug '{body.slug}' is already used by another restaurant.")
    return _restaurant_out(db, _get_restaurant(db, r.id))


@router.get("/restaurants/{restaurant_id}", response_model=a.AdminRestaurantOut)
def get_restaurant(restaurant_id: int, db: DbSession, _: AdminUser):
    return _restaurant_out(db, _get_restaurant(db, restaurant_id))


@router.patch("/restaurants/{restaurant_id}", response_model=a.AdminRestaurantOut)
def update_restaurant(restaurant_id: int, body: a.RestaurantPatch, db: DbSession, _: AdminUser):
    r = _get_restaurant(db, restaurant_id)
    apply_patch(r, body, exclude={"add_ons"})
    _check_times(r)
    if body.add_ons is not None:
        sync_children(r.add_ons, body.add_ons, lambda d: AddOn(**d), "Add-on")
    _commit(db, "That slug is already used by another restaurant.")
    return _restaurant_out(db, _get_restaurant(db, restaurant_id))


@router.delete("/restaurants/{restaurant_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_restaurant(restaurant_id: int, db: DbSession, _: AdminUser):
    """Restaurants with order history are deactivated instead of deleted."""
    r = _get_restaurant(db, restaurant_id)
    try:
        db.delete(r)
        db.commit()
    except IntegrityError:
        db.rollback()
        r = _get_restaurant(db, restaurant_id)
        r.is_active = False
        db.commit()


# ------------------------------------------------------------ menu items


def _menu_item_out(m: MenuItem) -> a.AdminMenuItemOut:
    return a.AdminMenuItemOut.model_validate(
        {
            **{c.key: getattr(m, c.key) for c in MenuItem.__table__.columns},
            "restaurant_name": m.restaurant.name,
            "category_name": m.category.name if m.category else None,
            "variants": m.variants,
        }
    )


def _get_item(db, item_id: int) -> MenuItem:
    m = db.get(
        MenuItem,
        item_id,
        options=[selectinload(MenuItem.variants), selectinload(MenuItem.restaurant), selectinload(MenuItem.category)],
    )
    if m is None:
        raise ApiError(404, "Menu item not found.")
    return m


def _check_refs(db, restaurant_id: int | None, category_id: int | None) -> None:
    if restaurant_id is not None and db.get(Restaurant, restaurant_id) is None:
        raise ApiError(400, f"Restaurant {restaurant_id} does not exist.")
    if category_id is not None and db.get(Category, category_id) is None:
        raise ApiError(400, f"Category {category_id} does not exist.")


def _check_variants(variants) -> None:
    if sum(1 for v in variants if v.is_default) > 1:
        raise ApiError(400, "Only one portion can be the default.")


@router.get("/menu-items", response_model=Page[a.AdminMenuItemOut])
def list_menu_items(
    db: DbSession,
    _: AdminUser,
    q: str | None = None,
    restaurant_id: Annotated[int | None, Query(alias="restaurantId")] = None,
    category_id: Annotated[int | None, Query(alias="categoryId")] = None,
    available: bool | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100, alias="pageSize")] = 20,
):
    stmt = select(MenuItem).options(
        selectinload(MenuItem.variants), selectinload(MenuItem.restaurant), selectinload(MenuItem.category)
    )
    if q:
        stmt = stmt.where(MenuItem.name.ilike(f"%{q}%"))
    if restaurant_id is not None:
        stmt = stmt.where(MenuItem.restaurant_id == restaurant_id)
    if category_id is not None:
        stmt = stmt.where(MenuItem.category_id == category_id)
    if available is not None:
        stmt = stmt.where(MenuItem.is_available.is_(available))
    rows, total = paginate(db, stmt.order_by(MenuItem.id), page, page_size)
    return Page(items=[_menu_item_out(m) for m in rows], total=total, page=page, page_size=page_size)


@router.post("/menu-items", response_model=a.AdminMenuItemOut, status_code=status.HTTP_201_CREATED)
def create_menu_item(body: a.MenuItemIn, db: DbSession, _: AdminUser):
    _check_refs(db, body.restaurant_id, body.category_id)
    _check_variants(body.variants)
    m = MenuItem(**body.model_dump(exclude={"variants"}))
    m.variants = [MenuItemVariant(**v.model_dump(exclude={"id"})) for v in body.variants]
    db.add(m)
    db.commit()
    return _menu_item_out(_get_item(db, m.id))


@router.get("/menu-items/{item_id}", response_model=a.AdminMenuItemOut)
def get_menu_item(item_id: int, db: DbSession, _: AdminUser):
    return _menu_item_out(_get_item(db, item_id))


@router.patch("/menu-items/{item_id}", response_model=a.AdminMenuItemOut)
def update_menu_item(item_id: int, body: a.MenuItemPatch, db: DbSession, _: AdminUser):
    m = _get_item(db, item_id)
    sent = body.model_dump(exclude_unset=True)
    _check_refs(db, sent.get("restaurant_id"), sent.get("category_id"))
    apply_patch(m, body, exclude={"variants"})
    if body.variants is not None:
        _check_variants(body.variants)
        # Clear defaults first so the partial unique index never sees two.
        for v in m.variants:
            v.is_default = False
        db.flush()
        sync_children(m.variants, body.variants, lambda d: MenuItemVariant(**d), "Portion")
    db.commit()
    return _menu_item_out(_get_item(db, item_id))


@router.delete("/menu-items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_menu_item(item_id: int, db: DbSession, _: AdminUser):
    """Order history keeps its own snapshot (order_items.menu_item_id is set NULL)."""
    m = _get_item(db, item_id)
    db.delete(m)
    db.commit()


# ------------------------------------------------------------- categories


def _category_out(db, c: Category) -> a.AdminCategoryOut:
    count = db.scalar(select(func.count(MenuItem.id)).where(MenuItem.category_id == c.id)) or 0
    return a.AdminCategoryOut.model_validate(
        {**{col.key: getattr(c, col.key) for col in Category.__table__.columns}, "menu_item_count": count}
    )


def _get_category(db, category_id: int) -> Category:
    c = db.get(Category, category_id)
    if c is None:
        raise ApiError(404, "Category not found.")
    return c


@router.get("/categories", response_model=list[a.AdminCategoryOut])
def list_categories(db: DbSession, _: AdminUser):
    rows = db.scalars(select(Category).order_by(Category.sort_order, Category.name))
    return [_category_out(db, c) for c in rows]


@router.post("/categories", response_model=a.AdminCategoryOut, status_code=status.HTTP_201_CREATED)
def create_category(body: a.CategoryIn, db: DbSession, _: AdminUser):
    c = Category(**body.model_dump())
    db.add(c)
    _commit(db, "A category with that name or slug already exists.")
    return _category_out(db, c)


@router.patch("/categories/{category_id}", response_model=a.AdminCategoryOut)
def update_category(category_id: int, body: a.CategoryPatch, db: DbSession, _: AdminUser):
    c = _get_category(db, category_id)
    apply_patch(c, body)
    _commit(db, "A category with that name or slug already exists.")
    return _category_out(db, c)


@router.delete("/categories/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(category_id: int, db: DbSession, _: AdminUser):
    """Dishes in this category keep existing with no category."""
    db.delete(_get_category(db, category_id))
    db.commit()

