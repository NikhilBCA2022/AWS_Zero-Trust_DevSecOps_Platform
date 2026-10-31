"""Database engine and session handling.

The engine is created lazily so /health can work when the database is
unavailable. AWS deployments can load credentials from Secrets Manager.
"""
import json
import logging
from collections.abc import Iterator
from functools import lru_cache

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.engine import URL
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings

logger = logging.getLogger(__name__)


class Base(DeclarativeBase):
    """Parent class for all database models."""


def _database_url_from_secret() -> URL:
    """Retrieve RDS credentials and build a SQLAlchemy URL."""
    settings = get_settings()

    if not settings.db_secret_arn:
        raise RuntimeError("Database secret ARN is not configured")

    try:
        client = boto3.client(
            "secretsmanager",
            region_name=settings.aws_region,
        )
        response = client.get_secret_value(
            SecretId=settings.db_secret_arn
        )
        secret_string = response.get("SecretString")

        if not secret_string:
            raise RuntimeError("Database secret has no SecretString")

        secret = json.loads(secret_string)

        username = secret.get("username")
        password = secret.get("password")

        if not username or not password:
            raise RuntimeError("Database secret is missing credentials")

        # Host and database name come from non-secret application settings.
        if not settings.db_host or not settings.db_name:
            raise RuntimeError(
                "DB_HOST and DB_NAME are required with DB_SECRET_ARN"
            )

        return URL.create(
            "postgresql+psycopg2",
            username=username,
            password=password,
            host=settings.db_host,
            port=settings.db_port,
            database=settings.db_name,
        )

    except (BotoCoreError, ClientError, json.JSONDecodeError, TypeError):
        logger.error("Unable to retrieve or parse database credentials")
        raise RuntimeError("Database credentials are unavailable") from None


@lru_cache
def get_engine():
    """Create the database engine on first use."""
    settings = get_settings()

    if settings.database_url is not None:
        url = settings.sqlalchemy_url()
    elif settings.db_secret_arn:
        url = _database_url_from_secret()
    else:
        # Existing local-development path.
        url = settings.sqlalchemy_url()

    return create_engine(url, pool_pre_ping=True)


@lru_cache
def get_sessionmaker() -> sessionmaker[Session]:
    return sessionmaker(bind=get_engine(), expire_on_commit=False)


def get_db() -> Iterator[Session]:
    """FastAPI dependency: one database session per request, always closed."""
    try:
        factory = get_sessionmaker()
    except (RuntimeError, BotoCoreError, ClientError):
        logger.error("Database configuration or credentials are unavailable")
        raise HTTPException(
            status_code=503,
            detail="Database unavailable",
        ) from None

    session = factory()
    try:
        yield session
    finally:
        session.close()