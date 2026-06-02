import base64
import hashlib
import hmac
import os
from typing import Optional

PBKDF2_ITERATIONS = 180000
HASH_NAME = "sha256"
SALT_BYTES = 16


def hash_password(password: str, salt: Optional[str] = None) -> str:
    if salt is None:
        salt = base64.urlsafe_b64encode(os.urandom(SALT_BYTES)).decode().rstrip("=")
    digest = hashlib.pbkdf2_hmac(HASH_NAME, password.encode("utf-8"), salt.encode("utf-8"), PBKDF2_ITERATIONS)
    hashed = base64.urlsafe_b64encode(digest).decode().rstrip("=")
    return f"{salt}${hashed}"


def verify_password(password: str, hashed_password: str) -> bool:
    try:
        salt, stored_hash = hashed_password.split("$", 1)
    except ValueError:
        return False
    return hmac.compare_digest(hash_password(password, salt), hashed_password)
