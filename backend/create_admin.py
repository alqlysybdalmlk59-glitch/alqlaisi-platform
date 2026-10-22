"""Create the first/next administrator without a public registration endpoint.

Example:
  python -m backend.create_admin --name "Platform Admin" --phone "9677..." --email "admin@example.com"
The password is read interactively and is not accepted as a command-line argument.
"""
import argparse
import getpass
import os
import re
import sys
from pathlib import Path
from uuid import uuid4

ROOT = str(Path(__file__).resolve().parents[1])
BACKEND = str(Path(__file__).resolve().parent)
for item in (ROOT, BACKEND):
    if item not in sys.path:
        sys.path.insert(0, item)

import database
import models
from app.core.security import hash_password
from app.core.runtime_config import IS_PRODUCTION, validate_production_configuration


def main() -> None:
    parser = argparse.ArgumentParser(description="Provision an Al Qulaisi administrator account.")
    parser.add_argument("--name", required=True)
    parser.add_argument("--phone", required=True)
    parser.add_argument("--email", required=True)
    args = parser.parse_args()

    name = args.name.strip()
    phone = re.sub(r"[\s()-]", "", args.phone)
    email = args.email.strip().lower()
    if len(name) < 2 or len(phone) < 8 or not re.fullmatch(r"[+0-9]{8,20}", phone):
        parser.error("Provide a valid name and phone number.")
    if "@" not in email or email.endswith("@accounts.alqulaisi.invalid"):
        parser.error("Provide a real administrator email address.")

    validate_production_configuration()
    models.Base.metadata.create_all(bind=database.engine)
    database.ensure_schema_compatibility()

    with database.SessionLocal() as db:
        if db.query(models.DBUser).filter(
            (models.DBUser.email == email) | (models.DBUser.phone == phone)
        ).first():
            parser.error("An account with this email or phone already exists.")

        password = getpass.getpass("Administrator password (minimum 14 characters): ")
        confirmation = getpass.getpass("Confirm password: ")
        if len(password) < 14 or password != confirmation:
            parser.error("Password must be at least 14 characters and both entries must match.")

        account = models.DBUser(
            id=f"admin_{uuid4().hex}",
            name=name,
            email=email,
            role="ADMIN",
            phone=phone,
            address="",
            password_hash=hash_password(password),
            status="active",
            store_id=None,
            google_subject=None,
        )
        db.add(account)
        db.commit()
        print(f"Administrator created. Account ID: {account.id}")


if __name__ == "__main__":
    main()
