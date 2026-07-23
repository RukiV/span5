import base64
import hashlib
import hmac
import json
import os
from datetime import datetime, timedelta, timezone

# The token signing key must never fall back to a shipped default in a real
# deployment: anyone who knows it can forge valid session tokens for any user.
# We therefore fail fast at import time (i.e. at startup) unless the app is
# explicitly running in a local/dev/test environment.
_DEFAULT_SECRET = "please-change-this-secret"
_DEV_ENVIRONMENTS = {"development", "dev", "local", "test", "testing"}

ENVIRONMENT = os.getenv("ENVIRONMENT", os.getenv("APP_ENV", "development")).strip().lower()
SECRET_KEY = os.getenv("AUTH_SECRET_KEY")

if not SECRET_KEY or SECRET_KEY == _DEFAULT_SECRET:
    if ENVIRONMENT in _DEV_ENVIRONMENTS:
        # Dev/test convenience only. This key is public knowledge — never rely
        # on it anywhere real. Set ENVIRONMENT=production (or any non-dev value)
        # and the block below turns this into a hard startup failure.
        # ASCII only: this runs at startup and may print to a Windows cp1252
        # console, where non-ASCII characters raise UnicodeEncodeError.
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

SESSION_DURATION_SECONDS = int(os.getenv("SESSION_DURATION_SECONDS", "7200"))


def _sign_message(message: bytes) -> str:
    return hmac.new(SECRET_KEY.encode("utf-8"), message, hashlib.sha256).hexdigest()


def create_session_token(user_id: int) -> str:
    # Deliberately store ONLY the user_id (plus expiry) in the token — never the
    # role or the resolved rights. The user (and their rights) are re-resolved
    # from the DB on every request (see auth/permissions.py), so a role change or
    # a RoleRight change takes effect immediately without having to revoke any
    # outstanding tokens. (This resolves the old "#Moet not role add en dalk
    # rights" note that used to sit here.)
    payload = {
        "user_id": user_id,
        "exp": int((datetime.now(timezone.utc) + timedelta(seconds=SESSION_DURATION_SECONDS)).timestamp()),
    }
    data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    payload_b64 = base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")
    signature = _sign_message(data)
    return f"{payload_b64}.{signature}"


def verify_session_token(token: str) -> dict | None:
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


def create_state_token() -> str:
    return base64.urlsafe_b64encode(os.urandom(24)).decode("utf-8").rstrip("=")
