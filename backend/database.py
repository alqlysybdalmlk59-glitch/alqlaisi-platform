import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

_REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(_REPOSITORY_ROOT / ".env")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "alqulaisi.db")

# Preserve the current SQLite database by default. PostgreSQL is supported when
# DATABASE_URL is explicitly configured; changing this setting does NOT copy
# existing SQLite records, so run a verified data migration before cutover.
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL") or f"sqlite:///{DB_PATH}"

_engine_options = {"pool_pre_ping": True}
if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    _engine_options["connect_args"] = {"check_same_thread": False}

engine = create_engine(SQLALCHEMY_DATABASE_URL, **_engine_options)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def ensure_schema_compatibility() -> None:
    """Add auth columns to existing SQLite/PostgreSQL users tables idempotently."""
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return

    existing_columns = {column["name"] for column in inspector.get_columns("users")}
    statements = []
    if "password_hash" not in existing_columns:
        if engine.dialect.name == "sqlite":
            statements.append("ALTER TABLE users ADD COLUMN password_hash VARCHAR")
        elif engine.dialect.name == "postgresql":
            statements.append(
                "ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR"
            )
        else:
            raise RuntimeError(
                f"Unsupported database dialect for auth migration: {engine.dialect.name}"
            )

    if "status" not in existing_columns:
        if engine.dialect.name == "sqlite":
            statements.append(
                "ALTER TABLE users ADD COLUMN status VARCHAR NOT NULL DEFAULT 'active'"
            )
        elif engine.dialect.name == "postgresql":
            statements.append(
                "ALTER TABLE users ADD COLUMN IF NOT EXISTS status VARCHAR NOT NULL DEFAULT 'active'"
            )
        else:
            raise RuntimeError(
                f"Unsupported database dialect for auth migration: {engine.dialect.name}"
            )

    if statements:
        with engine.begin() as connection:
            for statement in statements:
                connection.execute(text(statement))


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
