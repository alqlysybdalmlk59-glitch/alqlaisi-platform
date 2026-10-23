"""Fail-closed validation for production runtime configuration."""
import os
import re
from urllib.parse import parse_qs, urlsplit
from sqlalchemy import inspect

APP_ENV = os.getenv("APP_ENV", "development").strip().lower()
IS_PRODUCTION = APP_ENV in {"production", "prod"}
DEV_ORIGINS = "http://localhost:3000,http://localhost:5500,http://localhost:8080"
CORS_ORIGINS = [v.strip() for v in os.getenv("CORS_ALLOW_ORIGINS", DEV_ORIGINS).split(",") if v.strip()]
ALLOWED_HOSTS = [v.strip() for v in os.getenv("ALLOWED_HOSTS", "localhost,127.0.0.1,10.0.2.2,testserver").split(",") if v.strip()]


def validate_production_configuration() -> None:
    if not IS_PRODUCTION:
        return
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url.startswith(("postgresql://", "postgresql+psycopg://")):
        raise RuntimeError("Production requires PostgreSQL in DATABASE_URL; SQLite is development-only.")
    database_parts = urlsplit(database_url)
    sslmodes = parse_qs(database_parts.query).get("sslmode", [])
    if not sslmodes or sslmodes[0].lower() not in {"require", "verify-ca", "verify-full"}:
        raise RuntimeError("Production DATABASE_URL must explicitly require PostgreSQL TLS using sslmode=require or stronger.")
    secret = os.getenv("JWT_SECRET_KEY", "")
    forbidden = ("replace", "change_me", "test-only", "your-secret", "example")
    if len(secret) < 48 or any(marker in secret.lower() for marker in forbidden):
        raise RuntimeError("Production requires a unique random JWT_SECRET_KEY of at least 48 characters.")
    google_client_id = os.getenv("GOOGLE_CLIENT_ID", "").strip()
    if not re.fullmatch(r"[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com", google_client_id):
        raise RuntimeError(
            "Production requires a real-format Google Web OAuth client ID; placeholders are not accepted."
        )
    forwarded_allow_ips = os.getenv("FORWARDED_ALLOW_IPS", "").strip()
    if not forwarded_allow_ips:
        raise RuntimeError("Production requires explicit FORWARDED_ALLOW_IPS for trusted ingress proxies.")
    if any(value.strip() == "*" for value in forwarded_allow_ips.split(",")):
        raise RuntimeError("FORWARDED_ALLOW_IPS must not trust every proxy; configure exact trusted ingress addresses.")
    if not CORS_ORIGINS or "*" in CORS_ORIGINS:
        raise RuntimeError("Production requires explicit CORS_ALLOW_ORIGINS; wildcard origins are forbidden.")
    for origin in CORS_ORIGINS:
        parsed = urlsplit(origin)
        if parsed.scheme != "https" or not parsed.netloc or parsed.path not in ("", "/") or parsed.query or parsed.fragment:
            raise RuntimeError(f"Invalid production CORS origin {origin!r}; use HTTPS origins only.")
    raw_allowed_hosts = os.getenv("ALLOWED_HOSTS", "").strip()
    if not raw_allowed_hosts:
        raise RuntimeError("Production requires ALLOWED_HOSTS to be explicitly configured; local development defaults are not accepted.")
    if not ALLOWED_HOSTS or "*" in ALLOWED_HOSTS:
        raise RuntimeError("Production requires explicit ALLOWED_HOSTS; wildcard hosts are forbidden.")
    if any("://" in host or "/" in host for host in ALLOWED_HOSTS):
        raise RuntimeError("ALLOWED_HOSTS must contain hostnames only, not URLs.")


def validate_production_database_schema(engine) -> None:
    required = {
        "users": {"id", "email", "role", "status", "store_id", "password_hash", "google_subject"},
        "customer_addresses": {"id", "user_id", "label", "recipient_name", "phone", "address", "notes", "is_default", "created_at", "updated_at"},
        "vendor_stores": {"id", "status", "owner_user_id", "delivery_fee"},
        "products": {"id", "vendor_id", "price", "is_available", "review_status"},
        "orders": {"id", "client_id", "vendor_id", "items_price", "delivery_fee", "total_price", "delivery_agent_name", "delivery_agent_phone", "delivery_notes", "delivery_assigned_at", "delivery_delivered_at"},
        "support_tickets": {"id", "user_id", "status"},
        "order_status_history": {"id", "order_id", "old_status", "new_status", "changed_by_user_id", "changed_by_role", "created_at"},
        "vendor_ownership_history": {"id", "store_id", "previous_owner_user_id", "new_owner_user_id", "actor_user_id", "action", "verification_note", "created_at"},
        "product_reviews": {"id", "product_id", "order_id", "client_id", "reviewer_name", "rating", "comment", "created_at"},
    }
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    for table, required_columns in required.items():
        if table not in tables:
            raise RuntimeError(f"Production schema lacks {table!r}; run python -m backend.migrate first.")
        columns = {column["name"] for column in inspector.get_columns(table)}
        missing = required_columns - columns
        if missing:
            raise RuntimeError(
                f"Production schema lacks columns in {table}: {', '.join(sorted(missing))}; "
                "run python -m backend.migrate first."
            )
