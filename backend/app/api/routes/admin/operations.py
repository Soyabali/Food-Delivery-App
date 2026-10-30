"""Dashboard: offers, orders, users, notifications, stats and image uploads."""

import uuid
from datetime import UTC, datetime, time
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, File, Query, UploadFile, status
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.api.deps import AdminUser, DbSession
from app.api.routes.admin.common import apply_patch, paginate
from app.core.config import get_settings
from app.core.errors import ApiError
from app.core.security import hash_password
from app.models import (
    Category,
    DiscountType,
    MediaAsset,
    MenuItem,
    Notification,
    NotificationKind,
    Offer,
    Order,
    OrderItem,
    OrderStatus,
    PaymentStatus,
    Restaurant,
    User,
    UserRole,
)
from app.schemas import admin as a
from app.schemas.common import Page
from app.services import order_service

router = APIRouter(tags=["admin: operations"])

# ----------------------------------------------------------------- offers


def _offer_out(db, o: Offer) -> a.AdminOfferOut:
    used = db.scalar(select(func.count(Order.id)).where(Order.offer_id == o.id)) or 0
    return a.AdminOfferOut.model_validate(
        {**{c.key: getattr(o, c.key) for c in Offer.__table__.columns}, "discount_type": o.discount_type.value,
         "times_used": used}
    )


def _check_offer(o: Offer) -> None:
    if o.discount_type == DiscountType.percent and o.value > 100:
        raise ApiError(400, "A percentage discount can't exceed 100.")
    if o.starts_at and o.ends_at and o.ends_at <= o.starts_at:
        raise ApiError(400, "endsAt must be after startsAt.")


def _get_offer(db, offer_id: int) -> Offer:
    o = db.get(Offer, offer_id)
    if o is None:
        raise ApiError(404, "Offer not found.")
    return o


@router.get("/offers", response_model=list[a.AdminOfferOut])
def list_offers(db: DbSession, _: AdminUser):
    return [_offer_out(db, o) for o in db.scalars(select(Offer).order_by(Offer.id))]


@router.post("/offers", response_model=a.AdminOfferOut, status_code=status.HTTP_201_CREATED)
def create_offer(body: a.OfferIn, db: DbSession, _: AdminUser):
    o = Offer(**{**body.model_dump(), "code": body.code.upper(), "discount_type": DiscountType(body.discount_type)})
    _check_offer(o)
    db.add(o)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise ApiError(409, f"Coupon code {o.code} already exists.") from exc
    return _offer_out(db, o)


@router.patch("/offers/{offer_id}", response_model=a.AdminOfferOut)
def update_offer(offer_id: int, body: a.OfferPatch, db: DbSession, _: AdminUser):
    o = _get_offer(db, offer_id)
    apply_patch(o, body, exclude={"discount_type"})
    if body.discount_type is not None:
        o.discount_type = DiscountType(body.discount_type)
    _check_offer(o)
    db.commit()
    return _offer_out(db, o)


