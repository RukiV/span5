from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlmodel import Session

from ....auth.session import COOKIE_NAME, SESSION_DURATION_SECONDS, create_session_token, verify_session_token
from ....db.database import getSession
from ....models.user import UserRead, User
from ....services.user_service import user_service

router = APIRouter()


def _get_current_user(request: Request, session: Session) -> Optional[User]:
    token = request.cookies.get(COOKIE_NAME)
    if not token:
        return None
    payload = verify_session_token(token)
    if not payload:
        return None
    return user_service.getByID(session, payload.get("user_id"))


@router.get("/me", response_model=UserRead)
def current_user(request: Request, session: Session = Depends(getSession)):
    user = _get_current_user(request, session)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated.")
    return user


@router.post("/logout")
def logout(response: Response):
    response.delete_cookie(COOKIE_NAME)
    return {"detail": "Logged out."}


@router.get("/validate")
def validate_session(request: Request, session: Session = Depends(getSession)):
    """Validate the current session token and return basic payload info."""
    token = request.cookies.get(COOKIE_NAME)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated.")
    payload = verify_session_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session.")
    user = user_service.getByID(session, payload.get("user_id"))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")
    return {"valid": True, "user_id": user.user_id, "exp": payload.get("exp")}


@router.post("/refresh")
def refresh_session(request: Request, response: Response, session: Session = Depends(getSession)):
    """Refresh the session expiry by issuing a new session token."""
    token = request.cookies.get(COOKIE_NAME)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated.")
    payload = verify_session_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session.")
    user = user_service.getByID(session, payload.get("user_id"))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")

    new_token = create_session_token(user.user_id)
    response.set_cookie(
        COOKIE_NAME,
        new_token,
        httponly=True,
        samesite="lax",
        max_age=SESSION_DURATION_SECONDS,
    )
    return {"detail": "session refreshed", "user_id": user.user_id}


@router.post("/revoke")
def revoke_session(response: Response):
    """Revoke the current session by clearing the cookie."""
    response.delete_cookie(COOKIE_NAME)
    return {"detail": "session revoked"}
