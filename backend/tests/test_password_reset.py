from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import update

from app.core.config import get_settings
from app.core.database import SessionLocal
from app.models import PasswordResetToken
from tests.conftest import DEMO, login

URL_FORGOT = "/api/auth/forgot-password"
URL_RESET = "/api/auth/reset-password"


@pytest.fixture
def outbox(monkeypatch):
    """Captures reset emails instead of sending them."""
    sent = []
    monkeypatch.setattr(
        "app.api.routes.auth.email_service.send_password_reset_code",
        lambda to, name, code, minutes: sent.append({"to": to, "name": name, "code": code, "minutes": minutes}),
    )
    return sent


def reset(client, code, password="BrandNew#2026", email=DEMO[0]):
    return client.post(URL_RESET, json={"email": email, "code": code, "newPassword": password})


def test_full_reset_flow_signs_out_everywhere(client, outbox, user):
    res = client.post(URL_FORGOT, json={"email": DEMO[0].upper()})
    assert res.status_code == 200
    assert len(outbox) == 1 and outbox[0]["to"] == DEMO[0] and outbox[0]["name"] == "Rahul Sharma"
    code = outbox[0]["code"]
    assert len(code) == 6 and code.isdigit() and outbox[0]["minutes"] == get_settings().password_reset_minutes

    assert reset(client, code).status_code == 200
    assert client.get("/api/auth/me", headers=user).status_code == 401  # old session revoked
    login(client, DEMO[0], "BrandNew#2026")
    assert client.post("/api/auth/login", json={"email": DEMO[0], "password": DEMO[1]}).status_code == 401
    assert reset(client, code).status_code == 400  # single use


def test_unknown_email_gets_same_response_and_no_email(client, outbox):
    known = client.post(URL_FORGOT, json={"email": DEMO[0]}).json()
    unknown = client.post(URL_FORGOT, json={"email": "nobody@example.com"}).json()
    assert known == unknown
    assert [m["to"] for m in outbox] == [DEMO[0]]


def test_wrong_codes_lock_after_max_attempts(client, outbox):
    client.post(URL_FORGOT, json={"email": DEMO[0]})
    code = outbox[0]["code"]
    wrong = "000000" if code != "000000" else "111111"
    messages = [reset(client, wrong).json()["message"] for _ in range(5)]
    assert messages[0] == "Incorrect code. 4 attempts left."
    assert messages[-1] == "Too many wrong codes. Request a new code."
    locked = reset(client, code)
    assert locked.status_code == 429  # even the right code is refused now


def test_resend_cooldown_and_only_newest_code_works(client, outbox):
    client.post(URL_FORGOT, json={"email": DEMO[0]})
    client.post(URL_FORGOT, json={"email": DEMO[0]})  # within cooldown -> ignored
    assert len(outbox) == 1
    first = outbox[0]["code"]

    with SessionLocal() as db:  # pretend the cooldown passed
        db.execute(update(PasswordResetToken).values(created_at=datetime.now(UTC) - timedelta(minutes=2)))
        db.commit()
    client.post(URL_FORGOT, json={"email": DEMO[0]})
    assert len(outbox) == 2
    second = outbox[1]["code"]
    if first != second:
        assert reset(client, first).status_code == 400
    assert reset(client, second).status_code == 200


def test_expired_code(client, outbox):
    client.post(URL_FORGOT, json={"email": DEMO[0]})
    with SessionLocal() as db:
        db.execute(update(PasswordResetToken).values(expires_at=datetime.now(UTC) - timedelta(seconds=1)))
        db.commit()
    res = reset(client, outbox[0]["code"])
    assert res.status_code == 400 and "expired" in res.json()["message"]


def test_validation(client):
    assert reset(client, "12ab56").status_code == 422
    assert reset(client, "123456", password="short").status_code == 422


def test_without_smtp_the_code_is_logged(client, caplog, monkeypatch):
    monkeypatch.setattr("app.services.email_service.smtp_configured", lambda: False)
    with caplog.at_level("WARNING", logger="apna_food.email"):
        client.post(URL_FORGOT, json={"email": DEMO[0]})
    assert "SMTP not configured" in caplog.text
    assert "password reset code is:" in caplog.text
