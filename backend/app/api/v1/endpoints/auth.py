import hashlib
from typing import Optional
import os
<<<<<<< HEAD
import secrets
from datetime import datetime, timedelta, timezone
=======
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
import httpx
from pydantic import BaseModel

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlmodel import Session, select

<<<<<<< HEAD
from ....auth.session import (
    SESSION_DURATION_SECONDS, create_session_token, create_refresh_token,
    verify_session_token, revoke_token,
)
from ....auth.security import verify_password, is_hashed, hash_password, validate_password_strength, PasswordError
from ....auth.permissions import get_current_user, get_rights_for_role
=======
from ....auth.session import SESSION_DURATION_SECONDS, create_session_token, verify_session_token
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
from ....db.database import getSession
from ....models.user import UserRead, User, _MAX_FAILED_ATTEMPTS, _LOCKOUT_MINUTES
from ....models.revoked_token import RevokedToken
from ....models.password_reset import PasswordResetToken
from ....services.user_service import user_service
from ....services.email_service import send_password_reset
from ....middleware.rate_limit import limiter

router = APIRouter()


# Datamodel vir Microsoft-token-versoek
class MicrosoftTokenRequest(BaseModel):
    microsoft_token: str


<<<<<<< HEAD
# /auth/me response model. Deliberately a separate model (not UserRead, which is
# reused for /users) so the resolved rights list can ride along without bloating
# the generic user schema. This rights array is the single source of truth both
# the web and mobile clients read their menu/route permissions from.
class CurrentUserRead(UserRead):
    rights: list[str] = []
    unread_notifications_count: int = 0
    location_name: Optional[str] = None


