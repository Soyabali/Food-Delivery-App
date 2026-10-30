"""Public account deletion (Google Play "Delete account URL").

1. POST /request  email -> emails a 6-digit code (same answer for any email)
2. POST /verify   email + code -> short-lived deletion token
3. POST /confirm  deletion token -> account deleted, orders anonymised

GET /delete-account serves the web page that drives these steps.
"""

import hmac
import html
import logging
import secrets
from datetime import UTC, datetime, timedelta
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Request
from fastapi.responses import HTMLResponse
from sqlalchemy import delete, func, select
from sqlalchemy.exc import SQLAlchemyError

from app.api.deps import DbSession
from app.core.config import get_settings
from app.core.errors import ApiError
from app.core.rate_limit import RateLimiter
from app.core.security import hash_token, new_token
from app.models import AccountDeletionCode, User
from app.schemas import public as s
from app.services import email_service
from app.services.account_deletion import DeletionBlocked, check_deletable, delete_account

log = logging.getLogger("apna_food.account_deletion")

router = APIRouter(prefix="/account-deletion", tags=["account deletion"])
page_router = APIRouter(tags=["account deletion"])

_settings = get_settings()
WINDOW_SECONDS = 15 * 60
request_limiter = RateLimiter(_settings.account_deletion_requests_per_ip, WINDOW_SECONDS)
verify_limiter = RateLimiter(_settings.account_deletion_verifies_per_ip, WINDOW_SECONDS)

TOO_MANY = ApiError(429, "Too many attempts from this device. Please wait 15 minutes and try again.")


def _client_ip(request: Request) -> str:
    # Behind a reverse proxy run uvicorn with --proxy-headers so this is the
    # visitor's address, not the proxy's.
    return request.client.host if request.client else "unknown"


def _find_by_email(db, email: str) -> User | None:
    return db.scalar(select(User).where(func.lower(User.email) == email.strip().lower()))


def _code_hash(user_id: int, code: str) -> str:
    return hash_token(f"delete:{user_id}:{code}")


@router.post("/request", response_model=s.Message)
def request_deletion(body: s.DeletionRequestIn, request: Request, db: DbSession, background: BackgroundTasks):
    """Emails a 6-digit code to the account owner. The response is identical
    whether or not the email is registered."""
    if not request_limiter.allow(_client_ip(request)):
        raise TOO_MANY
    settings = get_settings()
    response = s.Message(
        message="If an Apna Food account uses this email, we've sent a 6-digit code to it. "
        "It may take a minute to arrive; check your spam folder too."
    )
    user = _find_by_email(db, body.email)
    if user is None:
        return response

    now = datetime.now(UTC)
    latest = db.scalar(
        select(AccountDeletionCode)
        .where(AccountDeletionCode.user_id == user.id)
        .order_by(AccountDeletionCode.created_at.desc())
    )
    if latest and latest.verified_at is None and (now - latest.created_at).total_seconds() < settings.account_deletion_resend_seconds:
        return response  # resend cooldown: don't flood the inbox

    # Only the newest code is valid.
    db.execute(delete(AccountDeletionCode).where(AccountDeletionCode.user_id == user.id))
    code = f"{secrets.randbelow(1_000_000):06d}"
    db.add(
        AccountDeletionCode(
            user_id=user.id,
            code_hash=_code_hash(user.id, code),
            expires_at=now + timedelta(minutes=settings.account_deletion_code_minutes),
        )
    )
    db.commit()
    log.info("Account deletion code issued for user %s", user.id)
    background.add_task(
        email_service.send_account_deletion_code, user.email, user.full_name, code,
        settings.account_deletion_code_minutes,
    )
    return response


