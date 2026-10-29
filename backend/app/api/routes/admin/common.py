from collections.abc import Callable, Sequence
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.errors import ApiError


def paginate(db: Session, stmt, page: int, page_size: int) -> tuple[list[Any], int]:
    total = db.scalar(select(func.count()).select_from(stmt.order_by(None).subquery()))
    rows = db.scalars(stmt.offset((page - 1) * page_size).limit(page_size)).all()
    return list(rows), total or 0


def sync_children(
    existing: list[Any],
    incoming: Sequence[Any],
    create: Callable[[dict], Any],
    label: str,
) -> None:
    """Make `existing` (a relationship list) match `incoming` payloads:
    items with an `id` are updated, new ones created, missing ones deleted."""
    by_id = {child.id: child for child in existing}
    keep = []
    for item in incoming:
        data = item.model_dump(exclude={"id"})
        if item.id is not None:
            child = by_id.get(item.id)
            if child is None:
                raise ApiError(400, f"{label} {item.id} does not belong to this record.")
            for key, value in data.items():
                setattr(child, key, value)
        else:
            child = create(data)
        keep.append(child)
    existing[:] = keep


def apply_patch(obj: Any, patch, exclude: set[str] = frozenset()) -> None:
    """Copy only the fields the client actually sent."""
    for key, value in patch.model_dump(exclude_unset=True, exclude=exclude).items():
        setattr(obj, key, value)
