"""All tables. Importing this package registers every model on Base.metadata
(used by Alembic and the seed script)."""

from app.models.base import Base
from app.models.catalog import AddOn, Category, MenuItem, MenuItemVariant, Restaurant
from app.models.commerce import (
    Cart,
    CartItem,
    Order,
    OrderItem,
    OrderStatusHistory,
    cart_item_add_ons,
)
from app.models.engagement import FavoriteMenuItem, FavoriteRestaurant, Notification, Offer
from app.models.enums import (
    DiscountType,
    NotificationKind,
    OrderStatus,
    PaymentMethod,
    PaymentStatus,
    UserRole,
)
from app.models.media import MediaAsset
from app.models.user import AccountDeletionCode, Address, PasswordResetToken, User, UserSession

__all__ = [
    "AccountDeletionCode",
    "AddOn",
    "Address",
    "Base",
    "Cart",
    "CartItem",
    "Category",
    "DiscountType",
    "FavoriteMenuItem",
    "FavoriteRestaurant",
    "MediaAsset",
    "MenuItem",
    "MenuItemVariant",
    "Notification",
    "NotificationKind",
    "Offer",
    "Order",
    "OrderItem",
    "OrderStatus",
    "OrderStatusHistory",
    "PasswordResetToken",
    "PaymentMethod",
    "PaymentStatus",
    "Restaurant",
    "User",
    "UserRole",
    "UserSession",
    "cart_item_add_ons",
]
