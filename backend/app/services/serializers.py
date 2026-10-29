"""ORM rows -> API response shapes (mobile contract)."""

import math
from decimal import Decimal

from app.core.config import get_settings
from app.models import (
    AddOn,
    Address,
    MenuItem,
    MenuItemVariant,
    Notification,
    Offer,
    Order,
    OrderStatus,
    Restaurant,
    User,
)
from app.schemas import public as s

SPICE_LEVELS = ["Mild", "Medium", "Extra Hot"]
PLACEHOLDER_IMAGE = ""

# DB enum value -> value the mobile app expects.
STATUS_TO_API = {
    OrderStatus.placed: "placed",
    OrderStatus.preparing: "preparing",
    OrderStatus.out_for_delivery: "outForDelivery",
    OrderStatus.delivered: "delivered",
    OrderStatus.cancelled: "cancelled",
}


def money(v: Decimal | float | int | None) -> float:
    return float(v or 0)


def reference_point(user: User | None) -> tuple[float, float]:
    """Distances are measured from the user's selected address when it has
    coordinates, otherwise from the configured city centre."""
    address = user.selected_address if user else None
    if address and address.latitude is not None and address.longitude is not None:
        return float(address.latitude), float(address.longitude)
    settings = get_settings()
    return settings.default_latitude, settings.default_longitude


def distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle (haversine) distance, rounded to 0.1 km."""
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return round(2 * r * math.asin(math.sqrt(a)), 1)


def delivery_time(r: Restaurant) -> str:
    return f"{r.delivery_time_min}-{r.delivery_time_max} mins"


def restaurant_distance(r: Restaurant, ref: tuple[float, float]) -> float:
    return distance_km(ref[0], ref[1], float(r.latitude), float(r.longitude))


def add_on_out(a: AddOn) -> s.AddOnOut:
    return s.AddOnOut(id=str(a.id), name=a.name, subtitle=a.subtitle, price=money(a.price))


def restaurant_out(r: Restaurant, ref: tuple[float, float]) -> s.RestaurantOut:
    available = [m for m in r.menu_items if m.is_available]
    tags = sorted({t for m in available for t in m.tags})
    return s.RestaurantOut(
        id=r.slug,
        name=r.name,
        cuisines=r.cuisines,
        rating=money(r.rating),
        delivery_time=delivery_time(r),
        cost_for_one=r.cost_for_one,
        distance_km=restaurant_distance(r, ref),
        image_url=r.image_url or PLACEHOLDER_IMAGE,
        is_pure_veg=r.is_pure_veg,
        delivery_fee=r.delivery_fee,
        badge=r.badge,
        popular=r.is_popular,
        menu_tags=tags,
        add_ons=[add_on_out(a) for a in r.add_ons if a.is_active],
        has_spice_levels=r.has_spice_levels,
    )


def variant_out(v: MenuItemVariant) -> s.VariantOut:
    return s.VariantOut(
        id=str(v.id), name=v.name, subtitle=v.subtitle, price=money(v.price_delta), is_default=v.is_default
    )


def menu_item_out(m: MenuItem) -> s.MenuItemOut:
    r = m.restaurant
    spicy = m.has_spice_levels and r.has_spice_levels
    return s.MenuItemOut(
        id=m.id,
        restaurant_id=r.slug,
        restaurant_name=r.name,
        category=m.category.name if m.category else None,
        name=m.name,
        description=m.description or "",
        price=money(m.price),
        image_url=m.image_url or PLACEHOLDER_IMAGE,
        is_veg=m.is_veg,
        is_available=m.is_available,
        rating=money(m.rating),
        rating_count=m.rating_count,
        prep_time=f"{m.prep_time_minutes} mins" if m.prep_time_minutes else "",
        calories=m.calories,
        cuisine=m.cuisine,
        tags=m.tags,
        meal_types=m.meal_types,
        ingredients=m.ingredients,
        difficulty=m.difficulty,
        servings=m.servings,
        badge=m.badge,
        portions=[variant_out(v) for v in m.variants],
        spice_levels=SPICE_LEVELS if spicy else [],
        add_ons=[add_on_out(a) for a in r.add_ons if a.is_active] if m.allows_add_ons else [],
    )


def address_out(a: Address) -> s.AddressOut:
    return s.AddressOut(
        id=str(a.id),
        label=a.label,
        line=a.line,
        icon=a.icon,
        is_default=a.is_default,
        latitude=float(a.latitude) if a.latitude is not None else None,
        longitude=float(a.longitude) if a.longitude is not None else None,
    )


def address_book_out(user: User) -> s.AddressBookOut:
    selected = user.selected_address_id
    if selected is None and user.addresses:
        default = next((a for a in user.addresses if a.is_default), user.addresses[0])
        selected = default.id
    return s.AddressBookOut(
        selected_id=str(selected) if selected is not None else None,
        items=[address_out(a) for a in user.addresses],
    )


def offer_out(o: Offer) -> s.OfferOut:
    return s.OfferOut(
        code=o.code,
        title=o.title,
        subtitle=o.subtitle,
        type=o.discount_type.value,
        value=money(o.value),
        max_discount=money(o.max_discount) if o.max_discount is not None else None,
        min_order=money(o.min_order),
        max_orders_per_user=o.valid_for_first_n_orders,
        image_url=o.image_url,
        featured=o.is_featured,
    )


def notification_out(n: Notification) -> s.NotificationOut:
    return s.NotificationOut(
        id=str(n.id), title=n.title, body=n.body, kind=n.kind.value, created_at=n.created_at
    )


def user_out(u: User) -> s.UserOut:
    return s.UserOut(id=str(u.id), name=u.full_name, email=u.email, phone=u.phone)


def order_out(o: Order, ref: tuple[float, float]) -> s.OrderOut:
    r = o.restaurant
    times: dict[str, object] = {}
    for event in o.status_history:
        times.setdefault(STATUS_TO_API[event.status], event.changed_at)
    lines = [
        s.CartLineOut(
            id=str(i.id),
            recipe_id=i.menu_item_id or 0,
            menu_item_id=i.menu_item_id or 0,
            restaurant_id=r.slug,
            name=i.name,
            image=i.image_url or PLACEHOLDER_IMAGE,
            is_veg=i.is_veg,
            unit_price=money(i.unit_price),
            quantity=i.quantity,
            portion=i.variant_name,
            spice_level=i.spice_level,
            add_ons=i.add_on_names,
            note=i.note,
        )
        for i in o.items
    ]
    return s.OrderOut(
        id=o.order_number,
        restaurant=s.OrderRestaurantOut(
            id=r.slug,
            name=r.name,
            image_url=r.image_url or PLACEHOLDER_IMAGE,
            distance_km=restaurant_distance(r, ref),
            delivery_time=delivery_time(r),
        ),
        items=lines,
        item_total=money(o.item_total),
        delivery_fee=money(o.delivery_fee),
        taxes=money(o.taxes),
        discount=money(o.discount),
        amount=money(o.total),
        coupon_code=o.coupon_code,
        instructions=o.instructions,
        address=s.AddressOut(
            id="snapshot",
            label=o.address_label,
            line=o.address_line,
            icon="home",
            is_default=False,
        ),
        payment_method=o.payment_method.value,
        payment_status=o.payment_status.value,
        placed_at=o.placed_at,
        eta=o.eta,
        status=STATUS_TO_API[o.status],
        status_times=times,
    )
