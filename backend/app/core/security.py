import os
import hmac
import hashlib
import base64
import json
import time
from typing import Optional, Dict, Any
from datetime import datetime, timedelta

# Default secret key (should be set via environment variable in production)
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "alqulaisi-secure-jwt-secret-key-2026-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours


# --------------------------------------------------------------------------
# Password Hashing using PBKDF2 with SHA-256 (standard library compatible)
# --------------------------------------------------------------------------

def hash_password(password: str) -> str:
    """
    Hashes a password using PBKDF2-HMAC-SHA256 with a unique random salt.
    Format: pbkdf2_sha256$iterations$salt$hash
    """
    salt = base64.b64encode(os.urandom(16)).decode("ascii")
    iterations = 100_000
    derived = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        iterations
    )
    b64_hash = base64.b64encode(derived).decode("ascii")
    return f"pbkdf2_sha256${iterations}${salt}${b64_hash}"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verifies a plain password against the stored PBKDF2 hash.
    Constant-time comparison prevents timing attacks.
    """
    try:
        parts = hashed_password.split("$")
        if len(parts) != 4 or parts[0] != "pbkdf2_sha256":
            return False
        iterations = int(parts[1])
        salt = parts[2]
        stored_hash = parts[3]
        
        derived = hashlib.pbkdf2_hmac(
            "sha256",
            plain_password.encode("utf-8"),
            salt.encode("utf-8"),
            iterations
        )
        b64_hash = base64.b64encode(derived).decode("ascii")
        return hmac.compare_digest(b64_hash, stored_hash)
    except Exception:
        return False


# --------------------------------------------------------------------------
# JWT Token Generation and Decoding (Standard HS256 JWT format)
# --------------------------------------------------------------------------

def _base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _base64url_decode(data: str) -> bytes:
    padding = "=" * (4 - (len(data) % 4)) if len(data) % 4 != 0 else ""
    return base64.urlsafe_b64decode((data + padding).encode("ascii"))


def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """
    Generates a cryptographically signed JWT token for user authentication.
    Claims embedded:
      - sub: user id
      - email: user email
      - role: customer | seller | admin
      - store_id: vendor store ID (if seller)
      - exp: expiration timestamp
    """
    to_encode = data.copy()
    now = int(time.time())
    if expires_delta:
        expire = now + int(expires_delta.total_seconds())
    else:
        expire = now + (ACCESS_TOKEN_EXPIRE_MINUTES * 60)
        
    to_encode.update({"iat": now, "exp": expire})
    
    header = {"alg": ALGORITHM, "typ": "JWT"}
    header_bytes = json.dumps(header, separators=(",", ":")).encode("utf-8")
    payload_bytes = json.dumps(to_encode, separators=(",", ":")).encode("utf-8")
    
    b64_header = _base64url_encode(header_bytes)
    b64_payload = _base64url_encode(payload_bytes)
    
    signing_input = f"{b64_header}.{b64_payload}".encode("ascii")
    signature = hmac.new(SECRET_KEY.encode("utf-8"), signing_input, hashlib.sha256).digest()
    b64_signature = _base64url_encode(signature)
    
    return f"{b64_header}.{b64_payload}.{b64_signature}"


def decode_access_token(token: str) -> Dict[str, Any]:
    """
    Validates signature, expiration, and decodes the JWT payload.
    Raises ValueError on invalid token or expiration.
    """
    parts = token.strip().split(".")
    if len(parts) != 3:
        raise ValueError("Invalid JWT token structure")
        
    b64_header, b64_payload, b64_signature = parts
    
    # Verify signature
    signing_input = f"{b64_header}.{b64_payload}".encode("ascii")
    expected_sig = hmac.new(SECRET_KEY.encode("utf-8"), signing_input, hashlib.sha256).digest()
    actual_sig = _base64url_decode(b64_signature)
    
    if not hmac.compare_digest(expected_sig, actual_sig):
        raise ValueError("Invalid token signature")
        
    payload_json = _base64url_decode(b64_payload).decode("utf-8")
    payload = json.loads(payload_json)
    
    # Verify expiration
    now = int(time.time())
    if "exp" in payload and payload["exp"] < now:
        raise ValueError("Token has expired")
        
    return payload