@router.delete("/offers/{offer_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_offer(offer_id: int, db: DbSession, _: AdminUser):
    """Past orders keep their coupon code text; carts drop the coupon."""
    db.delete(_get_offer(db, offer_id))
    db.commit()


# ----------------------------------------------------------------- orders


def _order_row(o: Order) -> dict:
    return {
        **{c.key: getattr(o, c.key) for c in Order.__table__.columns},
        "status": o.status.value,
        "payment_method": o.payment_method.value,
        "payment_status": o.payment_status.value,
        "customer_id": o.user_id,
        # NULL user = the customer deleted their account (order anonymised).
        "customer_name": o.user.full_name if o.user else "Deleted customer",
        "customer_phone": o.user.phone if o.user else None,
        "restaurant_name": o.restaurant.name,
        "item_count": sum(i.quantity for i in o.items),
    }


def _get_order(db, order_id: int) -> Order:
    o = db.get(
        Order,
        order_id,
        options=[selectinload(Order.items), selectinload(Order.status_history), selectinload(Order.restaurant)],
    )
    if o is None:
        raise ApiError(404, "Order not found.")
    return o


def _order_detail(o: Order) -> a.AdminOrderDetailOut:
    return a.AdminOrderDetailOut.model_validate(
        {
            **_order_row(o),
            "items": o.items,
            "status_history": [
                {"status": e.status.value, "note": e.note, "changed_at": e.changed_at,
                 "changed_by_user_id": e.changed_by_user_id}
                for e in o.status_history
            ],
        }
    )


@router.get("/orders", response_model=Page[a.AdminOrderOut])
def list_orders(
    db: DbSession,
    _: AdminUser,
    status_filter: Annotated[
        OrderStatus | None, Query(alias="status", description="placed | preparing | out_for_delivery | delivered | cancelled")
    ] = None,
    restaurant_id: Annotated[int | None, Query(alias="restaurantId")] = None,
    q: Annotated[str | None, Query(description="Order number or customer name/email")] = None,
    date_from: Annotated[datetime | None, Query(alias="from")] = None,
    date_to: Annotated[datetime | None, Query(alias="to")] = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100, alias="pageSize")] = 20,
):
    stmt = (
        select(Order)
        .outerjoin(Order.user)
        .options(selectinload(Order.items), selectinload(Order.restaurant), selectinload(Order.user))
    )
    if status_filter is not None:
        stmt = stmt.where(Order.status == status_filter)
    if restaurant_id is not None:
        stmt = stmt.where(Order.restaurant_id == restaurant_id)
    if q:
        term = f"%{q}%"
        stmt = stmt.where(or_(Order.order_number.ilike(term), User.full_name.ilike(term), User.email.ilike(term)))
    if date_from is not None:
        stmt = stmt.where(Order.placed_at >= date_from)
    if date_to is not None:
        stmt = stmt.where(Order.placed_at < date_to)
    rows, total = paginate(db, stmt.order_by(Order.placed_at.desc()), page, page_size)
    return Page(items=[a.AdminOrderOut.model_validate(_order_row(o)) for o in rows], total=total, page=page,
                page_size=page_size)


@router.get("/orders/{order_id}", response_model=a.AdminOrderDetailOut)
def get_order(order_id: int, db: DbSession, _: AdminUser):
    return _order_detail(_get_order(db, order_id))


@router.patch("/orders/{order_id}/status", response_model=a.AdminOrderDetailOut)
def update_order_status(order_id: int, body: a.OrderStatusIn, db: DbSession, admin: AdminUser):
    """placed → preparing → out_for_delivery → delivered (or → cancelled)."""
    order = order_service.change_status(db, _get_order(db, order_id), OrderStatus(body.status), admin, body.note)
    return _order_detail(order)


@router.patch("/orders/{order_id}/payment", response_model=a.AdminOrderDetailOut)
def update_payment_status(order_id: int, body: a.PaymentStatusIn, db: DbSession, _: AdminUser):
    order = _get_order(db, order_id)
    order.payment_status = PaymentStatus(body.payment_status)
    db.commit()
    return _order_detail(_get_order(db, order_id))


# ------------------------------------------------------------------ users


def _user_out(db, u: User) -> a.AdminUserOut:
    count = db.scalar(select(func.count(Order.id)).where(Order.user_id == u.id)) or 0
    return a.AdminUserOut.model_validate(
        {**{c.key: getattr(u, c.key) for c in User.__table__.columns}, "role": u.role.value, "order_count": count}
    )


@router.get("/users", response_model=Page[a.AdminUserOut])
def list_users(
    db: DbSession,
    _: AdminUser,
    q: str | None = None,
    role: UserRole | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100, alias="pageSize")] = 20,
):
    stmt = select(User).order_by(User.id)
    if q:
        stmt = stmt.where(or_(User.full_name.ilike(f"%{q}%"), User.email.ilike(f"%{q}%"), User.phone.ilike(f"%{q}%")))
    if role is not None:
        stmt = stmt.where(User.role == role)
    rows, total = paginate(db, stmt, page, page_size)
    return Page(items=[_user_out(db, u) for u in rows], total=total, page=page, page_size=page_size)


