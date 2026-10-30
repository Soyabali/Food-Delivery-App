"""Shapes for the web dashboard (/admin/*)."""

from datetime import datetime
from typing import Literal

from pydantic import EmailStr, Field

from app.schemas.common import CamelModel


class AddOnIn(CamelModel):
    id: int | None = None  # existing add-on to update; omit to create
    name: str = Field(min_length=1, max_length=80)
    subtitle: str | None = Field(default=None, max_length=150)
    price: float = Field(ge=0)
    sort_order: int = 0
    is_active: bool = True


class AdminAddOnOut(CamelModel):
    id: int
    name: str
    subtitle: str | None
    price: float
    sort_order: int
    is_active: bool


class RestaurantIn(CamelModel):
    slug: str = Field(min_length=2, max_length=80, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    name: str = Field(min_length=2, max_length=120)
    description: str | None = None
    cuisines: list[str] = []
    image_url: str | None = None
    address_line: str | None = None
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    rating: float = Field(default=0, ge=0, le=5)
    rating_count: int = Field(default=0, ge=0)
    delivery_time_min: int = Field(gt=0, le=180)
    delivery_time_max: int = Field(gt=0, le=240)
    cost_for_one: int = Field(ge=0)
    delivery_fee: int = Field(default=0, ge=0)
    is_pure_veg: bool = False
    has_spice_levels: bool = False
    badge: str | None = Field(default=None, max_length=30)
    is_popular: bool = False
    is_active: bool = True
    add_ons: list[AddOnIn] = []


class RestaurantPatch(CamelModel):
    """All fields optional; `addOns`, when sent, replaces the whole list."""

    slug: str | None = Field(default=None, min_length=2, max_length=80, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    name: str | None = Field(default=None, min_length=2, max_length=120)
    description: str | None = None
    cuisines: list[str] | None = None
    image_url: str | None = None
    address_line: str | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    rating: float | None = Field(default=None, ge=0, le=5)
    rating_count: int | None = Field(default=None, ge=0)
    delivery_time_min: int | None = Field(default=None, gt=0, le=180)
    delivery_time_max: int | None = Field(default=None, gt=0, le=240)
    cost_for_one: int | None = Field(default=None, ge=0)
    delivery_fee: int | None = Field(default=None, ge=0)
    is_pure_veg: bool | None = None
    has_spice_levels: bool | None = None
    badge: str | None = None
    is_popular: bool | None = None
    is_active: bool | None = None
    add_ons: list[AddOnIn] | None = None


class AdminRestaurantOut(CamelModel):
    id: int
    slug: str
    name: str
    description: str | None
    cuisines: list[str]
    image_url: str | None
    address_line: str | None
    latitude: float
    longitude: float
    rating: float
    rating_count: int
    delivery_time_min: int
    delivery_time_max: int
    cost_for_one: int
    delivery_fee: int
    is_pure_veg: bool
    has_spice_levels: bool
    badge: str | None
    is_popular: bool
    is_active: bool
    menu_item_count: int
    add_ons: list[AdminAddOnOut]
    created_at: datetime
    updated_at: datetime


class VariantIn(CamelModel):
    id: int | None = None
    name: str = Field(min_length=1, max_length=60)
    subtitle: str | None = Field(default=None, max_length=150)
    price_delta: float = Field(default=0, ge=0)
    is_default: bool = False
    sort_order: int = 0


class AdminVariantOut(CamelModel):
    id: int
    name: str
    subtitle: str | None
    price_delta: float
    is_default: bool
    sort_order: int


class MenuItemIn(CamelModel):
    restaurant_id: int
    category_id: int | None = None
    name: str = Field(min_length=2, max_length=150)
    description: str | None = None
    price: float = Field(gt=0)
    image_url: str | None = None
    is_veg: bool = False
    is_available: bool = True
    has_spice_levels: bool = False
    allows_add_ons: bool = True
    cuisine: str | None = Field(default=None, max_length=40)
    tags: list[str] = []
    meal_types: list[str] = []
    ingredients: list[str] = []
    prep_time_minutes: int | None = Field(default=None, ge=0, le=600)
    calories: int | None = Field(default=None, ge=0)
    difficulty: str | None = Field(default=None, max_length=20)
    servings: int | None = Field(default=None, ge=1, le=50)
    rating: float = Field(default=0, ge=0, le=5)
    rating_count: int = Field(default=0, ge=0)
    badge: str | None = Field(default=None, max_length=30)
    sort_order: int = 0
    variants: list[VariantIn] = []


class MenuItemPatch(CamelModel):
    restaurant_id: int | None = None
    category_id: int | None = None
    name: str | None = Field(default=None, min_length=2, max_length=150)
    description: str | None = None
    price: float | None = Field(default=None, gt=0)
    image_url: str | None = None
    is_veg: bool | None = None
    is_available: bool | None = None
    has_spice_levels: bool | None = None
    allows_add_ons: bool | None = None
    cuisine: str | None = None
    tags: list[str] | None = None
    meal_types: list[str] | None = None
    ingredients: list[str] | None = None
    prep_time_minutes: int | None = Field(default=None, ge=0, le=600)
    calories: int | None = Field(default=None, ge=0)
    difficulty: str | None = None
    servings: int | None = Field(default=None, ge=1, le=50)
    rating: float | None = Field(default=None, ge=0, le=5)
    rating_count: int | None = Field(default=None, ge=0)
    badge: str | None = None
    sort_order: int | None = None
    variants: list[VariantIn] | None = None


class AdminMenuItemOut(CamelModel):
    id: int
    restaurant_id: int
    restaurant_name: str
    category_id: int | None
    category_name: str | None
    name: str
    description: str | None
    price: float
    image_url: str | None
    is_veg: bool
    is_available: bool
    has_spice_levels: bool
    allows_add_ons: bool
    cuisine: str | None
    tags: list[str]
    meal_types: list[str]
    ingredients: list[str]
    prep_time_minutes: int | None
    calories: int | None
    difficulty: str | None
    servings: int | None
    rating: float
    rating_count: int
    badge: str | None
    sort_order: int
    variants: list[AdminVariantOut]
    created_at: datetime
    updated_at: datetime


class CategoryIn(CamelModel):
    name: str = Field(min_length=1, max_length=60)
    slug: str = Field(min_length=1, max_length=60, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    emoji: str | None = Field(default=None, max_length=16)
    image_url: str | None = None
    sort_order: int = 0
    is_active: bool = True


class CategoryPatch(CamelModel):
    name: str | None = Field(default=None, min_length=1, max_length=60)
    slug: str | None = Field(default=None, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    emoji: str | None = None
    image_url: str | None = None
    sort_order: int | None = None
    is_active: bool | None = None


class AdminCategoryOut(CamelModel):
    id: int
    name: str
    slug: str
    emoji: str | None
    image_url: str | None
    sort_order: int
    is_active: bool
    menu_item_count: int


class OfferIn(CamelModel):
    code: str = Field(min_length=3, max_length=30, pattern=r"^[A-Za-z0-9]+$")
    title: str = Field(min_length=1, max_length=80)
    subtitle: str = Field(min_length=1, max_length=150)
    description: str | None = None
    discount_type: Literal["percent", "flat"]
    value: float = Field(gt=0)
    max_discount: float | None = Field(default=None, gt=0)
    min_order: float = Field(default=0, ge=0)
    valid_for_first_n_orders: int | None = Field(default=None, ge=1)
    image_url: str | None = None
    is_featured: bool = False
    is_active: bool = True
    starts_at: datetime | None = None
    ends_at: datetime | None = None


class OfferPatch(CamelModel):
    title: str | None = Field(default=None, min_length=1, max_length=80)
    subtitle: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = None
    discount_type: Literal["percent", "flat"] | None = None
    value: float | None = Field(default=None, gt=0)
    max_discount: float | None = None
    min_order: float | None = Field(default=None, ge=0)
    valid_for_first_n_orders: int | None = None
    image_url: str | None = None
    is_featured: bool | None = None
    is_active: bool | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None


class AdminOfferOut(CamelModel):
    id: int
    code: str
    title: str
    subtitle: str
    description: str | None
    discount_type: str
    value: float
    max_discount: float | None
    min_order: float
    valid_for_first_n_orders: int | None
    image_url: str | None
    is_featured: bool
    is_active: bool
    starts_at: datetime | None
    ends_at: datetime | None
    times_used: int


class OrderStatusIn(CamelModel):
    status: Literal["placed", "preparing", "out_for_delivery", "delivered", "cancelled"]
    note: str | None = Field(default=None, max_length=200)


class PaymentStatusIn(CamelModel):
    payment_status: Literal["pending", "paid", "failed", "refunded"]


class AdminOrderItemOut(CamelModel):
    id: int
    menu_item_id: int | None
    name: str
    variant_name: str | None
    spice_level: str | None
    add_on_names: list[str]
    note: str | None
    unit_price: float
    quantity: int
    line_total: float


class AdminStatusEventOut(CamelModel):
    status: str
    note: str | None
    changed_at: datetime
    changed_by_user_id: int | None


class AdminOrderOut(CamelModel):
    id: int
    order_number: str
    status: str
    payment_method: str
    payment_status: str
    customer_id: int | None  # None once the customer deleted their account
    customer_name: str
    customer_phone: str | None
    restaurant_id: int
    restaurant_name: str
    address_label: str
    address_line: str
    item_total: float
    delivery_fee: float
    taxes: float
    discount: float
    total: float
    coupon_code: str | None
    instructions: str | None
    placed_at: datetime
    eta: datetime
    delivered_at: datetime | None
    item_count: int


class AdminOrderDetailOut(AdminOrderOut):
    items: list[AdminOrderItemOut]
    status_history: list[AdminStatusEventOut]


class AdminUserOut(CamelModel):
    id: int
    full_name: str
    email: str
    phone: str | None
    role: str
    is_active: bool
    order_count: int
    created_at: datetime
    last_login_at: datetime | None


class UserPatch(CamelModel):
    role: Literal["customer", "admin"] | None = None
    is_active: bool | None = None


class AdminUserCreate(CamelModel):
    full_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    phone: str | None = None
    password: str = Field(min_length=8, max_length=128)
    role: Literal["customer", "admin"] = "customer"


class NotificationIn(CamelModel):
    title: str = Field(min_length=1, max_length=120)
    body: str = Field(min_length=1, max_length=500)
    kind: Literal["offer", "delivery", "info"] = "info"
    user_id: int | None = None  # omit to broadcast


class TopItemOut(CamelModel):
    menu_item_id: int | None
    name: str
    quantity: int
    revenue: float


class StatsOut(CamelModel):
    total_users: int
    total_restaurants: int
    total_menu_items: int
    orders_today: int
    revenue_today: float
    active_orders: int
    orders_by_status: dict[str, int]
    top_items: list[TopItemOut]


class UploadOut(CamelModel):
    id: int
    url: str


class MediaUsageOut(CamelModel):
    kind: Literal["restaurant", "menuItem", "category", "offer"]
    id: int
    name: str


class AdminMediaOut(CamelModel):
    id: int
    url: str
    file_name: str
    original_name: str
    content_type: str
    size_bytes: int
    uploaded_by: str | None  # admin's name; null once that user is gone
    created_at: datetime
    used_by: list[MediaUsageOut]
    # Past orders keep a copy of the dish photo URL, so the file must stay.
    order_item_count: int
