"""One-time idempotent bootstrap/migration command.

Production release command: python -m backend.migrate
Run this as a release step before starting web workers.
"""
import os
import sys
from pathlib import Path

ROOT = str(Path(__file__).resolve().parents[1])
BACKEND = str(Path(__file__).resolve().parent)
for item in (ROOT, BACKEND):
    if item not in sys.path:
        sys.path.insert(0, item)

import database
import models  # noqa: F401 - registers all SQLAlchemy models with Base
from app.core.runtime_config import IS_PRODUCTION, validate_production_configuration, validate_production_database_schema


def main() -> None:
    validate_production_configuration()
    # create_all creates missing tables but does not overwrite existing production data.
    # ensure_schema_compatibility applies the known additive auth/store-link upgrades.
    models.Base.metadata.create_all(bind=database.engine)
    database.ensure_schema_compatibility()
    if IS_PRODUCTION:
        validate_production_database_schema(database.engine)
    print("Al Qulaisi database schema bootstrap completed.")


if __name__ == "__main__":
    main()
