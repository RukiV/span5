import json
import os
import urllib.parse
import urllib.request
import urllib.error
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlmodel import Session, select

from ....auth.security import hash_password, verify_password
from ....auth.session import (
    COOKIE_NAME,
    STATE_COOKIE_NAME,
    SESSION_DURATION_SECONDS,
    create_session_token,
    create_state_token,
    verify_session_token,
)
from ....db.database import getSession
from ....models.user import UserRead, UserCreate, UserUpdate, User
from ....services.user_service import user_service

router = APIRouter()

MICROSOFT_CLIENT_ID = os.getenv("MICROSOFT_CLIENT_ID")
MICROSOFT_CLIENT_SECRET = os.getenv("MICROSOFT_CLIENT_SECRET")
MICROSOFT_REDIRECT_URI = os.getenv("MICROSOFT_REDIRECT_URI", "http://localhost:8000/api/v1/auth/callback")
FRONTEND_SUCCESS_URL = os.getenv("FRONTEND_SUCCESS_URL", "http://localhost:3000")
MICROSOFT_AUTHORIZE_URL = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
MICROSOFT_TOKEN_URL = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
MICROSOFT_USERINFO_URL = "https://graph.microsoft.com/v1.0/me"
MICROSOFT_SCOPE = "openid profile email offline_access User.Read"


class LocalLogin(BaseModel):
    user_email: str
    user_password: str


class LocalRegister(BaseModel):
    user_name: str
    user_surname: str
    user_email: str
    user_password: str
    user_number: Optional[str] = None
    role_id: Optional[int] = 1


def _get_user_by_email(session: Session, email: str) -> Optional[User]:
    return session.exec(select(User).where(User.user_email == email)).first()


def _exchange_code_for_tokens(code: str) -> dict:
    if not MICROSOFT_CLIENT_ID or not MICROSOFT_CLIENT_SECRET:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Microsoft OAuth client configuration is missing.",
        )

    body = urllib.parse.urlencode(
        {
            "client_id": MICROSOFT_CLIENT_ID,
            "client_secret": MICROSOFT_CLIENT_SECRET,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": MICROSOFT_REDIRECT_URI,
            "scope": MICROSOFT_SCOPE,
        }
    ).encode("utf-8")

    request = urllib.request.Request(
        MICROSOFT_TOKEN_URL,
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )

    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Microsoft token exchange failed: {error_body}",
        )


def _fetch_microsoft_profile(access_token: str) -> dict:
    request = urllib.request.Request(
        MICROSOFT_USERINFO_URL,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Microsoft profile request failed: {error_body}",
        )


@router.get("/login-microsoft")
def login_microsoft(response: Response):
    state = create_state_token()
    query = urllib.parse.urlencode(
        {
            "client_id": MICROSOFT_CLIENT_ID,
            "response_type": "code",
            "redirect_uri": MICROSOFT_REDIRECT_URI,
            "response_mode": "query",
            "scope": MICROSOFT_SCOPE,
            "state": state,
        }
    )
    response = RedirectResponse(f"{MICROSOFT_AUTHORIZE_URL}?{query}")
    response.set_cookie(
        STATE_COOKIE_NAME,
        state,
        httponly=True,
        samesite="lax",
        max_age=300,
    )
    return response


@router.get("/callback")
def auth_callback(request: Request, response: Response, session: Session = Depends(getSession)):
    code = request.query_params.get("code")
    state = request.query_params.get("state")
    cookie_state = request.cookies.get(STATE_COOKIE_NAME)

    if not code or not state or not cookie_state or cookie_state != state:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid Microsoft OAuth callback state.",
        )

    token_payload = _exchange_code_for_tokens(code)
    access_token = token_payload.get("access_token")
    if not access_token:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Microsoft did not return an access token.",
        )

    profile = _fetch_microsoft_profile(access_token)
    email = profile.get("mail") or profile.get("userPrincipalName")
    if not email:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to obtain email from Microsoft profile.",
        )

    user = _get_user_by_email(session, email)
    if not user:
        # create a local user record for the Microsoft account
        user = user_service.create(
            session,
            UserCreate(
                user_name=profile.get("givenName", ""),
                user_surname=profile.get("surname", ""),
                user_email=email,
                user_number=None,
                user_password=hash_password(os.urandom(16).hex()),
                user_lastlogintime=datetime.utcnow(),
                user_lastlogouttime=None,
                user_status="active",
                role_id=int(os.getenv("DEFAULT_ROLE_ID", "1")),
            ),
        )
    else:
        user.user_lastlogintime = datetime.utcnow()
        session.add(user)
        session.commit()
        session.refresh(user)

    session_token = create_session_token(user.user_id)
    response = RedirectResponse(FRONTEND_SUCCESS_URL)
    response.set_cookie(
        COOKIE_NAME,
        session_token,
        httponly=True,
        samesite="lax",
        max_age=SESSION_DURATION_SECONDS,
    )
    response.delete_cookie(STATE_COOKIE_NAME)
    return response


@router.post("/login-local", response_model=UserRead)
def login_local(login: LocalLogin, response: Response, session: Session = Depends(getSession)):
    user = _get_user_by_email(session, login.user_email)
    if not user or not verify_password(login.user_password, user.user_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials.")

    user.user_lastlogintime = datetime.utcnow()
    session.add(user)
    session.commit()
    session.refresh(user)

    session_token = create_session_token(user.user_id)
    response.set_cookie(
        COOKIE_NAME,
        session_token,
        httponly=True,
        samesite="lax",
        max_age=SESSION_DURATION_SECONDS,
    )
    return user


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def register_local(register: LocalRegister, response: Response, session: Session = Depends(getSession)):
    if _get_user_by_email(session, register.user_email):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is already registered.")

    user = user_service.create(
        session,
        UserCreate(
            user_name=register.user_name,
            user_surname=register.user_surname,
            user_email=register.user_email,
            user_number=register.user_number,
            user_password=register.user_password,
            user_lastlogintime=datetime.utcnow(),
            user_lastlogouttime=None,
            user_status="active",
            role_id=register.role_id or 1,
        ),
    )

    session_token = create_session_token(user.user_id)
    response.set_cookie(
        COOKIE_NAME,
        session_token,
        httponly=True,
        samesite="lax",
        max_age=SESSION_DURATION_SECONDS,
    )
    return user


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
