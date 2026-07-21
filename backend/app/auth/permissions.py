"""Authorization layer built on the ``Rights`` / ``RoleRight`` tables.

This is the single source of truth for "who may do what". Endpoints declare the
right they need with ``Depends(require_right("assets.manage"))`` instead of the
old ad-hoc ``role_id == N`` comparisons.

Two design decisions worth calling out (so they are not re-litigated later):

1. ``get_current_user`` HARD-FAILS with 401 when there is no valid token. This is
   the default for every endpoint. The old ``get_current_user`` returned ``None``
   on a missing/invalid token and nothing downstream checked for it, so most
   endpoints were reachable with no ``Authorization`` header at all. If an
   endpoint genuinely wants to allow anonymous access it must opt in explicitly
   via ``get_current_user_optional`` — "no auth" is never the silent default.

2. Rights are resolved fresh from the DB (never embedded in the session token),
   so a role/right change applies immediately. A tiny TTL cache keyed on
   ``role_id`` keeps this from becoming a query storm; it re-queries every
   ``_RIGHTS_CACHE_TTL_SECONDS``, so a right change propagates within that window.
"""

import time
from typing import Optional

from fastapi import Depends, HTTPException, Request, status
from sqlmodel import Session, select

from ..db.database import getSession
from ..models.role import Rights, RoleRight
from ..models.user import User
from ..services.user_service import user_service
from .session import verify_session_token


def _extract_bearer_token(request: Request) -> Optional[str]:
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    return auth_header[len("Bearer "):].strip()


def _resolve_user(request: Request, session: Session) -> Optional[User]:
    token = _extract_bearer_token(request)
    if not token:
        return None
    payload = verify_session_token(token)
    if not payload:
        return None
    return user_service.getByID(session, payload.get("user_id"))


def get_current_user(request: Request, session: Session = Depends(getSession)) -> User:
    """Resolve the authenticated user, or raise 401.

    This is the default authentication dependency for the whole API.
    """
    user = _resolve_user(request, session)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


def get_current_user_optional(
    request: Request, session: Session = Depends(getSession)
) -> Optional[User]:
    """Explicit opt-in for the rare endpoint that may serve anonymous callers."""
    return _resolve_user(request, session)


# --- Rights resolution -----------------------------------------------------

# role_id -> (expires_at_monotonic, frozenset_of_right_names)
_RIGHTS_CACHE: dict[int, tuple[float, frozenset[str]]] = {}
_RIGHTS_CACHE_TTL_SECONDS = 30.0


def clear_rights_cache() -> None:
    """Drop the cached rights (useful after seeding or in tests)."""
    _RIGHTS_CACHE.clear()


def get_rights_for_role(session: Session, role_id: int) -> frozenset[str]:
    """Return the set of right names granted to ``role_id`` (cheap join, cached)."""
    now = time.monotonic()
    cached = _RIGHTS_CACHE.get(role_id)
    if cached is not None and cached[0] > now:
        return cached[1]

    rows = session.exec(
        select(Rights.right_name)
        .join(RoleRight, RoleRight.right_id == Rights.right_id)
        .where(RoleRight.role_id == role_id)
    ).all()
    rights = frozenset(rows)
    _RIGHTS_CACHE[role_id] = (now + _RIGHTS_CACHE_TTL_SECONDS, rights)
    return rights


def user_has_right(session: Session, role_id: int, right_name: str) -> bool:
    return right_name in get_rights_for_role(session, role_id)


def require_right(right_name: str):
    """Dependency factory: 401 if unauthenticated, 403 if the right is missing.

    Usage: ``user: User = Depends(require_right("assets.manage"))``. The returned
    ``User`` is available to the endpoint for audit-log attribution / ownership
    checks.
    """

    def dependency(
        user: User = Depends(get_current_user),
        session: Session = Depends(getSession),
    ) -> User:
        if not user_has_right(session, user.role_id, right_name):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return user

    return dependency


def require_any_right(*right_names: str):
    """Like :func:`require_right` but passes if the user holds ANY of the rights.

    Used by image upload, which must be reachable both by asset managers
    (``assets.manage``) and by students attaching a photo to their own fault card
    (``faults.create_own``).
    """

    def dependency(
        user: User = Depends(get_current_user),
        session: Session = Depends(getSession),
    ) -> User:
        rights = get_rights_for_role(session, user.role_id)
        if not any(name in rights for name in right_names):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return user

    return dependency
