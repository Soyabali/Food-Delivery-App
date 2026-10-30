"""Deleting a customer account (the public /delete-account flow).

Deleted: the user row and, through ON DELETE CASCADE, their addresses,
sessions, password reset and deletion codes, cart, favourites and personal
notifications.

Kept, anonymised: orders are business and tax records, so they stay with the
customer link removed (orders.user_id -> NULL) and the personal parts
(delivery address, coordinates, instructions, per-item notes) cleared.
Order number, restaurant, items, amounts and dates remain.
"""

import logging

from sqlalchemy import select, update

from app.models import Order, OrderItem, OrderStatus, User, UserRole

log = logging.getLogger("apna_food.account_deletion")

ANONYMISED_ADDRESS_LABEL = "Deleted"
ANONYMISED_ADDRESS_LINE = "Removed (customer deleted their account)"

ACTIVE_STATUSES = (OrderStatus.placed, OrderStatus.preparing, OrderStatus.out_for_delivery)


class DeletionBlocked(Exception):
    """The account can't be deleted right now; the message says why."""


def check_deletable(db, user: User) -> None:
    if user.role == UserRole.admin:
        raise DeletionBlocked(
            "Admin accounts can't be deleted here. Ask another admin to remove your access first."
        )
    active = db.scalar(
        select(Order.order_number).where(Order.user_id == user.id, Order.status.in_(ACTIVE_STATUSES)).limit(1)
    )
    if active:
        raise DeletionBlocked(
            f"Order {active} is still in progress. You can delete your account once it is delivered or cancelled."
        )


def delete_account(db, user: User) -> None:
    """Deletes `user` in the caller's transaction (commit/rollback is theirs)."""
    check_deletable(db, user)
    order_ids = select(Order.id).where(Order.user_id == user.id)
    db.execute(update(OrderItem).where(OrderItem.order_id.in_(order_ids)).values(note=None))
    db.execute(
        update(Order)
        .where(Order.user_id == user.id)
        .values(
            user_id=None,
            address_label=ANONYMISED_ADDRESS_LABEL,
            address_line=ANONYMISED_ADDRESS_LINE,
            address_latitude=None,
            address_longitude=None,
            instructions=None,
        )
    )
    user_id = user.id
    # The ORM delete also clears users.selected_address_id -> addresses first.
    db.delete(user)
    db.flush()
    log.info("Account %s deleted; orders anonymised", user_id)
