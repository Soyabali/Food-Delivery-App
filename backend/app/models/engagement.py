from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin
from app.models.enums import DiscountType, NotificationKind


class Offer(TimestampMixin, Base):
    """Coupon / promotion (APNA50, APNA100...)."""

    __tablename__ = "offers"
    __table_args__ = (
        CheckConstraint("value > 0", name="value_positive"),
        CheckConstraint("discount_type <> 'percent' OR value <= 100", name="percent_max_100"),
        CheckConstraint("min_order >= 0", name="min_order_positive"),
        CheckConstraint("ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at", name="date_range"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(String(30), nullable=False, unique=True)  # stored UPPERCASE
    title: Mapped[str] = mapped_column(String(80), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    discount_type: Mapped[DiscountType] = mapped_column(
        Enum(DiscountType, name="discount_type"), nullable=False
    )
    value: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    max_discount: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    min_order: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, server_default="0")
    # Only valid on a customer's first N orders (null = no limit).
    valid_for_first_n_orders: Mapped[int | None] = mapped_column(Integer)
    image_url: Mapped[str | None] = mapped_column(String(500))
    is_featured: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    starts_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Notification(Base):
    """In-app notification. user_id NULL = broadcast to everyone."""

    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    body: Mapped[str] = mapped_column(String(500), nullable=False)
    kind: Mapped[NotificationKind] = mapped_column(
        Enum(NotificationKind, name="notification_kind"),
        nullable=False,
        server_default=NotificationKind.info.value,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class FavoriteRestaurant(Base):
    __tablename__ = "favorite_restaurants"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id", ondelete="CASCADE"), primary_key=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class FavoriteMenuItem(Base):
    __tablename__ = "favorite_menu_items"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    menu_item_id: Mapped[int] = mapped_column(
        ForeignKey("menu_items.id", ondelete="CASCADE"), primary_key=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
