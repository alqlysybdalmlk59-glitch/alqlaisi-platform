import os
from pathlib import Path
from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

_REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(_REPOSITORY_ROOT / ".env")
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "alqulaisi.db")
# Selecting DATABASE_URL does not migrate data from the existing SQLite DB.
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL") or f"sqlite:///{DB_PATH}"
_options = {"pool_pre_ping": True}
if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    _options["connect_args"] = {"check_same_thread": False}
engine = create_engine(SQLALCHEMY_DATABASE_URL, **_options)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def ensure_schema_compatibility() -> None:
    """Idempotently add authentication and store-owner columns to an existing DB."""
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    if not tables:
        return
    additions = {
        "users": {
            "password_hash": "VARCHAR",
            "status": "VARCHAR NOT NULL DEFAULT 'active'",
            "store_id": "VARCHAR",
            "google_subject": "VARCHAR",
        },
        "vendor_stores": {
            "owner_user_id": "VARCHAR",
            "delivery_fee": "FLOAT NOT NULL DEFAULT 15.0",
        },
    }
    statements = []
    for table, columns in additions.items():
        if table not in tables:
            continue
        existing = {column["name"] for column in inspector.get_columns(table)}
        for name, sql_type in columns.items():
            if name in existing:
                continue
            if engine.dialect.name == "sqlite":
                statements.append(f"ALTER TABLE {table} ADD COLUMN {name} {sql_type}")
            elif engine.dialect.name == "postgresql":
                statements.append(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {name} {sql_type}")
            else:
                raise RuntimeError(f"Unsupported schema migration dialect: {engine.dialect.name}")
    if statements:
        with engine.begin() as connection:
            for statement in statements:
                connection.execute(text(statement))
    if "users" in tables and engine.dialect.name in {"sqlite", "postgresql"}:
        with engine.begin() as connection:
            connection.execute(text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ux_users_google_subject "
                "ON users (google_subject) WHERE google_subject IS NOT NULL"
            ))

    # NULL ownership is allowed for legacy rows; duplicate non-null owner mappings are not.
    if "vendor_stores" in tables and engine.dialect.name in {"sqlite", "postgresql"}:
        with engine.begin() as connection:
            connection.execute(text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_vendor_stores_owner_user_id "
                "ON vendor_stores (owner_user_id)"
            ))

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
