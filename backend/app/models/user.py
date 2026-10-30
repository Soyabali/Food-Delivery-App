from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Numeric,
    SmallInteger,
    String,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.enums import UserRole


class User(TimestampMixin, Base):
    """A person who uses the app (customer) or the dashboard (admin)."""

    __tablename__ = "users"
    __table_args__ = (
        # Case-insensitive unique email.
        Index("uq_users_email_lower", func.lower(text("email")), unique=True),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str] = mapped_column(String(254), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(20))
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole, name="user_role"), nullable=False, server_default=UserRole.customer.value
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    # Address currently chosen for delivery (circular FK, nullable).
    selected_address_id: Mapped[int | None] = mapped_column(
        ForeignKey("addresses.id", ondelete="SET NULL", use_alter=True)
    )
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    addresses: Mapped[list[Address]] = relationship(
        back_populates="user",
        foreign_keys="Address.user_id",
        cascade="all, delete-orphan",
        order_by="Address.id",
    )
    selected_address: Mapped[Address | None] = relationship(
        foreign_keys=[selected_address_id], post_update=True
    )
    sessions: Mapped[list[UserSession]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class UserSession(Base):
    """One signed-in device. The token itself is never stored, only its hash."""

    __tablename__ = "user_sessions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    user_agent: Mapped[str | None] = mapped_column(String(255))

    user: Mapped[User] = relationship(back_populates="sessions")


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Wrong guesses so far; the code is locked after PASSWORD_RESET_MAX_ATTEMPTS.
    attempts: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="0")


class AccountDeletionCode(Base):
    """Ownership check for the public /delete-account page. The emailed
    6-digit code and the deletion token it is exchanged for are stored only
    as hashes. Removed together with the account (CASCADE)."""

    __tablename__ = "account_deletion_codes"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    # Wrong guesses so far; locked after ACCOUNT_DELETION_MAX_ATTEMPTS.
    attempts: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="0")
    # Set once the code is verified: the token "Confirm delete" must present.
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    confirm_token_hash: Mapped[str | None] = mapped_column(String(64), unique=True)
    confirm_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Address(TimestampMixin, Base):
    __tablename__ = "addresses"
    __table_args__ = (
        CheckConstraint("latitude BETWEEN -90 AND 90", name="latitude_range"),
        CheckConstraint("longitude BETWEEN -180 AND 180", name="longitude_range"),
        # At most one default address per user.
        Index(
            "uq_addresses_one_default_per_user",
            "user_id",
            unique=True,
            postgresql_where=text("is_default"),
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    label: Mapped[str] = mapped_column(String(40), nullable=False)  # Home, Work...
    line: Mapped[str] = mapped_column(String(300), nullable=False)
    icon: Mapped[str] = mapped_column(String(20), nullable=False, server_default="home")
    latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    is_default: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))

    user: Mapped[User] = relationship(back_populates="addresses", foreign_keys=[user_id])
