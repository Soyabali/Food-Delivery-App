"""Tests run against a real PostgreSQL database named by TEST_DATABASE_URL
(it is wiped and re-seeded for every test). Never point it at real data."""

import os

TEST_DB = os.environ.get(
    "TEST_DATABASE_URL", "postgresql+psycopg://postgres@localhost:55432/apna_food_test"
)
os.environ["DATABASE_URL"] = TEST_DB
os.environ["MEDIA_DIR"] = os.path.join(os.path.dirname(__file__), ".media")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.database import SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import Base  # noqa: E402
from scripts import seed as seeder  # noqa: E402

DEMO = ("rahul.sharma@example.com", "supersecret123")
ADMIN = ("admin@apnafood.com", "Admin@12345")


@pytest.fixture(scope="session", autouse=True)
def schema():
    with engine.begin() as conn:
        conn.exec_driver_sql("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
    Base.metadata.create_all(engine)
    yield
    engine.dispose()


@pytest.fixture(autouse=True)
def seeded(schema):
    db = SessionLocal()
    try:
        seeder.reset(db)
        seeder.seed(db)
    finally:
        db.close()


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def login(client, email, password) -> dict:
    res = client.post("/api/auth/login", json={"email": email, "password": password})
    assert res.status_code == 200, res.text
    return {"Authorization": f"Bearer {res.json()['token']}"}


@pytest.fixture
def user(client):
    return login(client, *DEMO)


@pytest.fixture
def admin(client):
    return login(client, *ADMIN)
