from fastapi import APIRouter, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DbSession
from app.core.errors import ApiError
from app.models import Order
from app.schemas import public as s
from app.services import order_service
from app.services.serializers import order_out, reference_point

router = APIRouter(prefix="/orders", tags=["orders"])


def _query():
    return select(Order).options(
        selectinload(Order.items), selectinload(Order.status_history), selectinload(Order.restaurant)
    )


@router.post("", response_model=s.OrderOut, status_code=status.HTTP_201_CREATED)
def place_order(body: s.PlaceOrderIn, user: CurrentUser, db: DbSession):
    order = order_service.place_order(db, user, body.address_id, body.payment_method)
    return order_out(order, reference_point(user))


@router.get("", response_model=list[s.OrderOut])
def list_orders(user: CurrentUser, db: DbSession):
    stmt = _query().where(Order.user_id == user.id).order_by(Order.placed_at.desc()).limit(100)
    ref = reference_point(user)
    return [order_out(o, ref) for o in db.scalars(stmt)]


@router.get("/{order_number}", response_model=s.OrderOut)
def get_order(order_number: str, user: CurrentUser, db: DbSession):
    order = db.scalar(_query().where(Order.order_number == order_number, Order.user_id == user.id))
    if order is None:
        raise ApiError(404, "We couldn’t find this order.")
    return order_out(order, reference_point(user))
