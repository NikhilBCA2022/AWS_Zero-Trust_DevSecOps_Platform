"""Shared test setup: every test gets a fresh in-memory database and a test API key."""
import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import Settings, get_settings
from app.database import Base, get_db

# Environment variables that influence application configuration.
# They must be cleared *before* ``app.main`` is imported, because
# ``app/main.py`` calls ``get_settings()`` at import time and the result is
# cached by ``@lru_cache``.  If they are left in place, the developer's shell
# environment leaks into the test configuration (log level, docs visibility,
# API keys, database URL, …) and can never be undone for the test session.
_ENV_VARS_TO_ISOLATE = (
    "APP_ENV",
    "LOG_LEVEL",
    "ENABLE_DOCS",
    "DATABASE_URL",
    "DB_HOST",
    "DB_PORT",
    "DB_NAME",
    "DB_USER",
    "DB_PASSWORD",
    "API_KEYS",
)

for _name in _ENV_VARS_TO_ISOLATE:
    os.environ.pop(_name, None)

from app.main import app  # noqa: E402 – must come after env-var cleanup above

TEST_API_KEY = "test-key-0123456789-abcdefghij"


@pytest.fixture(autouse=True)
def isolate_application_environment(monkeypatch):
    """Prevent the developer's shell environment from leaking into tests."""
    for name in _ENV_VARS_TO_ISOLATE:
        monkeypatch.delenv(name, raising=False)


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,  # one shared connection, so the in-memory DB persists
    )

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(dbapi_connection, _):
        dbapi_connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine, expire_on_commit=False)()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture
def client(db_session):
    app.dependency_overrides[get_db] = lambda: db_session
    app.dependency_overrides[get_settings] = lambda: Settings(
        _env_file=None, api_keys=TEST_API_KEY
    )
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def auth():
    return {"X-API-Key": TEST_API_KEY}


@pytest.fixture
def make_service(client, auth):
    def _make(name="payments-api", environment="dev", **extra):
        response = client.post(
            "/services",
            json={"name": name, "environment": environment, **extra},
            headers=auth,
        )
        assert response.status_code == 201, response.text
        return response.json()

    return _make


@pytest.fixture
def make_incident(client, auth):
    def _make(service_id, title="High latency", severity="HIGH", **extra):
        response = client.post(
            "/incidents",
            json={
                "title": title,
                "severity": severity,
                "service_id": service_id,
                **extra,
            },
            headers=auth,
        )
        assert response.status_code == 201, response.text
        return response.json()

    return _make
