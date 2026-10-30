from pathlib import Path

from fastapi import APIRouter, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.api.routes import account_deletion, auth, cart, catalog, me, orders
from app.api.routes.admin import catalog as admin_catalog
from app.api.routes.admin import operations as admin_operations
from app.core.config import get_settings
from app.core.database import engine
from app.core.errors import register_error_handlers

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description=(
        "Backend for the Apna Food mobile app and web dashboard.\n\n"
        "* **Mobile API** — `/api/...` (same contract as the app's mock backend)\n"
        "* **Dashboard API** — `/api/admin/...` (admin role required)\n\n"
        "Authenticate with `Authorization: Bearer <token>` from `POST /api/auth/login`."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
register_error_handlers(app)

api = APIRouter(prefix="/api")
for module in (auth, catalog, me, cart, orders, account_deletion):
    api.include_router(module.router)

admin = APIRouter(prefix="/admin")
admin.include_router(admin_catalog.router)
admin.include_router(admin_operations.router)
api.include_router(admin)
app.include_router(api)
# Public web page: https://<your-domain>/delete-account (Google Play).
app.include_router(account_deletion.page_router)

Path(settings.media_dir).mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=settings.media_dir), name="media")


@app.get("/health", tags=["health"])
def health():
    """Liveness + database connectivity check."""
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"status": "ok", "database": "ok"}
