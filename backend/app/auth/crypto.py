import os
import base64
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

_DEV_ENVIRONMENTS = {"development", "dev", "local", "test", "testing"}

_ENV = os.getenv("ENVIRONMENT", os.getenv("APP_ENV", "development")).strip().lower()
_ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY")
_fernet = None


def _get_fernet() -> Fernet:
    global _fernet
    if _fernet is not None:
        return _fernet

    raw_key = _ENCRYPTION_KEY
    if raw_key:
        key = base64.urlsafe_b64encode(
            PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=b"fbs-encryption-salt",
                iterations=600000,
            ).derive(raw_key.encode("utf-8"))
        )
    else:
        if _ENV not in _DEV_ENVIRONMENTS:
            raise RuntimeError(
                "ENCRYPTION_KEY is not set while ENVIRONMENT is not a development "
                "environment. Refusing to start: a random per-process key would make "
                "previously encrypted data unrecoverable after a restart. Set "
                "ENCRYPTION_KEY to a persistent, secret value."
            )
        # Development only: a random key means encrypted values do not survive a
        # restart, which is acceptable for local testing but never for production.
        key = Fernet.generate_key()

    _fernet = Fernet(key)
    return _fernet


def encrypt_value(plaintext: str) -> str:
    if not plaintext:
        return plaintext
    f = _get_fernet()
    return f.encrypt(plaintext.encode("utf-8")).decode("utf-8")


def decrypt_value(ciphertext: str) -> str:
    if not ciphertext:
        return ciphertext
    f = _get_fernet()
    return f.decrypt(ciphertext.encode("utf-8")).decode("utf-8")


def encrypt_bytes(data: bytes) -> bytes:
    if not data:
        return data
    f = _get_fernet()
    return f.encrypt(data)


def decrypt_bytes(data: bytes) -> bytes:
    if not data:
        return data
    f = _get_fernet()
    return f.decrypt(data)
