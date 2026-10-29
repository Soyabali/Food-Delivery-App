import secrets
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.models import (
    Order,
    OrderItem,
    OrderStatus,
    OrderStatusHistory,
    PaymentMethod,
    PaymentStatus,
    User,
)
from app.services import cart_service

# Which status changes the dashboard may make.
ALLOWED_TRANSITIONS: dict[OrderStatus, set[OrderStatus]] = {
    OrderStatus.placed: {OrderStatus.preparing, OrderStatus.cancelled},
    OrderStatus.preparing: {OrderStatus.out_for_delivery, OrderStatus.cancelled},
    OrderStatus.out_for_delivery: {OrderStatus.delivered, OrderStatus.cancelled},
    OrderStatus.delivered: set(),
    OrderStatus.cancelled: set(),
}


def _new_order_number(db: Session) -> str:
    while True:
        number = f"AF-{secrets.randbelow(90000) + 10000}"
        if db.scalar(select(Order.id).where(Order.order_number == number)) is None:
            return number


def place_order(db: Session, user: User, address_id: str, payment_method: str) -> Order:
    cart = cart_service.get_or_create_cart(db, user)
    if not cart.items:
        raise ApiError(400, "Your cart is empty.")
    address = next((a for a in user.addresses if str(a.id) == address_id), None)
    if address is None:
        raise ApiError(400, "Please choose a delivery address.")
    restaurant = cart.restaurant
    if restaurant is None or not restaurant.is_active:
        raise ApiError(400, "This restaurant is not accepting orders right now.")
    unavailable = [i.menu_item.name for i in cart.items if not i.menu_item.is_available]
    if unavailable:
        raise ApiError(400, f"No longer available: {', '.join(unavailable)}. Please remove it from your cart.")

    totals = cart_service.compute_totals(db, user, cart)
    now = datetime.now(UTC)
    method = PaymentMethod(payment_method)
    order = Order(
        order_number=_new_order_number(db),
        user_id=user.id,
        restaurant_id=restaurant.id,
        status=OrderStatus.placed,
        payment_method=method,
        # No gateway yet: online methods are recorded as pending until a
        # payment provider confirms them.
        payment_status=PaymentStatus.pending,
        address_label=address.label,
        address_line=address.line,
        address_latitude=address.latitude,
        address_longitude=address.longitude,
        item_total=totals.item_total,
        delivery_fee=totals.delivery_fee,
        taxes=totals.taxes,
        discount=totals.discount,
        total=totals.total,
        offer_id=cart.offer_id if totals.discount > 0 else None,
        coupon_code=cart.offer.code if cart.offer and totals.discount > 0 else None,
        instructions=cart.instructions or None,
        placed_at=now,
        eta=now + timedelta(minutes=restaurant.delivery_time_max),
    )
    for line in cart.items:
        price = cart_service.unit_price(line)
        order.items.append(
            OrderItem(
                menu_item_id=line.menu_item_id,
                name=line.menu_item.name,
                image_url=line.menu_item.image_url,
                is_veg=line.menu_item.is_veg,
                variant_name=line.variant.name if line.variant else None,
                spice_level=line.spice_level,
                add_on_names=[a.name for a in line.add_ons],
                note=line.note,
                unit_price=price,
                quantity=line.quantity,
                line_total=price * line.quantity,
            )
        )
    order.status_history.append(OrderStatusHistory(status=OrderStatus.placed, changed_at=now))
    db.add(order)

    # Empty the cart in the same transaction.
    cart.items.clear()
    cart.offer_id = None
    cart.instructions = ""
    db.commit()
    db.refresh(order)
    return order


def change_status(
    db: Session, order: Order, new_status: OrderStatus, changed_by: User, note: str | None
) -> Order:
    if new_status == order.status:
        return order
    if new_status not in ALLOWED_TRANSITIONS[order.status]:
        raise ApiError(
            400, f"Can't change an order from {order.status.value} to {new_status.value}."
        )
    now = datetime.now(UTC)
    order.status = new_status
    if new_status == OrderStatus.delivered:
        order.delivered_at = now
        if order.payment_method == PaymentMethod.cod:
            order.payment_status = PaymentStatus.paid
    order.status_history.append(
        OrderStatusHistory(status=new_status, changed_by_user_id=changed_by.id, note=note, changed_at=now)
    )
    db.commit()
    db.refresh(order)
    return order