@router.post("/verify", response_model=s.DeletionVerifiedOut)
def verify_deletion(body: s.DeletionVerifyIn, request: Request, db: DbSession):
    """Checks the emailed code and returns the token that authorises deletion."""
    if not verify_limiter.allow(_client_ip(request)):
        raise TOO_MANY
    settings = get_settings()
    invalid = ApiError(400, "That code is incorrect or has expired. Request a new code.")
    user = _find_by_email(db, body.email)
    if user is None:
        raise invalid
    entry = db.scalar(
        select(AccountDeletionCode)
        .where(AccountDeletionCode.user_id == user.id, AccountDeletionCode.verified_at.is_(None))
        .order_by(AccountDeletionCode.created_at.desc())
    )
    now = datetime.now(UTC)
    if entry is None:
        raise invalid
    if entry.expires_at <= now:
        raise ApiError(400, "That code has expired. Request a new code.")
    if entry.attempts >= settings.account_deletion_max_attempts:
        raise ApiError(429, "Too many wrong codes. Request a new code.")
    if not hmac.compare_digest(entry.code_hash, _code_hash(user.id, body.code)):
        entry.attempts += 1
        db.commit()
        left = settings.account_deletion_max_attempts - entry.attempts
        raise ApiError(400, f"Incorrect code. {left} attempt{'s' if left != 1 else ''} left." if left else
                       "Too many wrong codes. Request a new code.")

    # Ownership is proven, so it's safe to say why deletion can't happen yet.
    try:
        check_deletable(db, user)
    except DeletionBlocked as exc:
        raise ApiError(409, str(exc)) from exc

    token = new_token()
    entry.verified_at = now
    entry.confirm_token_hash = hash_token(token)
    entry.confirm_expires_at = now + timedelta(minutes=settings.account_deletion_confirm_minutes)
    db.commit()
    return s.DeletionVerifiedOut(deletion_token=token, expires_in_seconds=settings.account_deletion_confirm_minutes * 60)


@router.post("/confirm", response_model=s.Message)
def confirm_deletion(body: s.DeletionConfirmIn, db: DbSession):
    """Permanently deletes the account the token was issued for."""
    entry = db.scalar(
        select(AccountDeletionCode).where(AccountDeletionCode.confirm_token_hash == hash_token(body.deletion_token))
    )
    if entry is None or entry.confirm_expires_at is None or entry.confirm_expires_at <= datetime.now(UTC):
        # A used token is gone with the account (CASCADE), so this also
        # covers "already deleted".
        raise ApiError(400, "This deletion request has expired or the account was already deleted. Please start again.")
    user = db.get(User, entry.user_id)
    try:
        delete_account(db, user)
        db.commit()
    except DeletionBlocked as exc:
        db.rollback()
        raise ApiError(409, str(exc)) from exc
    except SQLAlchemyError:
        db.rollback()
        log.exception("Account deletion failed for user %s", entry.user_id)
        raise ApiError(500, "We couldn't delete your account right now. Nothing was changed; please try again.")
    return s.Message(message="Your Apna Food account and personal data have been deleted.")


# ------------------------------------------------------------------ page

PAGE = Path(__file__).resolve().parents[3] / "web" / "delete-account" / "index.html"

PAGE_HEADERS = {
    "Content-Security-Policy": (
        "default-src 'self'; script-src 'self' 'unsafe-inline'; "
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
        "font-src https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'; "
        "frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
    ),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "no-cache",
}


@page_router.get("/delete-account", response_class=HTMLResponse, include_in_schema=False)
def deletion_page():
    settings = get_settings()
    support = html.escape(settings.support_email)
    contact = (
        f'Questions? Email <a href="mailto:{support}">{support}</a>.' if support else ""
    )
    page = (
        PAGE.read_text(encoding="utf-8")
        .replace("{{ORDER_RETENTION_YEARS}}", str(settings.order_retention_years))
        .replace("{{CODE_MINUTES}}", str(settings.account_deletion_code_minutes))
        .replace("{{SUPPORT_CONTACT}}", contact)
    )
    return HTMLResponse(page, headers=PAGE_HEADERS)