@router.post("/users", response_model=a.AdminUserOut, status_code=status.HTTP_201_CREATED)
def create_user(body: a.AdminUserCreate, db: DbSession, _: AdminUser):
    exists = db.scalar(select(User.id).where(func.lower(User.email) == body.email.lower()))
    if exists:
        raise ApiError(409, "A user with this email already exists.")
    u = User(
        full_name=body.full_name,
        email=body.email.lower(),
        phone=body.phone,
        password_hash=hash_password(body.password),
        role=UserRole(body.role),
    )
    db.add(u)
    db.commit()
    return _user_out(db, u)


@router.patch("/users/{user_id}", response_model=a.AdminUserOut)
def update_user(user_id: int, body: a.UserPatch, db: DbSession, admin: AdminUser):
    u = db.get(User, user_id)
    if u is None:
        raise ApiError(404, "User not found.")
    if u.id == admin.id and (body.is_active is False or body.role == "customer"):
        raise ApiError(400, "You can't remove your own admin access.")
    if body.role is not None:
        u.role = UserRole(body.role)
    if body.is_active is not None:
        u.is_active = body.is_active
    db.commit()
    return _user_out(db, u)


# ---------------------------------------------------------- notifications


@router.post("/notifications", status_code=status.HTTP_201_CREATED)
def send_notification(body: a.NotificationIn, db: DbSession, _: AdminUser):
    if body.user_id is not None and db.get(User, body.user_id) is None:
        raise ApiError(400, f"User {body.user_id} does not exist.")
    n = Notification(title=body.title, body=body.body, kind=NotificationKind(body.kind), user_id=body.user_id)
    db.add(n)
    db.commit()
    return {"id": n.id, "message": "Notification created."}


# ------------------------------------------------------------------ stats


@router.get("/stats", response_model=a.StatsOut)
def stats(db: DbSession, _: AdminUser):
    today = datetime.combine(datetime.now(UTC).date(), time.min, tzinfo=UTC)
    not_cancelled = Order.status != OrderStatus.cancelled
    by_status = dict(db.execute(select(Order.status, func.count(Order.id)).group_by(Order.status)).all())
    top = db.execute(
        select(
            OrderItem.menu_item_id,
            OrderItem.name,
            func.sum(OrderItem.quantity),
            func.sum(OrderItem.line_total),
        )
        .join(Order, Order.id == OrderItem.order_id)
        .where(not_cancelled)
        .group_by(OrderItem.menu_item_id, OrderItem.name)
        .order_by(func.sum(OrderItem.quantity).desc())
        .limit(5)
    ).all()
    return a.StatsOut(
        total_users=db.scalar(select(func.count(User.id)).where(User.role == UserRole.customer)) or 0,
        total_restaurants=db.scalar(select(func.count(Restaurant.id)).where(Restaurant.is_active.is_(True))) or 0,
        total_menu_items=db.scalar(select(func.count(MenuItem.id))) or 0,
        orders_today=db.scalar(select(func.count(Order.id)).where(Order.placed_at >= today)) or 0,
        revenue_today=float(
            db.scalar(select(func.coalesce(func.sum(Order.total), 0)).where(Order.placed_at >= today, not_cancelled))
        ),
        active_orders=db.scalar(
            select(func.count(Order.id)).where(
                Order.status.in_([OrderStatus.placed, OrderStatus.preparing, OrderStatus.out_for_delivery])
            )
        )
        or 0,
        orders_by_status={s.value: by_status.get(s, 0) for s in OrderStatus},
        top_items=[
            a.TopItemOut(menu_item_id=mid, name=name, quantity=int(qty), revenue=float(rev))
            for mid, name, qty, rev in top
        ],
    )


# ---------------------------------------------------------------- uploads

ALLOWED_IMAGES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}


