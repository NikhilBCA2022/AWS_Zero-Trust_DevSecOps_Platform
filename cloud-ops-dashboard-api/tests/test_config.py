import pytest

from app.config import Settings


def test_database_url_built_from_parts_escapes_password():
    settings = Settings(
        _env_file=None, db_host="db", db_name="ops", db_user="app", db_password="p@ss/word"
    )
    url = settings.sqlalchemy_url()
    assert url.host == "db"
    assert url.password == "p@ss/word"
    # The password must be hidden when the URL is printed.
    assert "p@ss/word" not in repr(url)


def test_missing_database_settings_give_clear_error():
    with pytest.raises(RuntimeError, match="DB_HOST"):
        Settings(_env_file=None).sqlalchemy_url()


def test_secrets_are_hidden_in_settings_repr():
    settings = Settings(_env_file=None, db_password="s3cret-value")
    assert "s3cret-value" not in repr(settings)
