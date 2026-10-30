from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """All configuration comes from environment variables or `backend/.env`.

    See `.env.example` for documentation of each value.
    """

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Apna Food API"
    environment: str = "development"

    # postgresql+psycopg://USER:PASSWORD@HOST:PORT/DBNAME
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/apna_food"

    # Comma-separated list of web origins allowed to call the API (dashboard).
    cors_origins: str = "http://localhost:3000,http://localhost:5173"

    # Opaque bearer tokens: lifetime in days.
    session_days: int = 30

    # Password reset: 6-digit code emailed to the user.
    password_reset_minutes: int = 15
    password_reset_max_attempts: int = 5
    password_reset_resend_seconds: int = 45

    # Public account deletion page (/delete-account, used for Google Play).
    # A 6-digit code proves ownership; verifying it gives a short-lived
    # deletion token that the final "Confirm delete" step must present.
    account_deletion_code_minutes: int = 15
    account_deletion_max_attempts: int = 5
    account_deletion_resend_seconds: int = 60
    account_deletion_confirm_minutes: int = 10
    # Per client IP, per 15 minutes (in-memory, per server process).
    account_deletion_requests_per_ip: int = 5
    account_deletion_verifies_per_ip: int = 20
    # Anonymised order records are kept this long for tax/accounting law.
    # Shown on the public page: confirm the right period with your accountant.
    order_retention_years: int = 8
    # Shown on the deletion page for questions (optional).
    support_email: str = ""

    # Outgoing email (SMTP). Leave SMTP_HOST empty in development: emails are
    # then printed in the server log instead of being sent.
    # Gmail: host smtp.gmail.com, port 587, username = your Gmail address,
    # password = a 16-character App Password (not your normal password).
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from: str = ""  # e.g. "Apna Food <you@gmail.com>"; defaults to smtp_username

    # Business rules used for cart totals.
    standard_delivery_fee: int = 30
    free_delivery_threshold: int = 199
    tax_rate_percent: float = 5.0

    # Reference point used for restaurant distance when the user has no
    # address with coordinates (Bengaluru city centre).
    default_latitude: float = 12.9716
    default_longitude: float = 77.5946

    # Uploaded images (dashboard) are stored here and served at /media.
    media_dir: str = "media"
    public_base_url: str = "http://localhost:8000"
    max_upload_mb: int = 5

    # First admin account created by scripts/seed.py.
    admin_email: str = "admin@apnafood.com"
    admin_password: str = "Admin@12345"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
