"""Backwards-compatible password helpers.

Both branches independently added password hashing: this module (pbkdf2_sha256)
and ``auth/security.py``. They are now consolidated onto a single implementation
in ``security.py`` (also pbkdf2_sha256, with an added ``is_hashed`` used by the
plaintext->hash migration). This module re-exports from there so any code
importing ``from ..auth.passwords import ...`` keeps working, without a divergent
second CryptContext.
"""

from .security import (  # noqa: F401  (re-exported for compatibility)
    hash_password,
    verify_password,
    is_hashed,
    pwd_context,
)
