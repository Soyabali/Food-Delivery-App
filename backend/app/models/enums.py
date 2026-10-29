import enum


class UserRole(str, enum.Enum):
    customer = "customer"
    admin = "admin"


class DiscountType(str, enum.Enum):
    percent = "percent"
    flat = "flat"


class OrderStatus(str, enum.Enum):
    placed = "placed"
    preparing = "preparing"
    out_for_delivery = "out_for_delivery"
    delivered = "delivered"
    cancelled = "cancelled"


class PaymentMethod(str, enum.Enum):
    upi = "upi"
    card = "card"
    cod = "cod"


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    paid = "paid"
    failed = "failed"
    refunded = "refunded"


class NotificationKind(str, enum.Enum):
    offer = "offer"
    delivery = "delivery"
    info = "info"
