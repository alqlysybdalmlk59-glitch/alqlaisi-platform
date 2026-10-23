"""Create a safe local-only .env for first-time Windows development.

This script never replaces an existing production environment file and never
prints the generated JWT secret.
"""
from __future__ import annotations

import secrets
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / ".env"
EXAMPLE_FILE = ROOT / ".env.example"
_PLACEHOLDER_MARKERS = ("replace", "change_me", "test-only", "your-secret", "example")


def _setting(lines: list[str], name: str) -> str | None:
    prefix = f"{name}="
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(prefix):
            return stripped[len(prefix):].strip().strip("'\"")
    return None


def _write_setting(lines: list[str], name: str, value: str) -> list[str]:
    prefix = f"{name}="
    output = list(lines)
    for index, line in enumerate(output):
        if line.strip().startswith(prefix):
            output[index] = f"{name}={value}"
            return output
    output.append(f"{name}={value}")
    return output


def _is_unsafe_secret(value: str | None) -> bool:
    if value is None or len(value) < 48:
        return True
    lowered = value.lower()
    return any(marker in lowered for marker in _PLACEHOLDER_MARKERS)


def main() -> int:
    if ENV_FILE.exists():
        content = ENV_FILE.read_text(encoding="utf-8-sig")
        lines = content.splitlines()
        app_env = (_setting(lines, "APP_ENV") or "development").lower()
        if app_env in {"prod", "production"}:
            print("Refusing to modify .env because APP_ENV is production.")
            return 2
    else:
        if not EXAMPLE_FILE.exists():
            print("Missing .env.example; cannot initialize local configuration.")
            return 2
        content = EXAMPLE_FILE.read_text(encoding="utf-8-sig")
        lines = content.splitlines()
        lines = _write_setting(lines, "APP_ENV", "development")
        # Blank DATABASE_URL intentionally selects the local SQLite database.
        if _setting(lines, "DATABASE_URL") is None:
            lines = _write_setting(lines, "DATABASE_URL", "")
        app_env = "development"

    secret = _setting(lines, "JWT_SECRET_KEY")
    if _is_unsafe_secret(secret):
        lines = _write_setting(lines, "JWT_SECRET_KEY", secrets.token_urlsafe(48))
        content = "\n".join(lines).rstrip() + "\n"
        ENV_FILE.write_text(content, encoding="utf-8", newline="\n")
        print("Created/updated local .env with a fresh random development JWT secret.")
    elif not ENV_FILE.exists():
        ENV_FILE.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8", newline="\n")
        print("Created local .env.")
    else:
        print("Existing local .env retained; its JWT secret already meets the development checks.")

    print("Development database: DATABASE_URL is blank (SQLite local file).")
    print("Google sign-in needs real OAuth setup; phone/password login does not.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
