"""Password hashing helpers.

Before this module existed, passwords were stored and compared in plaintext
(`user.user_password != login_data.user_password`). All password storage now
goes through a passlib ``CryptContext``.

Scheme: **pbkdf2_sha256** — pure-Python, so there is no native bcrypt C
dependency to build inside containers. (This is the single hashing entry point;
``auth/passwords.py`` re-exports from here so the two branches' password code
converged on one implementation.)

The helpers are deliberately tiny so they can be reused from:
- login verification (``auth/endpoints/auth.py``),
- user create/update (``services/user_service.py``),
- the one-time plaintext -> hash migration in ``db/seed.py``.

``is_hashed`` uses passlib's ``identify`` so the migration is idempotent: a value
that is already a recognised hash is left untouched, so the migration is safe to
re-run on every startup.
"""

from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def hash_password(password: str) -> str:
    """Return a pbkdf2_sha256 hash for ``password``."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Return True if ``plain_password`` matches ``hashed_password``.

    Never raises: a malformed/legacy hash simply fails verification.
    """
    if not plain_password or not hashed_password:
        return False
    try:
        return pwd_context.verify(plain_password, hashed_password)
    except (ValueError, TypeError):
        return False


def is_hashed(value: str) -> bool:
    """Return True if ``value`` already looks like a hash produced by this context.

    Used to detect legacy plaintext passwords so they can be migrated once.
    """
    if not value:
        return False
    try:
        return pwd_context.identify(value) is not None
    except (ValueError, TypeError):
        return False
