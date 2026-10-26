"""Reusable pagination query parameters (?limit=20&offset=0)."""
from dataclasses import dataclass

from fastapi import Query

DEFAULT_LIMIT = 20
MAX_LIMIT = 100


@dataclass
class Pagination:
    limit: int
    offset: int


def pagination_params(
    limit: int = Query(DEFAULT_LIMIT, ge=1, le=MAX_LIMIT, description="Page size"),
    offset: int = Query(0, ge=0, description="Number of records to skip"),
) -> Pagination:
    return Pagination(limit=limit, offset=offset)
