import os

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "alqulaisi.db")

# Keep the existing SQLite database during the compatibility phase. PostgreSQL
# configuration/migration will be introduced separately with an explicit data
# migration plan, rather than silently switching databases.
SQLALCHEMY_DATABASE_URL = f"sqlite:///{DB_PATH}"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def ensure_schema_compatibility() -> None:
    """Add new nullable/auth columns to an existing SQLite database safely.

    SQLAlchemy create_all() does not alter existing tables. This small,
    idempotent migration preserves existing rows and lets older demo accounts
    remain present without granting them password-based access.
    """
    if engine.dialect.name != "sqlite":
        raise RuntimeError(
            "The legacy compatibility migration currently supports SQLite only."
        )

    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return

    existing_columns = {column["name"] for column in inspector.get_columns("users")}
    statements = []
    if "password_hash" not in existing_columns:
        statements.append("ALTER TABLE users ADD COLUMN password_hash VARCHAR")
    if "status" not in existing_columns:
        statements.append(
            "ALTER TABLE users ADD COLUMN status VARCHAR NOT NULL DEFAULT 'active'"
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
