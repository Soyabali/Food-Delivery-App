from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.schemas import public as s
from app.services import cart_service as cs

router = APIRouter(prefix="/cart", tags=["cart"])


@router.get("", response_model=s.CartOut)
def get_cart(user: CurrentUser, db: DbSession):
    return cs.cart_out(db, user, cs.get_or_create_cart(db, user))


@router.delete("", response_model=s.CartOut)
def clear_cart(user: CurrentUser, db: DbSession):
    cart = cs.get_or_create_cart(db, user)
    cart.items.clear()
    cart.instructions = ""
    db.commit()
    return cs.cart_out(db, user, cart)


@router.post("/items", response_model=s.CartOut)
def add_item(body: s.AddCartItemIn, user: CurrentUser, db: DbSession):
    """409 when the cart holds another restaurant's items (unless replaceCart)."""
    return cs.cart_out(db, user, cs.add_item(db, user, body))


@router.patch("/items/{line_id}", response_model=s.CartOut)
def update_item(line_id: str, body: s.UpdateCartItemIn, user: CurrentUser, db: DbSession):
    cart = cs.get_or_create_cart(db, user)
    line = cs.find_line(cart, line_id)
    if body.quantity == 0:
        cart.items.remove(line)
    else:
        line.quantity = body.quantity
    db.commit()
    return cs.cart_out(db, user, cart)


@router.delete("/items/{line_id}", response_model=s.CartOut)
def remove_item(line_id: str, user: CurrentUser, db: DbSession):
    cart = cs.get_or_create_cart(db, user)
    line = next((i for i in cart.items if str(i.id) == line_id), None)
    if line is not None:
        cart.items.remove(line)
        db.commit()
    return cs.cart_out(db, user, cart)


@router.post("/coupon", response_model=s.CartOut)
def apply_coupon(body: s.CouponIn, user: CurrentUser, db: DbSession):
    return cs.cart_out(db, user, cs.apply_coupon(db, user, body.code))


@router.delete("/coupon", response_model=s.CartOut)
def remove_coupon(user: CurrentUser, db: DbSession):
    cart = cs.get_or_create_cart(db, user)
    cart.offer_id = None
    db.commit()
    db.refresh(cart)
    return cs.cart_out(db, user, cart)


@router.put("/instructions", response_model=s.CartOut)
def set_instructions(body: s.InstructionsIn, user: CurrentUser, db: DbSession):
    cart = cs.get_or_create_cart(db, user)
    cart.instructions = body.instructions.strip()
    db.commit()
    return cs.cart_out(db, user, cart)