@router.post("/uploads", response_model=a.UploadOut, status_code=status.HTTP_201_CREATED)
async def upload_image(db: DbSession, admin: AdminUser, file: Annotated[UploadFile, File()]):
    """Stores an image in MEDIA_DIR, records it in media_assets and returns
    its public URL. Use the URL as imageUrl for restaurants, menu items,
    categories or offers."""
    settings = get_settings()
    ext = ALLOWED_IMAGES.get(file.content_type or "")
    if ext is None:
        raise ApiError(400, "Only JPEG, PNG or WebP images are allowed.")
    data = await file.read(settings.max_upload_mb * 1024 * 1024 + 1)
    if len(data) > settings.max_upload_mb * 1024 * 1024:
        raise ApiError(400, f"Image must be {settings.max_upload_mb} MB or smaller.")
    if not data:
        raise ApiError(400, "The image file is empty.")
    folder = Path(settings.media_dir)
    folder.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex}{ext}"
    (folder / name).write_bytes(data)
    asset = MediaAsset(
        file_name=name,
        original_name=(file.filename or name)[:255],
        content_type=file.content_type,
        size_bytes=len(data),
        url=f"{settings.public_base_url.rstrip('/')}/media/{name}",
        uploaded_by_id=admin.id,
    )
    db.add(asset)
    db.commit()
    return a.UploadOut(id=asset.id, url=asset.url)


# Tables whose rows show an uploaded image, with the column used as its label.
_IMAGE_OWNERS = (
    ("restaurant", Restaurant, Restaurant.name),
    ("menuItem", MenuItem, MenuItem.name),
    ("category", Category, Category.name),
    ("offer", Offer, Offer.code),
)


def _media_out(db, assets: list[MediaAsset]) -> list[a.AdminMediaOut]:
    urls = [m.url for m in assets]
    used: dict[str, list[a.MediaUsageOut]] = {u: [] for u in urls}
    for kind, model, label in _IMAGE_OWNERS:
        for rid, name, url in db.execute(select(model.id, label, model.image_url).where(model.image_url.in_(urls))):
            used[url].append(a.MediaUsageOut(kind=kind, id=rid, name=name))
    in_orders = dict(
        db.execute(
            select(OrderItem.image_url, func.count(OrderItem.id))
            .where(OrderItem.image_url.in_(urls))
            .group_by(OrderItem.image_url)
        ).all()
    )
    return [
        a.AdminMediaOut(
            **{c.key: getattr(m, c.key) for c in MediaAsset.__table__.columns if c.key != "uploaded_by_id"},
            uploaded_by=m.uploaded_by.full_name if m.uploaded_by else None,
            used_by=used[m.url],
            order_item_count=in_orders.get(m.url, 0),
        )
        for m in assets
    ]


@router.get("/uploads", response_model=Page[a.AdminMediaOut])
def list_uploads(
    db: DbSession,
    _: AdminUser,
    q: str | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100, alias="pageSize")] = 40,
):
    """Every uploaded image, newest first, with where each one is used."""
    stmt = select(MediaAsset).options(selectinload(MediaAsset.uploaded_by)).order_by(MediaAsset.id.desc())
    if q:
        stmt = stmt.where(MediaAsset.original_name.ilike(f"%{q}%"))
    rows, total = paginate(db, stmt, page, page_size)
    return Page(items=_media_out(db, rows), total=total, page=page, page_size=page_size)


@router.delete("/uploads/{asset_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_upload(asset_id: int, db: DbSession, _: AdminUser):
    m = db.get(MediaAsset, asset_id)
    if m is None:
        raise ApiError(404, "Image not found.")
    (info,) = _media_out(db, [m])
    if info.used_by:
        names = ", ".join(u.name for u in info.used_by[:3])
        raise ApiError(409, f"This image is still in use ({names}). Change those images first.")
    if info.order_item_count:
        raise ApiError(409, "Past orders show this image, so it can't be deleted.")
    file_name = m.file_name
    db.delete(m)
    db.commit()
    (Path(get_settings().media_dir) / file_name).unlink(missing_ok=True)
