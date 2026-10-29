from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, CheckConstraint, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.user import User


class MediaAsset(Base):
    """An image uploaded from the dashboard. The file lives in MEDIA_DIR;
    restaurants, menu items, categories and offers point at it by `url`."""

    __tablename__ = "media_assets"
    __table_args__ = (CheckConstraint("size_bytes > 0", name="size_positive"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    file_name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)  # name in MEDIA_DIR
    original_name: Mapped[str] = mapped_column(String(255), nullable=False)
    content_type: Mapped[str] = mapped_column(String(50), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    url: Mapped[str] = mapped_column(String(500), nullable=False, unique=True)
    uploaded_by_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    uploaded_by: Mapped[User | None] = relationship()
