"""Backwards-compatible auth dependencies.

The real implementations now live in ``auth/permissions.py``. This module
re-exports them so any lingering ``from ..auth.dependencies import ...`` keeps
working — but note the behaviour change: ``get_current_user`` now HARD-FAILS with
401 on a missing/invalid token instead of returning ``None``. Prefer importing
from ``auth.permissions`` (and use ``require_right`` for real gating).
"""

from typing import Optional

from fastapi import Depends, Request
from sqlmodel import Session

from ..db.database import getSession
from .permissions import (  # noqa: F401  (re-exported for compatibility)
    get_current_user,
    get_current_user_optional,
)


def get_current_user_id(request: Request, session: Session = Depends(getSession)) -> Optional[int]:
    """Return the caller's user_id, or None if unauthenticated.

    Kept only for audit-log attribution on endpoints that are already gated by a
    ``require_right`` dependency. It intentionally does NOT raise, so it can sit
    alongside the real authorization check without duplicating the 401.
    """
    user = get_current_user_optional(request=request, session=session)
    return user.user_id if user else None
