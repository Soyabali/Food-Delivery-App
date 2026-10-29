"""Server-side cart: pricing, coupons and totals come from the database,
never from the client."""

from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import ApiError
from app.models import (
    AddOn,
    Cart,
    CartItem,
    DiscountType,
    MenuItem,
    MenuItemVariant,
    Offer,
    Order,
    OrderStatus,
    User,
)
from app.schemas import public as s
from app.services import serializers as ser

CENT = Decimal("0.01")


def get_or_create_cart(db: Session, user: User) -> Cart:
    cart = db.scalar(select(Cart).where(Cart.user_id == user.id))
    if cart is None:
        cart = Cart(user_id=user.id, instructions="")
        db.add(cart)
        db.flush()
    return cart


def unit_price(item: CartItem) -> Decimal:
    price = item.menu_item.price + (item.variant.price_delta if item.variant else 0)
    return price + sum((a.price for a in item.add_ons), Decimal(0))


@dataclass
class Totals:
    item_total: Decimal
    delivery_fee: Decimal
    standard_fee: Decimal
    taxes: Decimal
    discount: Decimal
    total: Decimal
    savings: Decimal
    coupon_message: str | None


def coupon_discount(
    db: Session, user: User, offer: Offer | None, item_total: Decimal
) -> tuple[Decimal, str | None]:
    if offer is None or item_total == 0:
        return Decimal(0), None
    if not offer.is_active:
        return Decimal(0), f"{offer.code} is no longer valid."
    if item_total < offer.min_order:
        missing = (offer.min_order - item_total).quantize(Decimal(1), ROUND_HALF_UP)
        return Decimal(0), f"Add ₹{missing} more to use {offer.code}"
    if offer.valid_for_first_n_orders is not None:
        orders = db.scalar(
            select(func.count(Order.id)).where(
                Order.user_id == user.id, Order.status != OrderStatus.cancelled
            )
        )
        if orders >= offer.valid_for_first_n_orders:
            return Decimal(0), f"{offer.code} is only valid on your first {offer.valid_for_first_n_orders} orders"
    if offer.discount_type == DiscountType.percent:
        discount = (item_total * offer.value / 100).quantize(Decimal(1), rounding="ROUND_FLOOR")
        if offer.max_discount is not None:
            discount = min(discount, offer.max_discount)
    else:
        discount = offer.value
    return min(discount, item_total), None


def compute_totals(db: Session, user: User, cart: Cart) -> Totals:
    settings = get_settings()
    item_total = sum((unit_price(i) * i.quantity for i in cart.items), Decimal(0))
    restaurant = cart.restaurant
    fee = Decimal(restaurant.delivery_fee) if restaurant else Decimal(0)
    standard_fee = fee if fee > 0 else Decimal(settings.standard_delivery_fee)
    empty = not cart.items
    free = item_total >= settings.free_delivery_threshold
    delivery_fee = Decimal(0) if empty or free else standard_fee
    taxes = (item_total * Decimal(str(settings.tax_rate_percent)) / 100).quantize(CENT, ROUND_HALF_UP)
    discount, message = coupon_discount(db, user, cart.offer, item_total)
    total = max(Decimal(0), item_total + delivery_fee + taxes - discount)
    return Totals(
        item_total=item_total,
        delivery_fee=delivery_fee,
        standard_fee=Decimal(0) if empty else standard_fee,
        taxes=taxes,
        discount=discount,
        total=total,
        savings=discount + (standard_fee if free and not empty else Decimal(0)),
        coupon_message=message,
    )


def cart_out(db: Session, user: User, cart: Cart) -> s.CartOut:
    settings = get_settings()
    totals = compute_totals(db, user, cart)
    restaurant = cart.restaurant if cart.items else None
    ref = ser.reference_point(user)
    return s.CartOut(
        items=[
            s.CartLineOut(
                id=str(i.id),
                recipe_id=i.menu_item_id,
                menu_item_id=i.menu_item_id,
                restaurant_id=i.menu_item.restaurant.slug,
                name=i.menu_item.name,
                image=i.menu_item.image_url or "",
                is_veg=i.menu_item.is_veg,
                unit_price=ser.money(unit_price(i)),
                quantity=i.quantity,
                portion=i.variant.name if i.variant else None,
                spice_level=i.spice_level,
                add_ons=[a.name for a in i.add_ons],
                note=i.note,
            )
            for i in cart.items
        ],
        restaurant=s.CartRestaurantOut(
            id=restaurant.slug,
            name=restaurant.name,
            distance_km=ser.restaurant_distance(restaurant, ref),
        )
        if restaurant
        else None,
        coupon_code=cart.offer.code if cart.offer else None,
        coupon_message=totals.coupon_message,
        instructions=cart.instructions,
        totals=s.CartTotalsOut(
            item_total=ser.money(totals.item_total),
            delivery_fee=ser.money(totals.delivery_fee),
            standard_delivery_fee=ser.money(totals.standard_fee),
            free_delivery_threshold=settings.free_delivery_threshold,
            taxes=ser.money(totals.taxes),
            tax_rate_percent=settings.tax_rate_percent,
            discount=ser.money(totals.discount),
            total=ser.money(totals.total),
            savings=ser.money(totals.savings),
        ),
    )


