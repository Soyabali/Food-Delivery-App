from __future__ import annotations

from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Category(TimestampMixin, Base):
    """Food category shown on the Home screen (Pizza, Biryani, Desserts...)."""

    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(60), nullable=False, unique=True)
    slug: Mapped[str] = mapped_column(String(60), nullable=False, unique=True)
    emoji: Mapped[str | None] = mapped_column(String(16))
    image_url: Mapped[str | None] = mapped_column(String(500))
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))

    menu_items: Mapped[list[MenuItem]] = relationship(back_populates="category")


class Restaurant(TimestampMixin, Base):
    __tablename__ = "restaurants"
    __table_args__ = (
        CheckConstraint("rating BETWEEN 0 AND 5", name="rating_range"),
        CheckConstraint("delivery_time_min > 0 AND delivery_time_max >= delivery_time_min", name="delivery_time"),
        CheckConstraint("cost_for_one >= 0", name="cost_for_one_positive"),
        CheckConstraint("delivery_fee >= 0", name="delivery_fee_positive"),
        CheckConstraint("latitude BETWEEN -90 AND 90", name="latitude_range"),
        CheckConstraint("longitude BETWEEN -180 AND 180", name="longitude_range"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    # Public, URL-friendly id used by the mobile app (e.g. "royal-biryani").
    slug: Mapped[str] = mapped_column(String(80), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    cuisines: Mapped[list[str]] = mapped_column(
        ARRAY(String(40)), nullable=False, server_default="{}"
    )
    image_url: Mapped[str | None] = mapped_column(String(500))
    address_line: Mapped[str | None] = mapped_column(String(300))
    latitude: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    longitude: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    rating: Mapped[Decimal] = mapped_column(Numeric(2, 1), nullable=False, server_default="0")
    rating_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    delivery_time_min: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    delivery_time_max: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    cost_for_one: Mapped[int] = mapped_column(Integer, nullable=False)
    # 0 = free delivery from this restaurant (standard fee still shown as saved).
    delivery_fee: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    is_pure_veg: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    has_spice_levels: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    badge: Mapped[str | None] = mapped_column(String(30))  # "Trending"
    is_popular: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))

    menu_items: Mapped[list[MenuItem]] = relationship(
        back_populates="restaurant", order_by="MenuItem.sort_order, MenuItem.id"
    )
    add_ons: Mapped[list[AddOn]] = relationship(
        back_populates="restaurant",
        cascade="all, delete-orphan",
        order_by="AddOn.sort_order, AddOn.id",
    )


class AddOn(TimestampMixin, Base):
    """Extra a restaurant offers with its dishes (raita, extra cheese...)."""

    __tablename__ = "add_ons"
    __table_args__ = (CheckConstraint("price >= 0", name="price_positive"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(150))
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))

    restaurant: Mapped[Restaurant] = relationship(back_populates="add_ons")


class MenuItem(TimestampMixin, Base):
    """A dish sold by a restaurant."""

    __tablename__ = "menu_items"
    __table_args__ = (
        CheckConstraint("price > 0", name="price_positive"),
        CheckConstraint("rating BETWEEN 0 AND 5", name="rating_range"),
        CheckConstraint("calories IS NULL OR calories >= 0", name="calories_positive"),
        Index("ix_menu_items_restaurant_available", "restaurant_id", "is_available"),
        Index("ix_menu_items_tags", "tags", postgresql_using="gin"),
        Index("ix_menu_items_meal_types", "meal_types", postgresql_using="gin"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    restaurant_id: Mapped[int] = mapped_column(
        ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False
    )
    category_id: Mapped[int | None] = mapped_column(
        ForeignKey("categories.id", ondelete="SET NULL"), index=True
    )
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    image_url: Mapped[str | None] = mapped_column(String(500))
    is_veg: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    is_available: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    has_spice_levels: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    # Whether the restaurant's add-ons can be ordered with this dish.
    allows_add_ons: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    cuisine: Mapped[str | None] = mapped_column(String(40))
    tags: Mapped[list[str]] = mapped_column(ARRAY(String(40)), nullable=False, server_default="{}")
    meal_types: Mapped[list[str]] = mapped_column(
        ARRAY(String(20)), nullable=False, server_default="{}"
    )
    ingredients: Mapped[list[str]] = mapped_column(
        ARRAY(String(120)), nullable=False, server_default="{}"
    )
    prep_time_minutes: Mapped[int | None] = mapped_column(SmallInteger)
    calories: Mapped[int | None] = mapped_column(Integer)
    difficulty: Mapped[str | None] = mapped_column(String(20))
    servings: Mapped[int | None] = mapped_column(SmallInteger)
    rating: Mapped[Decimal] = mapped_column(Numeric(2, 1), nullable=False, server_default="0")
    rating_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    badge: Mapped[str | None] = mapped_column(String(30))
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")

    restaurant: Mapped[Restaurant] = relationship(back_populates="menu_items")
    category: Mapped[Category | None] = relationship(back_populates="menu_items")
    variants: Mapped[list[MenuItemVariant]] = relationship(
        back_populates="menu_item",
        cascade="all, delete-orphan",
        order_by="MenuItemVariant.sort_order, MenuItemVariant.id",
    )


class MenuItemVariant(Base):
    """Portion/size of a dish ("Regular", "Large") with an extra price."""

    __tablename__ = "menu_item_variants"
    __table_args__ = (
        CheckConstraint("price_delta >= 0", name="price_delta_positive"),
        Index(
            "uq_menu_item_variants_one_default",
            "menu_item_id",
            unique=True,
            postgresql_where=text("is_default"),
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    menu_item_id: Mapped[int] = mapped_column(
        ForeignKey("menu_items.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(60), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(150))
    price_delta: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, server_default="0")
    is_default: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")

    menu_item: Mapped[MenuItem] = relationship(back_populates="variants")
