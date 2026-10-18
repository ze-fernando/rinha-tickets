import asyncio

from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import create_async_engine

from app.infra.database import Base
from app.ticket.models import Ticket  # noqa: F401

config = context.config
target_metadata = Base.metadata

DATABASE_URL = "sqlite+aiosqlite:///database.sqlite"


def run_migrations_offline() -> None:
    # Modo offline usa URL síncrona (sem +aiosqlite)
    sync_url = DATABASE_URL.replace("+aiosqlite", "")
    context.configure(
        url=sync_url,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        target_metadata=target_metadata,
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations():
    connectable = create_async_engine(DATABASE_URL, poolclass=pool.NullPool)
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