def _resolve_variant(item: MenuItem, body: s.AddCartItemIn) -> MenuItemVariant | None:
    if body.variant_id is not None:
        v = next((v for v in item.variants if v.id == body.variant_id), None)
        if v is None:
            raise ApiError(400, "That portion is not available for this dish.")
        return v
    if body.portion:
        v = next((v for v in item.variants if v.name.lower() == body.portion.lower()), None)
        if v is None:
            raise ApiError(400, f"Portion '{body.portion}' is not available for this dish.")
        return v
    return next((v for v in item.variants if v.is_default), item.variants[0] if item.variants else None)


def _resolve_add_ons(db: Session, item: MenuItem, body: s.AddCartItemIn) -> list[AddOn]:
    wants = bool(body.add_on_ids or body.add_ons)
    if wants and not item.allows_add_ons:
        raise ApiError(400, "Extras can't be added to this dish.")
    available = {a.id: a for a in item.restaurant.add_ons if a.is_active}
    if body.add_on_ids:
        missing = [i for i in body.add_on_ids if i not in available]
        if missing:
            raise ApiError(400, "Some selected extras are not available.")
        return sorted((available[i] for i in set(body.add_on_ids)), key=lambda a: a.id)
    if body.add_ons:
        by_name = {a.name.lower(): a for a in available.values()}
        chosen = []
        for name in body.add_ons:
            a = by_name.get(name.lower())
            if a is None:
                raise ApiError(400, f"Extra '{name}' is not available.")
            chosen.append(a)
        return sorted(set(chosen), key=lambda a: a.id)
    return []


def add_item(db: Session, user: User, body: s.AddCartItemIn) -> Cart:
    if body.item_id is None:
        raise ApiError(400, "menuItemId is required.")
    item = db.get(MenuItem, body.item_id)
    if item is None or not item.restaurant.is_active:
        raise ApiError(404, "This dish is no longer on the menu.")
    if not item.is_available:
        raise ApiError(400, f"{item.name} is currently unavailable.")
    if body.spice_level and not (item.has_spice_levels and item.restaurant.has_spice_levels):
        raise ApiError(400, "Spice level can't be chosen for this dish.")
    if body.spice_level and body.spice_level not in ser.SPICE_LEVELS:
        raise ApiError(400, "Unknown spice level.")

    variant = _resolve_variant(item, body)
    add_ons = _resolve_add_ons(db, item, body)

    cart = get_or_create_cart(db, user)
    if cart.items and cart.restaurant_id != item.restaurant_id:
        if not body.replace_cart:
            raise ApiError(409, "Your cart has items from another restaurant.")
        cart.items.clear()
        cart.instructions = ""
    cart.restaurant_id = item.restaurant_id

    key = (item.id, variant.id if variant else None, body.spice_level, tuple(a.id for a in add_ons), body.note)
    for line in cart.items:
        line_key = (
            line.menu_item_id,
            line.variant_id,
            line.spice_level,
            tuple(sorted(a.id for a in line.add_ons)),
            line.note,
        )
        if line_key == key:
            line.quantity = min(20, line.quantity + body.quantity)
            break
    else:
        cart.items.append(
            CartItem(
                menu_item=item,
                variant=variant,
                spice_level=body.spice_level,
                quantity=body.quantity,
                note=body.note,
                add_ons=add_ons,
            )
        )
    db.commit()
    db.refresh(cart)
    return cart


def find_line(cart: Cart, line_id: str) -> CartItem:
    line = next((i for i in cart.items if str(i.id) == line_id), None)
    if line is None:
        raise ApiError(404, "That item is no longer in your cart.")
    return line


def apply_coupon(db: Session, user: User, code: str) -> Cart:
    offer = db.scalar(
        select(Offer).where(
            Offer.code == code.strip().upper(),
            Offer.is_active.is_(True),
            (Offer.starts_at.is_(None)) | (Offer.starts_at <= func.now()),
            (Offer.ends_at.is_(None)) | (Offer.ends_at > func.now()),
        )
    )
    if offer is None:
        raise ApiError(400, "Invalid coupon code.")
    cart = get_or_create_cart(db, user)
    cart.offer = offer
    db.commit()
    return cart
