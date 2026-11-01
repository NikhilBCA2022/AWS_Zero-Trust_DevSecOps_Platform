"""Alembic environment: tells Alembic which database and which models to use."""
from logging.config import fileConfig

from alembic import context

from app import models  # noqa: F401  (importing registers the tables)
from app.config import get_settings
from app.database import Base, get_engine

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=get_settings().sqlalchemy_url(),
        target_metadata=target_metadata,
        literal_binds=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    # Use the app's engine so credentials come from Secrets Manager in EKS.
    engine = get_engine()
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
