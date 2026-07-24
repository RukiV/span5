from typing import Optional

from fastapi import Depends, Request
from sqlmodel import Session

from ..db.database import getSession
from ..models.user import User
from ..services.user_service import user_service
from .session import verify_session_token


def get_current_user(request: Request, session: Session = Depends(getSession)) -> Optional[User]:
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None

    token = auth_header[len("Bearer "):].strip()
    payload = verify_session_token(token)
    if not payload:
        return None

    return user_service.getByID(session, payload.get("user_id"))


def get_current_user_id(request: Request, session: Session = Depends(getSession)) -> Optional[int]:
    user = get_current_user(request=request, session=session)
    return user.user_id if user else None
