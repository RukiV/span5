import base64
import hashlib
import hmac
import json
import os
import secrets
from datetime import datetime, timedelta, timezone

<<<<<<< HEAD
_DEFAULT_SECRET = "please-change-this-secret"
_DEV_ENVIRONMENTS = {"development", "dev", "local", "test", "testing"}

ENVIRONMENT = os.getenv("ENVIRONMENT", os.getenv("APP_ENV", "development")).strip().lower()
SECRET_KEY = os.getenv("AUTH_SECRET_KEY")

if not SECRET_KEY or SECRET_KEY == _DEFAULT_SECRET:
    if ENVIRONMENT in _DEV_ENVIRONMENTS:
        print(
            "WARNING: AUTH_SECRET_KEY is unset or the known default; using an "
            f"insecure development key because ENVIRONMENT='{ENVIRONMENT}'. Set a "
            "strong AUTH_SECRET_KEY for any non-development environment."
        )
        SECRET_KEY = _DEFAULT_SECRET
    else:
        raise RuntimeError(
            "AUTH_SECRET_KEY is not set (or is the known default) while "
            f"ENVIRONMENT='{ENVIRONMENT}'. Refusing to start: set a strong, secret "
            "AUTH_SECRET_KEY environment variable."
        )

=======
SECRET_KEY = os.getenv("AUTH_SECRET_KEY", "please-change-this-secret")
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
SESSION_DURATION_SECONDS = int(os.getenv("SESSION_DURATION_SECONDS", "7200"))
REFRESH_TOKEN_DURATION_SECONDS = int(os.getenv("REFRESH_TOKEN_DURATION_SECONDS", "86400"))


def _sign_message(message: bytes) -> str:
    return hmac.new(SECRET_KEY.encode("utf-8"), message, hashlib.sha256).hexdigest()


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_session_token(user_id: int) -> str:
<<<<<<< HEAD
=======
    #Moet not role add en dalk rights
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
    payload = {
        "user_id": user_id,
        "exp": int((datetime.now(timezone.utc) + timedelta(seconds=SESSION_DURATION_SECONDS)).timestamp()),
        "type": "access",
    }
    data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    payload_b64 = base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")
    signature = _sign_message(data)
    return f"{payload_b64}.{signature}"


def create_refresh_token(user_id: int) -> str:
    payload = {
        "user_id": user_id,
        "exp": int((datetime.now(timezone.utc) + timedelta(seconds=REFRESH_TOKEN_DURATION_SECONDS)).timestamp()),
        "type": "refresh",
        "jti": secrets.token_hex(16),
    }
    data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    payload_b64 = base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")
    signature = _sign_message(data)
    return f"{payload_b64}.{signature}"


def _parse_token(token: str) -> dict | None:
    try:
        payload_b64, signature = token.split(".")
        padded = payload_b64 + "=" * (-len(payload_b64) % 4)
        data = base64.urlsafe_b64decode(padded.encode("utf-8"))
        expected = _sign_message(data)
        if not hmac.compare_digest(signature, expected):
            return None
        payload = json.loads(data)
        if int(payload.get("exp", 0)) < int(datetime.now(timezone.utc).timestamp()):
            return None
        return payload
    except Exception:
        return None


def verify_session_token(token: str, revoked_hashes: set | None = None) -> dict | None:
    payload = _parse_token(token)
    if payload is None:
        return None
    if revoked_hashes and _hash_token(token) in revoked_hashes:
        return None
    return payload


def revoke_token(token: str, user_id: int, expires_at: datetime) -> dict:
    return {
        "token_hash": _hash_token(token),
        "user_id": user_id,
        "expires_at": expires_at,
    }


def create_state_token() -> str:
    return base64.urlsafe_b64encode(os.urandom(24)).decode("utf-8").rstrip("=")
