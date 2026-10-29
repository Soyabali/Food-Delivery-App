from typing import Literal

from fastapi import APIRouter, status
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.core.errors import ApiError
from app.models import Address, FavoriteMenuItem, FavoriteRestaurant, MenuItem, Restaurant, User
from app.schemas import public as s
from app.services.serializers import address_book_out

router = APIRouter(tags=["user data"])


def _address(user: User, address_id: str) -> Address:
    a = next((a for a in user.addresses if str(a.id) == address_id), None)
    if a is None:
        raise ApiError(404, "Address not found.")
    return a


@router.get("/addresses", response_model=s.AddressBookOut)
def get_addresses(user: CurrentUser):
    return address_book_out(user)


@router.post("/addresses", response_model=s.AddressBookOut, status_code=status.HTTP_201_CREATED)
def create_address(body: s.AddressIn, user: CurrentUser, db: DbSession):
    if body.is_default:
        for a in user.addresses:
            a.is_default = False
        db.flush()
    address = Address(**body.model_dump())
    user.addresses.append(address)
    db.flush()
    if user.selected_address_id is None:
        user.selected_address_id = address.id
    db.commit()
    return address_book_out(user)


@router.post("/addresses/{address_id}/select", response_model=s.AddressBookOut)
def select_address(address_id: str, user: CurrentUser, db: DbSession):
    user.selected_address_id = _address(user, address_id).id
    db.commit()
    return address_book_out(user)


@router.delete("/addresses/{address_id}", response_model=s.AddressBookOut)
def delete_address(address_id: str, user: CurrentUser, db: DbSession):
    address = _address(user, address_id)
    if user.selected_address_id == address.id:
        user.selected_address_id = None
    user.addresses.remove(address)
    db.commit()
    return address_book_out(user)


def _favorites(db, user: User) -> s.FavoritesOut:
    restaurants = db.scalars(
        select(Restaurant.slug)
        .join(FavoriteRestaurant, FavoriteRestaurant.restaurant_id == Restaurant.id)
        .where(FavoriteRestaurant.user_id == user.id)
        .order_by(FavoriteRestaurant.created_at)
    ).all()
    dishes = db.scalars(
        select(FavoriteMenuItem.menu_item_id)
        .where(FavoriteMenuItem.user_id == user.id)
        .order_by(FavoriteMenuItem.created_at)
    ).all()
    return s.FavoritesOut(restaurants=list(restaurants), dishes=[str(d) for d in dishes])


@router.get("/favorites", response_model=s.FavoritesOut)
def get_favorites(user: CurrentUser, db: DbSession):
    return _favorites(db, user)


def _target(db, kind: str, target_id: str):
    if kind == "restaurant":
        rid = db.scalar(select(Restaurant.id).where(Restaurant.slug == target_id))
        if rid is None:
            raise ApiError(404, "Restaurant not found.")
        return FavoriteRestaurant, {"restaurant_id": rid}
    if kind == "dish":
        if not target_id.isdigit() or db.get(MenuItem, int(target_id)) is None:
            raise ApiError(404, "Dish not found.")
        return FavoriteMenuItem, {"menu_item_id": int(target_id)}
    raise ApiError(400, f'Unknown favourite type "{kind}".')


@router.put("/favorites/{kind}/{target_id}", response_model=s.FavoritesOut)
def add_favorite(kind: Literal["restaurant", "dish"], target_id: str, user: CurrentUser, db: DbSession):
    model, key = _target(db, kind, target_id)
    if db.get(model, {"user_id": user.id, **key}) is None:
        db.add(model(user_id=user.id, **key))
        db.commit()
    return _favorites(db, user)


@router.delete("/favorites/{kind}/{target_id}", response_model=s.FavoritesOut)
def remove_favorite(kind: Literal["restaurant", "dish"], target_id: str, user: CurrentUser, db: DbSession):
    model, key = _target(db, kind, target_id)
    row = db.get(model, {"user_id": user.id, **key})
    if row is not None:
        db.delete(row)
        db.commit()
    return _favorites(db, user)
