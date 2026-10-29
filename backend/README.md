# Apna Food API (FastAPI + PostgreSQL)

Full documentation: [`../docs/BACKEND_AND_DATABASE.md`](../docs/BACKEND_AND_DATABASE.md)
(schema, ER diagram, API reference, setup, mobile connection).

Quick start (Windows PowerShell):

```powershell
python -m venv .venv; .venv\Scripts\activate
pip install -r requirements-dev.txt
copy .env.example .env            # set DATABASE_URL + ADMIN_PASSWORD
alembic upgrade head              # create tables
python scripts/seed.py            # starter data
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API docs: http://localhost:8000/docs · Tests: `pytest` (needs `TEST_DATABASE_URL`, which gets wiped).
