"""Application settings, read from environment variables.

Nothing secret is stored in the code. In Kubernetes these variables would be
injected from a Secret; locally they can come from a .env file (see .env.example).
"""
from functools import lru_cache

from pydantic import SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL

MIN_API_KEY_LENGTH = 24


class Settings(BaseSettings):
    # hide_input_in_errors stops a validation error from printing the bad value,
    # which matters here because the value could be a real API key.
    model_config = SettingsConfigDict(
        env_file=".env", extra="ignore", hide_input_in_errors=True
    )

    app_env: str = "dev"
    log_level: str = "INFO"
    enable_docs: bool = True

    # Database: either one full URL, or the separate parts below.
    database_url: SecretStr | None = None
    db_host: str | None = None
    db_port: int = 5432
    db_name: str | None = None
    db_user: str | None = None
    db_password: SecretStr | None = None

    # Comma-separated list, so a new key can be added before the old one is removed.
    api_keys: SecretStr = SecretStr("")

    @field_validator("api_keys")
    @classmethod
    def api_keys_must_be_long_enough(cls, value: SecretStr) -> SecretStr:
        for key in _split_keys(value.get_secret_value()):
            if len(key) < MIN_API_KEY_LENGTH:
                raise ValueError(
                    f"each API key must be at least {MIN_API_KEY_LENGTH} characters"
                )
        return value

    @property
    def api_key_list(self) -> list[str]:
        return _split_keys(self.api_keys.get_secret_value())

    def sqlalchemy_url(self) -> str | URL:
        """Build the database connection URL, or fail with a clear message."""
        if self.database_url is not None:
            return self.database_url.get_secret_value()

        missing = [
            name
            for name, value in (
                ("DB_HOST", self.db_host),
                ("DB_NAME", self.db_name),
                ("DB_USER", self.db_user),
                ("DB_PASSWORD", self.db_password),
            )
            if not value
        ]
        if missing:
            raise RuntimeError(
                "Database is not configured. Set DATABASE_URL or: " + ", ".join(missing)
            )

        # URL.create escapes special characters in the password for us.
        return URL.create(
            "postgresql+psycopg2",
            username=self.db_user,
            password=self.db_password.get_secret_value(),
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
        )


def _split_keys(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