=======
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
def _get_bearer_token(request: Request) -> Optional[str]:
    """
    Ekstraheer die Bearer-token uit die Authorization-header.
    Verwag formaat: "Bearer <token>"
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    return auth_header[len("Bearer "):].strip()


def _get_current_user(request: Request, session: Session) -> Optional[User]:
    """
    Haal die huidige gebruiker uit die Bearer-token.
    Verifieer token geldigheid en haal gebruiker van database.
    Kontroleer ook dat die token nie herroep is nie.
    """
    token = _get_bearer_token(request)
    if not token:
        return None
    # Verifieer token handtekening, verstryking en herroeping
    revoked_hashes = {
        r.token_hash for r in session.exec(
            select(RevokedToken).where(RevokedToken.expires_at > datetime.utcnow())
        ).all()
    }
    payload = verify_session_token(token, revoked_hashes=revoked_hashes)
    if not payload:
        return None
    # Haal gebruiker uit database
    return user_service.getByID(session, payload.get("user_id"))


def _check_system_access(user: User, request: Request):
    """
    Kontroleer of gebruiker toegang het tot FBS-stelsel.
    Slegs role_id >= 2 (FK-koÃ¶rdineerder en Administrator) mag aanmeld.
    Gewone gebruikers (role_id=1) word geweier met 403-fout.
    """
    client_type = request.headers.get("X-Client-Type")

    if user.role_id == 1 and client_type != "mobile":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Studente het slegs toegang via die mobiele app. Kontak Administrasie vir hulp asseblief: admin@akademia.co.za"
        )


<<<<<<< HEAD
@router.get("/me", response_model=CurrentUserRead)
def current_user(user: User = Depends(get_current_user), session: Session = Depends(getSession)):
    rights = sorted(get_rights_for_role(session, user.role_id))
    from ....services.notification_service import NotificationService
    from ....models.location import Location
    notif_svc = NotificationService(session)
    unread_count = notif_svc.get_unread_count(user.user_id)
    location_name = None
    if user.location_id is not None:
        loc = session.get(Location, user.location_id)
        location_name = loc.location_name if loc else None
    return CurrentUserRead(**user.model_dump(), rights=rights,
                           unread_notifications_count=unread_count,
                           location_name=location_name)


@router.post("/logout")
def logout(request: Request, session: Session = Depends(getSession)):
    token = _get_bearer_token(request)
    if token:
        payload = verify_session_token(token)
        if payload:
            revoked = RevokedToken(
                token_hash=hashlib.sha256(token.encode("utf-8")).hexdigest(),
                user_id=payload["user_id"],
                expires_at=datetime.fromtimestamp(payload["exp"]),
            )
            session.add(revoked)
            session.commit()
=======
@router.get("/me", response_model=UserRead)
def current_user(request: Request, session: Session = Depends(getSession)):
    user = _get_current_user(request, session)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated.")
    return user


@router.post("/logout")
def logout():
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
    return {"detail": "Logged out."}


class LoginRequest(BaseModel):
    user_email: str
    user_password: str


def _increment_failed_attempts(session: Session, user: User) -> None:
    user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
    if user.failed_login_attempts >= _MAX_FAILED_ATTEMPTS:
        user.locked_until = datetime.utcnow() + timedelta(minutes=_LOCKOUT_MINUTES)
    session.add(user)
    session.commit()


def _reset_failed_attempts(session: Session, user: User) -> None:
    user.failed_login_attempts = 0
    user.locked_until = None
    session.add(user)
    session.commit()


@router.post("/login")
@limiter.limit("10/minute")
def login(login_data: LoginRequest, request: Request, session: Session = Depends(getSession)):
    """
    Plaaslike aanmelding met e-pos en wagwoord.
    1. Soek gebruiker op e-posadres
    2. Verifieer wagwoord
    3. Kontroleer rol-toegang (role_id >= 2)
    4. Gee app-sessietoken terug
    """
    user = user_service.get_by_email(session, login_data.user_email)
<<<<<<< HEAD

    if not user:
=======
    
    # Verifieer dat gebruiker bestaan en wagwoord korrek is
    if not user or user.user_password != login_data.user_password:
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
<<<<<<< HEAD

    if user.is_locked:
        remaining = (user.locked_until - datetime.utcnow()).seconds // 60
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Account locked due to too many failed attempts. Try again in {remaining} minute(s)."
        )

    password_valid = False
    if is_hashed(user.user_password):
        password_valid = verify_password(login_data.user_password, user.user_password)
    else:
        # Legacy plaintext password migration
        if login_data.user_password == user.user_password:
            import logging
            logging.getLogger(__name__).warning(
                "Legacy plaintext password upgraded to hash on login for user_id=%s", user.user_id
            )
            user.user_password = hash_password(login_data.user_password)
            session.add(user)
            session.commit()
            password_valid = True

    if not password_valid:
        _increment_failed_attempts(session, user)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    _reset_failed_attempts(session, user)

=======
    
    # Kontroleer of gebruiker se rol toelaat toegang tot stelsel
    # Hierdie gee 403-fout vir gewone gebruikers (role_id=1)
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
    _check_system_access(user, request)

    app_token = create_session_token(user.user_id)
    refresh_token = create_refresh_token(user.user_id)
    return {
        "access_token": app_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user_id": user.user_id
    }


@router.get("/validate")
def validate_session(request: Request, session: Session = Depends(getSession)):
    """
    Valideer huidige sessie-token.
    Kontroleer of token nog geldig en onverstrek is.
    """
    # Haal token uit request-header
    token = _get_bearer_token(request)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated.")
    
    # Verifieer token handtekening, verstryking en herroeping
    revoked_hashes = {
        r.token_hash for r in session.exec(
            select(RevokedToken).where(RevokedToken.expires_at > datetime.utcnow())
        ).all()
    }
    payload = verify_session_token(token, revoked_hashes=revoked_hashes)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session.")
    
    # Kontroleer dat gebruiker nog bestaan in database
    user = user_service.getByID(session, payload.get("user_id"))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")
    
    # Gee geldigheids-status terug
    return {"valid": True, "user_id": user.user_id, "exp": payload.get("exp")}


@router.post("/refresh")
def refresh_session(request: Request, session: Session = Depends(getSession)):
    token = _get_bearer_token(request)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated.")

    revoked_hashes = {
        r.token_hash for r in session.exec(
            select(RevokedToken).where(RevokedToken.expires_at > datetime.utcnow())
        ).all()
    }

    payload = verify_session_token(token, revoked_hashes=revoked_hashes)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session.")

    if payload.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token type for refresh.")

    user = user_service.getByID(session, payload.get("user_id"))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")

    # Revoke the used refresh token (rotation)
    revoked = RevokedToken(
        token_hash=hashlib.sha256(token.encode("utf-8")).hexdigest(),
        user_id=user.user_id,
        expires_at=datetime.fromtimestamp(payload["exp"]),
    )
    session.add(revoked)

    new_token = create_session_token(user.user_id)
    new_refresh = create_refresh_token(user.user_id)
    session.commit()
    return {
        "detail": "session refreshed",
        "user_id": user.user_id,
        "access_token": new_token,
        "refresh_token": new_refresh,
    }


@router.post("/revoke")
<<<<<<< HEAD
def revoke_session(request: Request, session: Session = Depends(getSession)):
    token = _get_bearer_token(request)
    if token:
        payload = verify_session_token(token)
        if payload:
            revoked = RevokedToken(
                token_hash=hashlib.sha256(token.encode("utf-8")).hexdigest(),
                user_id=payload["user_id"],
                expires_at=datetime.fromtimestamp(payload["exp"]),
            )
            session.add(revoked)
            session.commit()
=======
def revoke_session():
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
    return {"detail": "session revoked"}


class ForgotPasswordRequest(BaseModel):
    user_email: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


@router.post("/forgot-password")
@limiter.limit("5/minute")
def forgot_password(data: ForgotPasswordRequest, request: Request, session: Session = Depends(getSession)):
    user = user_service.get_by_email(session, data.user_email)
    if not user:
        # Always return success to prevent email enumeration
        return {"detail": "If the email exists, a reset link has been sent."}

    raw_token = secrets.token_urlsafe(48)
    token_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()

    reset = PasswordResetToken(
        user_id=user.user_id,
        token_hash=token_hash,
        expires_at=PasswordResetToken.create_expiry(),
        used=False,
    )
    session.add(reset)
    session.commit()

    frontend_url = os.getenv("REACT_APP_API_URL", "http://localhost:3000").rstrip("/")
    reset_url = f"{frontend_url}/reset-password?token={raw_token}"

    send_password_reset(to_email=user.user_email, reset_url=reset_url)

    return {"detail": "If the email exists, a reset link has been sent."}


@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, session: Session = Depends(getSession)):
    token_hash = hashlib.sha256(data.token.encode("utf-8")).hexdigest()

    reset = session.exec(
        select(PasswordResetToken).where(
            PasswordResetToken.token_hash == token_hash,
            PasswordResetToken.used == False,
        )
    ).first()

    if not reset or reset.is_expired:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token.",
        )

    validate_password_strength(data.new_password)

    user = session.get(User, reset.user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User not found.",
        )

    user.user_password = hash_password(data.new_password)
    reset.used = True
    session.add(user)
    session.add(reset)
    session.commit()

    return {"detail": "Password has been reset successfully."}


@router.post("/microsoft")
@limiter.limit("10/minute")
async def microsoft_login(token_request: MicrosoftTokenRequest, request: Request, session: Session = Depends(getSession)):
    """
    Microsoft Azure AD aanmelding.
    1. Valideer Microsoft-token via Graph API
    2. Haal gebruiker se inligting van Microsoft
    3. Soek of skep gebruiker in ons database
    4. Kontroleer rol-toegang (Web vs Mobile)
    5. Gee app-token terug
    """
    try:
        # Stuur Microsoft-token na Graph API vir validasie en gebruiker-data
        async with httpx.AsyncClient() as client:
            graph_response = await client.get(
                "https://graph.microsoft.com/v1.0/me",
                headers={"Authorization": f"Bearer {token_request.microsoft_token}"}
            )

            # Kontroleer of Graph API-versoek suksesvol was
            if graph_response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"Invalid Microsoft token: {graph_response.text}"
                )

            # Ekstraheer gebruiker-data uit Graph API-respons
            user_data = graph_response.json()

        # Haal e-pos, voornaam, en van naam uit Microsoft-data
        user_email = user_data.get("userPrincipalName") or user_data.get("mail")
        user_name = user_data.get("givenName", "User")
        user_surname = user_data.get("surname", "Account")

        # Kontroleer dat ons e-pos het (vereist)
        if not user_email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not extract email from Microsoft"
            )

        # Soek of skep gebruiker in ons database
        existing_user = user_service.get_by_email(session, user_email)
        if existing_user:
            # Gebruiker bestaan reeds - gebruik hulle
            user = existing_user
        else:
            # Nuwe Microsoft gebruikers word nou as Student (1) geskep by verstek
            user = User(
                user_name=user_name,
                user_surname=user_surname,
                user_email=user_email,
                user_password="microsoft_oauth",                                                            #Default password
                user_status="active",
                role_id=1  # Standaard rol
            )
            session.add(user)
            session.commit()
            session.refresh(user)

        # Kontroleer of gebruiker se rol toelaat toegang tot stelsel (Mobiel vs Web)   
        _check_system_access(user, request)

        # Skep ons app se sessietoken (nie Microsoft se token nie)
        app_token = create_session_token(user.user_id)
        return {
            "access_token": app_token,
            "token_type": "bearer",
            "user_id": user.user_id
        }

    except HTTPException:
        # Moenie FastAPI foute (soos 403 Forbidden) vang en in 500's verander nie
        raise
    except httpx.HTTPError as e:
        # Hanteer netwerkfoute by Microsoft-verbinding
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Could not validate with Microsoft: {str(e)}"
        )
    except Exception as e:
        # Hanteer ander onverwagte foute
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Microsoft authentication failed: {str(e)}"
        )