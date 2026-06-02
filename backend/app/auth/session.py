import base64
import hashlib
import hmac
import json
import os
from datetime import datetime, timedelta, timezone

SECRET_KEY = os.getenv("AUTH_SECRET_KEY", "please-change-this-secret")
SESSION_DURATION_SECONDS = int(os.getenv("SESSION_DURATION_SECONDS", "7200"))
COOKIE_NAME = "fbs_session"
STATE_COOKIE_NAME = "fbs_oauth_state"


def _sign_message(message: bytes) -> str:
    return hmac.new(SECRET_KEY.encode("utf-8"), message, hashlib.sha256).hexdigest()


def create_session_token(user_id: int) -> str:
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
