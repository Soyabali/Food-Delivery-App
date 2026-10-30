"""Public account deletion (/delete-account, /api/account-deletion/*)."""

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import func, select, update

from app.api.routes import account_deletion
from app.core.database import SessionLocal
from app.models import (
    AccountDeletionCode,
    Address,
    Cart,
    FavoriteRestaurant,
    Order,
    OrderItem,
    OrderStatus,
    User,
    UserSession,
)
from tests.conftest import ADMIN, DEMO, login
from tests.test_mobile_api import add, place

URL = "/api/account-deletion"


@pytest.fixture(autouse=True)
def fresh_limits():
    account_deletion.request_limiter.reset()
    account_deletion.verify_limiter.reset()


@pytest.fixture
def outbox(monkeypatch):
    """Captures deletion emails instead of sending them."""
    sent = []
    monkeypatch.setattr(
        "app.api.routes.account_deletion.email_service.send_account_deletion_code",
        lambda to, name, code, minutes: sent.append({"to": to, "code": code}),
    )
    return sent


def request_code(client, outbox, email=DEMO[0]) -> str:
    assert client.post(f"{URL}/request", json={"email": email}).status_code == 200
    return outbox[-1]["code"]


def verify(client, code, email=DEMO[0]):
    return client.post(f"{URL}/verify", json={"email": email, "code": code})


def set_order_status(status: OrderStatus) -> None:
    with SessionLocal() as db:
        db.execute(update(Order).values(status=status))
        db.commit()


def test_full_deletion_removes_personal_data_and_anonymises_orders(client, outbox, user, admin):
    add(client, user, menuItemId=11)
    order_number = place(client, user).json()["id"]
    set_order_status(OrderStatus.delivered)
    client.put("/api/favorites/restaurant/pizza-roma", headers=user)
    with SessionLocal() as db:
        user_id = db.scalar(select(User.id).where(User.email == DEMO[0]))

    code = request_code(client, outbox)
    assert outbox[-1]["to"] == DEMO[0]
    res = verify(client, code)
    assert res.status_code == 200, res.text
    token = res.json()["deletionToken"]
    assert res.json()["expiresInSeconds"] == 600

    res = client.post(f"{URL}/confirm", json={"deletionToken": token})
    assert res.status_code == 200, res.text

    with SessionLocal() as db:
        assert db.get(User, user_id) is None
        for model in (Address, UserSession, Cart, FavoriteRestaurant, AccountDeletionCode):
            assert db.scalar(select(func.count()).select_from(model).where(model.user_id == user_id)) == 0
        order = db.scalar(select(Order).where(Order.order_number == order_number))
        assert order.user_id is None and order.total > 0  # kept for accounting
        assert order.address_line.startswith("Removed") and order.address_latitude is None
        assert order.instructions is None
        assert all(i.note is None for i in db.scalars(select(OrderItem).where(OrderItem.order_id == order.id)))

    # Signed out everywhere, can't log in, link can't be reused.
    assert client.get("/api/auth/me", headers=user).status_code == 401
    assert client.post("/api/auth/login", json={"email": DEMO[0], "password": DEMO[1]}).status_code == 401
    again = client.post(f"{URL}/confirm", json={"deletionToken": token})
    assert again.status_code == 400 and "already deleted" in again.json()["message"]

    # The dashboard still lists the anonymised order.
    row = client.get("/api/admin/orders", headers=admin).json()["items"][0]
    assert row["orderNumber"] == order_number and row["customerName"] == "Deleted customer"
    assert row["customerId"] is None and row["customerPhone"] is None


def test_unknown_email_gets_same_answer_and_no_email(client, outbox):
    known = client.post(f"{URL}/request", json={"email": DEMO[0]}).json()
    unknown = client.post(f"{URL}/request", json={"email": "nobody@example.com"}).json()
    assert known == unknown and len(outbox) == 1
    assert verify(client, "123456", email="nobody@example.com").status_code == 400


def test_invalid_email_rejected(client, outbox):
    for bad in ("", "not-an-email", "a@"):
        assert client.post(f"{URL}/request", json={"email": bad}).status_code == 422
    assert outbox == []


def test_wrong_codes_lock_and_expired_code_fails(client, outbox):
    code = request_code(client, outbox)
    wrong = "000000" if code != "000000" else "111111"
    res = verify(client, wrong)
    assert res.status_code == 400 and "4 attempts left" in res.json()["message"]
    for _ in range(4):
        verify(client, wrong)
    assert verify(client, code).status_code == 429  # locked even with the right code

    # Resend cooldown applies only to unverified codes issued moments ago.
    with SessionLocal() as db:
        db.execute(update(AccountDeletionCode).values(created_at=datetime.now(UTC) - timedelta(minutes=5)))
        db.commit()
    code = request_code(client, outbox)
    with SessionLocal() as db:
        db.execute(update(AccountDeletionCode).values(expires_at=datetime.now(UTC) - timedelta(seconds=1)))
        db.commit()
    res = verify(client, code)
    assert res.status_code == 400 and "expired" in res.json()["message"]


def test_resend_cooldown_sends_one_email(client, outbox):
    client.post(f"{URL}/request", json={"email": DEMO[0]})
    client.post(f"{URL}/request", json={"email": DEMO[0]})
    assert len(outbox) == 1


def test_order_in_progress_blocks_deletion(client, outbox, user):
    add(client, user, menuItemId=11)
    place(client, user)
    res = verify(client, request_code(client, outbox))
    assert res.status_code == 409 and "in progress" in res.json()["message"]
    with SessionLocal() as db:
        assert db.scalar(select(User).where(User.email == DEMO[0])) is not None


def test_admin_accounts_cannot_be_deleted_here(client, outbox):
    res = verify(client, request_code(client, outbox, ADMIN[0]), email=ADMIN[0])
    assert res.status_code == 409 and "Admin" in res.json()["message"]
    login(client, *ADMIN)


def test_expired_or_fake_confirmation_token(client, outbox):
    token = verify(client, request_code(client, outbox)).json()["deletionToken"]
    with SessionLocal() as db:
        db.execute(update(AccountDeletionCode).values(confirm_expires_at=datetime.now(UTC) - timedelta(seconds=1)))
        db.commit()
    assert client.post(f"{URL}/confirm", json={"deletionToken": token}).status_code == 400
    assert client.post(f"{URL}/confirm", json={"deletionToken": "x" * 43}).status_code == 400
    login(client, *DEMO)  # still exists


def test_requests_are_rate_limited_per_ip(client, outbox):
    limit = account_deletion.request_limiter.limit
    for i in range(limit):
        assert client.post(f"{URL}/request", json={"email": f"user{i}@example.com"}).status_code == 200
    assert client.post(f"{URL}/request", json={"email": "one-more@example.com"}).status_code == 429


def test_public_page_is_served(client):
    res = client.get("/delete-account")
    assert res.status_code == 200 and "text/html" in res.headers["content-type"]
    assert "Delete Your Apna Food Account" in res.text and "Delete My Account" in res.text
    assert "{{" not in res.text  # placeholders filled
    assert "frame-ancestors 'none'" in res.headers["content-security-policy"]
