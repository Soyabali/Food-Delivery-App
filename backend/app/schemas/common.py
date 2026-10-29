from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    """JSON uses camelCase (what the Flutter app expects); Python uses snake_case."""

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, from_attributes=True)


class Message(CamelModel):
    message: str


T = TypeVar("T")


class Page(CamelModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    page_size: int
