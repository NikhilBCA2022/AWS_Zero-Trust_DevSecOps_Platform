"""Database engine and session handling.

The engine is created lazily (on first use) so the app can start and answer
/health even if the database settings are missing or the database is down.
"""
import logging
from collections.abc import Iterator
from functools import lru_cache

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings

logger = logging.getLogger(__name__)


class Base(DeclarativeBase):
    """Parent class for all database models."""


@lru_cache
def get_engine():
    # pool_pre_ping tests a connection before use, so a restarted database
    # does not cause errors from stale connections.
    return create_engine(get_settings().sqlalchemy_url(), pool_pre_ping=True)


@lru_cache
def get_sessionmaker() -> sessionmaker[Session]:
    return sessionmaker(bind=get_engine(), expire_on_commit=False)


def get_db() -> Iterator[Session]:
    """FastAPI dependency: one database session per request, always closed."""
    try:
        factory = get_sessionmaker()
    except RuntimeError:
        logger.error("Database configuration is missing or invalid")
        raise HTTPException(status_code=503, detail="Database unavailable") from None
    session = factory()
    try:
        yield session
    finally:
        session.close()
