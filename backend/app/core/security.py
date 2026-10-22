import os
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from jwt import InvalidTokenError
from pwdlib import PasswordHash

# No source-code fallback: configure JWT_SECRET_KEY in backend/.env.
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "")
if len(SECRET_KEY) < 32:
    raise RuntimeError(
        "JWT_SECRET_KEY must be configured with at least 32 characters "
        "in the backend environment."
    )

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(
    os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30")
)
_password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    """Hash passwords with a modern password-hashing algorithm (Argon2)."""
    if not password:
        raise ValueError("Password cannot be empty.")
    return _password_hash.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its salted password hash."""
    if not plain_password or not hashed_password:
        return False
    try:
        return _password_hash.verify(plain_password, hashed_password)
    except (ValueError, TypeError):
        return False


def create_access_token(
    data: dict[str, Any],
    expires_delta: timedelta | None = None,
) -> str:
    """Create a signed JWT access token with a UTC expiration timestamp."""
    to_encode = data.copy()
    expires_at = datetime.now(timezone.utc) + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode["exp"] = expires_at
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any]:
    """Decode a JWT; raise ValueError for malformed, invalid, or expired tokens."""
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except (InvalidTokenError, TypeError, ValueError) as exc:
        raise ValueError("Invalid or expired access token.") from exc
