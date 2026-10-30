from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Numeric,
    SmallInteger,
    String,
    Table,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.catalog import AddOn, MenuItem, MenuItemVariant, Restaurant
from app.models.engagement import Offer
from app.models.enums import OrderStatus, PaymentMethod, PaymentStatus

# Many-to-many: which add-ons were chosen for a cart line.
cart_item_add_ons = Table(
    "cart_item_add_ons",
    Base.metadata,
    Column("cart_item_id", ForeignKey("cart_items.id", ondelete="CASCADE"), primary_key=True),
    Column("add_on_id", ForeignKey("add_ons.id", ondelete="CASCADE"), primary_key=True),
)


class Cart(Base):
    """One active cart per user. Holds items from a single restaurant."""

    __tablename__ = "carts"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    restaurant_id: Mapped[int | None] = mapped_column(
        ForeignKey("restaurants.id", ondelete="SET NULL")
    )
    offer_id: Mapped[int | None] = mapped_column(ForeignKey("offers.id", ondelete="SET NULL"))
    instructions: Mapped[str] = mapped_column(String(150), nullable=False, server_default="")
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    restaurant: Mapped[Restaurant | None] = relationship()
    offer: Mapped[Offer | None] = relationship()
    items: Mapped[list[CartItem]] = relationship(
        back_populates="cart", cascade="all, delete-orphan", order_by="CartItem.id"
    )


class CartItem(Base):
    __tablename__ = "cart_items"
    __table_args__ = (CheckConstraint("quantity BETWEEN 1 AND 20", name="quantity_range"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    cart_id: Mapped[int] = mapped_column(
        ForeignKey("carts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    menu_item_id: Mapped[int] = mapped_column(
        ForeignKey("menu_items.id", ondelete="CASCADE"), nullable=False
    )
    variant_id: Mapped[int | None] = mapped_column(
        ForeignKey("menu_item_variants.id", ondelete="SET NULL")
    )
    spice_level: Mapped[str | None] = mapped_column(String(20))
    quantity: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    note: Mapped[str | None] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    cart: Mapped[Cart] = relationship(back_populates="items")
    menu_item: Mapped[MenuItem] = relationship()
    variant: Mapped[MenuItemVariant | None] = relationship()
    add_ons: Mapped[list[AddOn]] = relationship(secondary=cart_item_add_ons, order_by="AddOn.id")


class Order(TimestampMixin, Base):
    """A placed order. Prices and address are snapshots taken at checkout,
    so later menu/address edits never change history."""

    __tablename__ = "orders"
    __table_args__ = (
        CheckConstraint("item_total >= 0 AND delivery_fee >= 0 AND taxes >= 0", name="amounts_positive"),
        CheckConstraint("discount >= 0 AND total >= 0", name="totals_positive"),
        Index("ix_orders_user_placed", "user_id", "placed_at"),
        Index("ix_orders_status_placed", "status", "placed_at"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    order_number: Mapped[str] = mapped_column(String(20), nullable=False, unique=True)  # AF-12345
    # NULL once the customer deletes their account: the order is kept,
    # anonymised, for accounting (see services/account_deletion.py).
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    status: Mapped[OrderStatus] = mapped_column(
        Enum(OrderStatus, name="order_status"), nullable=False, server_default=OrderStatus.placed.value
    )
    payment_method: Mapped[PaymentMethod] = mapped_column(
        Enum(PaymentMethod, name="payment_method"), nullable=False
    )
    payment_status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus, name="payment_status"),
        nullable=False,
        server_default=PaymentStatus.pending.value,
    )
    # Delivery address snapshot
    address_label: Mapped[str] = mapped_column(String(40), nullable=False)
    address_line: Mapped[str] = mapped_column(String(300), nullable=False)
    address_latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    address_longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    # Money snapshot (rupees)
    item_total: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    delivery_fee: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    taxes: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    discount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, server_default="0")
    total: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    offer_id: Mapped[int | None] = mapped_column(ForeignKey("offers.id", ondelete="SET NULL"))
    coupon_code: Mapped[str | None] = mapped_column(String(30))
    instructions: Mapped[str | None] = mapped_column(String(150))
    placed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    eta: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    user: Mapped["User | None"] = relationship()  # noqa: F821 - resolved by name
    restaurant: Mapped[Restaurant] = relationship()
    items: Mapped[list[OrderItem]] = relationship(
        back_populates="order", cascade="all, delete-orphan", order_by="OrderItem.id"
    )
    status_history: Mapped[list[OrderStatusHistory]] = relationship(
        back_populates="order", cascade="all, delete-orphan", order_by="OrderStatusHistory.id"
    )


class OrderItem(Base):
    __tablename__ = "order_items"
    __table_args__ = (
        CheckConstraint("quantity BETWEEN 1 AND 20", name="quantity_range"),
        CheckConstraint("unit_price >= 0 AND line_total >= 0", name="amounts_positive"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    order_id: Mapped[int] = mapped_column(
        ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Kept for reporting; NULL if the dish is later deleted.
    menu_item_id: Mapped[int | None] = mapped_column(
        ForeignKey("menu_items.id", ondelete="SET NULL"), index=True
    )
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    image_url: Mapped[str | None] = mapped_column(String(500))
    is_veg: Mapped[bool] = mapped_column(nullable=False)
    variant_name: Mapped[str | None] = mapped_column(String(60))
    spice_level: Mapped[str | None] = mapped_column(String(20))
    add_on_names: Mapped[list[str]] = mapped_column(
        ARRAY(String(80)), nullable=False, server_default="{}"
    )
    note: Mapped[str | None] = mapped_column(String(120))
    unit_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    quantity: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    line_total: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)

    order: Mapped[Order] = relationship(back_populates="items")


class OrderStatusHistory(Base):
    """Every status change (who/when) — powers the tracking timeline."""

    __tablename__ = "order_status_history"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    order_id: Mapped[int] = mapped_column(
        ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status: Mapped[OrderStatus] = mapped_column(Enum(OrderStatus, name="order_status"), nullable=False)
    changed_by_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    note: Mapped[str | None] = mapped_column(String(200))
    changed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    order: Mapped[Order] = relationship(back_populates="status_history")

