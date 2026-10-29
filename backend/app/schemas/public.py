"""Request/response shapes for the mobile app API.

These match docs/API_ENDPOINTS.md in the Flutter project, so the app can
switch from its mock backend to this server with BACKEND_MODE=http.
"""

from datetime import datetime
from typing import Literal

from pydantic import EmailStr, Field, field_validator

from app.schemas.common import CamelModel, Message  # noqa: F401 (re-exported)

# ---------------------------------------------------------------- auth


class UserOut(CamelModel):
    id: str
    name: str
    email: str
    phone: str | None = None


class SessionOut(CamelModel):
    token: str
    user: UserOut


class LoginIn(CamelModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class RegisterIn(CamelModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    phone: str = Field(min_length=10, max_length=20)
    password: str = Field(min_length=8, max_length=128)

    @field_validator("phone")
    @classmethod
    def _digits(cls, v: str) -> str:
        digits = "".join(c for c in v if c.isdigit())
        if len(digits) < 10:
            raise ValueError("Enter a valid phone number")
        return v.strip()


class ForgotPasswordIn(CamelModel):
    email: EmailStr


class ResetPasswordIn(CamelModel):
    email: EmailStr
    code: str = Field(pattern=r"^\d{6}$", description="6-digit code from the email")
    new_password: str = Field(min_length=8, max_length=128)


class ChangePasswordIn(CamelModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


# ----------------------------------------------------------- catalogue


class AddOnOut(CamelModel):
    id: str
    name: str
    subtitle: str | None = None
    price: float


class RestaurantOut(CamelModel):
    id: str  # slug
    name: str
    cuisines: list[str]
    rating: float
    delivery_time: str  # "25-30 mins"
    cost_for_one: int
    distance_km: float
    image_url: str
    is_pure_veg: bool
    delivery_fee: int
    badge: str | None = None
    popular: bool
    menu_tags: list[str]
    add_ons: list[AddOnOut]
    has_spice_levels: bool
    serves_all_recipes: bool = False


class VariantOut(CamelModel):
    id: str
    name: str
    subtitle: str | None = None
    price: float  # extra over the base price
    is_default: bool


class MenuItemOut(CamelModel):
    id: int
    restaurant_id: str  # slug
    restaurant_name: str
    category: str | None = None
    name: str
    description: str
    price: float
    image_url: str
    is_veg: bool
    is_available: bool
    rating: float
    rating_count: int
    prep_time: str
    calories: int | None = None
    cuisine: str | None = None
    tags: list[str]
    meal_types: list[str]
    ingredients: list[str]
    difficulty: str | None = None
    servings: int | None = None
    badge: str | None = None
    portions: list[VariantOut]
    spice_levels: list[str]
    add_ons: list[AddOnOut]


class CategoryOut(CamelModel):
    id: int
    name: str
    slug: str
    emoji: str | None = None
    image_url: str | None = None


class OfferOut(CamelModel):
    code: str
    title: str
    subtitle: str
    type: Literal["percent", "flat"]
    value: float
    max_discount: float | None = None
    min_order: float
    max_orders_per_user: int | None = None
    image_url: str | None = None
    featured: bool


class NotificationOut(CamelModel):
    id: str
    title: str
    body: str
    kind: str
    created_at: datetime


# ------------------------------------------------------------ user data


class AddressOut(CamelModel):
    id: str
    label: str
    line: str
    icon: str
    is_default: bool
    latitude: float | None = None
    longitude: float | None = None


class AddressBookOut(CamelModel):
    selected_id: str | None
    items: list[AddressOut]


class AddressIn(CamelModel):
    label: str = Field(min_length=1, max_length=40)
    line: str = Field(min_length=5, max_length=300)
    icon: Literal["home", "work", "other"] = "home"
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    is_default: bool = False


class FavoritesOut(CamelModel):
    restaurants: list[str]
    dishes: list[str]


# ----------------------------------------------------------------- cart


class CartLineOut(CamelModel):
    id: str
    recipe_id: int  # = menu item id (name kept for app compatibility)
    menu_item_id: int
    restaurant_id: str
    name: str
    image: str
    is_veg: bool
    unit_price: float
    quantity: int
    portion: str | None = None
    spice_level: str | None = None
    add_ons: list[str]
    note: str | None = None


class CartRestaurantOut(CamelModel):
    id: str
    name: str
    distance_km: float


class CartTotalsOut(CamelModel):
    item_total: float
    delivery_fee: float
    standard_delivery_fee: float
    free_delivery_threshold: float
    taxes: float
    tax_rate_percent: float
    discount: float
    total: float
    savings: float


class CartOut(CamelModel):
    items: list[CartLineOut]
    restaurant: CartRestaurantOut | None
    coupon_code: str | None
    coupon_message: str | None
    instructions: str
    totals: CartTotalsOut


class AddCartItemIn(CamelModel):
    """Prices are always looked up on the server; any client price is ignored.

    `recipeId`, `portion` (name) and `addOns` (names) are accepted for
    compatibility with the current app; ids work too.
    """

    menu_item_id: int | None = None
    recipe_id: int | None = None
    variant_id: int | None = None
    portion: str | None = None
    spice_level: str | None = Field(default=None, max_length=20)
    add_on_ids: list[int] | None = None
    add_ons: list[str] | None = None
    note: str | None = Field(default=None, max_length=120)
    quantity: int = Field(ge=1, le=20)
    replace_cart: bool = False

    @property
    def item_id(self) -> int | None:
        return self.menu_item_id or self.recipe_id


class UpdateCartItemIn(CamelModel):
    quantity: int = Field(ge=0, le=20)


class CouponIn(CamelModel):
    code: str = Field(min_length=1, max_length=30)


class InstructionsIn(CamelModel):
    instructions: str = Field(default="", max_length=150)


# --------------------------------------------------------------- orders


class OrderRestaurantOut(CamelModel):
    id: str
    name: str
    image_url: str
    distance_km: float
    delivery_time: str


class OrderOut(CamelModel):
    id: str  # order number, e.g. AF-12345
    restaurant: OrderRestaurantOut
    items: list[CartLineOut]
    item_total: float
    delivery_fee: float
    taxes: float
    discount: float
    amount: float
    coupon_code: str | None
    instructions: str | None
    address: AddressOut
    payment_method: str
    payment_status: str
    placed_at: datetime
    eta: datetime
    status: str  # placed | preparing | outForDelivery | delivered | cancelled
    status_times: dict[str, datetime]


class PlaceOrderIn(CamelModel):
    address_id: str
    payment_method: Literal["upi", "card", "cod"]
