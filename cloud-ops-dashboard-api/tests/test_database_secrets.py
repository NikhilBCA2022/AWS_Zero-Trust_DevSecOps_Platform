import json
from unittest.mock import Mock

import pytest
from botocore.exceptions import ClientError
from sqlalchemy.engine import URL

from app import database
from app.config import Settings, get_settings


@pytest.fixture(autouse=True)
def clear_database_caches(monkeypatch):
    """Keep tests isolated from cached settings and database engines."""
    database.get_engine.cache_clear()
    database.get_sessionmaker.cache_clear()
    get_settings.cache_clear()

    monkeypatch.setattr(
        database,
        "get_settings",
        lambda: Settings(
            _env_file=None,
            db_secret_arn="arn:aws:secretsmanager:ap-south-1:123456789012:secret:test",
            aws_region="ap-south-1",
            db_host="db.example.test",
            db_name="cloudops",
        ),
    )

    yield

    database.get_engine.cache_clear()
    database.get_sessionmaker.cache_clear()
    get_settings.cache_clear()


def test_secret_retrieval_builds_database_url(monkeypatch):
    fake_client = Mock()
    fake_client.get_secret_value.return_value = {
        "SecretString": json.dumps(
            {
                "username": "appuser",
                "password": "p@ss/word",
            }
        )
    }

    monkeypatch.setattr(database.boto3, "client", Mock(return_value=fake_client))

    url = database._database_url_from_secret()

    assert isinstance(url, URL)
    assert url.drivername == "postgresql+psycopg2"
    assert url.username == "appuser"
    assert url.password == "p@ss/word"
    assert url.host == "db.example.test"
    assert url.database == "cloudops"

    fake_client.get_secret_value.assert_called_once_with(
        SecretId=(
            "arn:aws:secretsmanager:ap-south-1:"
            "123456789012:secret:test"
        )
    )


@pytest.mark.parametrize(
    "secret_value",
    [
        {},
        {"username": "appuser"},
        {"password": "secret-password"},
    ],
)
def test_missing_secret_credentials_fail_safely(monkeypatch, secret_value):
    fake_client = Mock()
    fake_client.get_secret_value.return_value = {
        "SecretString": json.dumps(secret_value)
    }

    monkeypatch.setattr(database.boto3, "client", Mock(return_value=fake_client))

    with pytest.raises(RuntimeError):
        database._database_url_from_secret()


def test_aws_error_does_not_expose_service_details(monkeypatch):
    fake_client = Mock()
    fake_client.get_secret_value.side_effect = ClientError(
        {
            "Error": {
                "Code": "AccessDeniedException",
                "Message": "Sensitive internal detail",
            }
        },
        "GetSecretValue",
    )

    monkeypatch.setattr(database.boto3, "client", Mock(return_value=fake_client))

    with pytest.raises(RuntimeError) as exc_info:
        database._database_url_from_secret()

    assert "Sensitive internal detail" not in str(exc_info.value)
