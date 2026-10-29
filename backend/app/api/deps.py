from datetime import UTC, datetime
from typing import Annotated

from fastapi import Depends, Header
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import hash_token
from app.models import User, UserRole, UserSession

DbSession = Annotated[Session, Depends(get_db)]


def _bearer(authorization: str | None) -> str | None:
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    return authorization[7:].strip() or None


def _user_for_token(db: Session, token: str | None) -> User | None:
    if token is None:
        return None
    session = db.scalar(
        select(UserSession).where(
            UserSession.token_hash == hash_token(token),
            UserSession.revoked_at.is_(None),
            UserSession.expires_at > datetime.now(UTC),
        )
    )
    if session is None or not session.user.is_active:
        return None
    return session.user


def get_optional_user(
    db: DbSession, authorization: Annotated[str | None, Header()] = None
) -> User | None:
    return _user_for_token(db, _bearer(authorization))


def get_current_user(
    db: DbSession, authorization: Annotated[str | None, Header()] = None
) -> User:
    user = _user_for_token(db, _bearer(authorization))
    if user is None:
        raise ApiError(401, "Please log in to continue.")
    return user


def get_admin_user(user: Annotated[User, Depends(get_current_user)]) -> User:
    if user.role != UserRole.admin:
        raise ApiError(403, "Admin access required.")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
OptionalUser = Annotated[User | None, Depends(get_optional_user)]
AdminUser = Annotated[User, Depends(get_admin_user)]
