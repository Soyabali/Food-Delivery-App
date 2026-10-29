import hmac
import secrets
from datetime import UTC, datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Header, status
from sqlalchemy import delete, func, select, update

from app.api.deps import CurrentUser, DbSession
from app.core.config import get_settings
from app.core.errors import ApiError
from app.core.security import hash_password, hash_token, new_token, verify_password
from app.models import Address, PasswordResetToken, User, UserSession
from app.schemas import public as s
from app.services import email_service
from app.services.serializers import user_out

router = APIRouter(prefix="/auth", tags=["auth"])

# New customers start with these addresses (Bengaluru demo coordinates);
# replace with a real "add address" flow in the app.
STARTER_ADDRESSES = [
    dict(label="Home", line="123 Main Street, Sector 4, Indiranagar, Bengaluru", icon="home",
         latitude=12.9719, longitude=77.6412, is_default=True),
    dict(label="Work", line="4th Floor, Prestige Tech Park, Outer Ring Road, Bengaluru", icon="work",
         latitude=12.9352, longitude=77.6950, is_default=False),
]


def _issue_session(db, user: User, user_agent: str | None) -> s.SessionOut:
    token = new_token()
    db.add(
        UserSession(
            user_id=user.id,
            token_hash=hash_token(token),
            expires_at=datetime.now(UTC) + timedelta(days=get_settings().session_days),
            user_agent=(user_agent or "")[:255] or None,
        )
    )
    user.last_login_at = datetime.now(UTC)
    db.commit()
    return s.SessionOut(token=token, user=user_out(user))


def _find_by_email(db, email: str) -> User | None:
    return db.scalar(select(User).where(func.lower(User.email) == email.strip().lower()))


@router.post("/login", response_model=s.SessionOut)
def login(body: s.LoginIn, db: DbSession, user_agent: Annotated[str | None, Header()] = None):
    user = _find_by_email(db, body.email)
    if user is None or not verify_password(body.password, user.password_hash):
        raise ApiError(401, "Incorrect email or password.")
    if not user.is_active:
        raise ApiError(403, "This account has been disabled.")
    return _issue_session(db, user, user_agent)


@router.post("/register", response_model=s.SessionOut, status_code=status.HTTP_201_CREATED)
def register(body: s.RegisterIn, db: DbSession, user_agent: Annotated[str | None, Header()] = None):
    if _find_by_email(db, body.email) is not None:
        raise ApiError(409, "An account with this email already exists. Try logging in.")
    user = User(
        full_name=body.name.strip(),
        email=body.email.strip().lower(),
        phone=body.phone,
        password_hash=hash_password(body.password),
    )
    user.addresses = [Address(**a) for a in STARTER_ADDRESSES]
    db.add(user)
    db.flush()
    user.selected_address_id = next(a.id for a in user.addresses if a.is_default)
    return _issue_session(db, user, user_agent)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(db: DbSession, authorization: Annotated[str | None, Header()] = None):
    if authorization and authorization.lower().startswith("bearer "):
        session = db.scalar(
            select(UserSession).where(UserSession.token_hash == hash_token(authorization[7:].strip()))
        )
        if session and session.revoked_at is None:
            session.revoked_at = datetime.now(UTC)
            db.commit()


@router.get("/me", response_model=s.UserOut)
def me(user: CurrentUser):
    return user_out(user)


def _code_hash(user_id: int, code: str) -> str:
    return hash_token(f"{user_id}:{code}")


@router.post("/forgot-password", response_model=s.Message)
def forgot_password(body: s.ForgotPasswordIn, db: DbSession, background: BackgroundTasks):
    """Emails a 6-digit reset code. The response is identical whether or not
    the account exists, so attackers can't discover registered emails."""
    settings = get_settings()
    response = s.Message(message="If an account exists for this email, we've sent a 6-digit reset code.")
    user = _find_by_email(db, body.email)
    if user is None or not user.is_active:
        return response

    now = datetime.now(UTC)
    latest = db.scalar(
        select(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id)
        .order_by(PasswordResetToken.created_at.desc())
    )
    if latest and latest.used_at is None and (now - latest.created_at).total_seconds() < settings.password_reset_resend_seconds:
        return response  # resend cooldown: don't flood the inbox

    # Only the newest code is valid.
    db.execute(delete(PasswordResetToken).where(PasswordResetToken.user_id == user.id))
    code = f"{secrets.randbelow(1_000_000):06d}"
    db.add(
        PasswordResetToken(
            user_id=user.id,
            token_hash=_code_hash(user.id, code),
            expires_at=now + timedelta(minutes=settings.password_reset_minutes),
        )
    )
    db.commit()
    background.add_task(
        email_service.send_password_reset_code, user.email, user.full_name, code, settings.password_reset_minutes
    )
    return response


@router.post("/reset-password", response_model=s.Message)
def reset_password(body: s.ResetPasswordIn, db: DbSession):
    """Sets a new password using the emailed code. Signs out every device."""
    settings = get_settings()
    invalid = ApiError(400, "That code is invalid or has expired. Request a new one.")
    user = _find_by_email(db, body.email)
    if user is None:
        raise invalid
    token = db.scalar(
        select(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id, PasswordResetToken.used_at.is_(None))
        .order_by(PasswordResetToken.created_at.desc())
    )
    now = datetime.now(UTC)
    if token is None or token.expires_at <= now:
        raise invalid
    if token.attempts >= settings.password_reset_max_attempts:
        raise ApiError(429, "Too many wrong codes. Request a new code.")
    if not hmac.compare_digest(token.token_hash, _code_hash(user.id, body.code)):
        token.attempts += 1
        db.commit()
        left = settings.password_reset_max_attempts - token.attempts
        raise ApiError(400, f"Incorrect code. {left} attempt{'s' if left != 1 else ''} left." if left else
                       "Too many wrong codes. Request a new code.")

    user.password_hash = hash_password(body.new_password)
    token.used_at = now
    # A reset means the old password may be compromised: end all sessions.
    db.execute(
        update(UserSession)
        .where(UserSession.user_id == user.id, UserSession.revoked_at.is_(None))
        .values(revoked_at=now)
    )
    db.commit()
    return s.Message(message="Password reset. You can now log in with your new password.")


@router.post("/change-password", response_model=s.Message)
def change_password(body: s.ChangePasswordIn, user: CurrentUser, db: DbSession):
    if not verify_password(body.current_password, user.password_hash):
        raise ApiError(400, "Current password is incorrect.")
    if body.current_password == body.new_password:
        raise ApiError(400, "New password must be different from the current one.")
    user.password_hash = hash_password(body.new_password)
    db.commit()
    return s.Message(message="Password updated.")
