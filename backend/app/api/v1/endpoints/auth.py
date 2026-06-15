from typing import Optional
import os
import httpx
from pydantic import BaseModel

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlmodel import Session

from ....auth.session import SESSION_DURATION_SECONDS, create_session_token, verify_session_token
from ....db.database import getSession
from ....models.user import UserRead, User
from ....services.user_service import user_service

router = APIRouter()


# Datamodel vir Microsoft-token-versoek
class MicrosoftTokenRequest(BaseModel):
    microsoft_token: str


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
    """
    token = _get_bearer_token(request)
    if not token:
        return None
    # Verifieer token handtekening en verstryking
    payload = verify_session_token(token)
    if not payload:
        return None
    # Haal gebruiker uit database
    return user_service.getByID(session, payload.get("user_id"))


def _check_system_access(user: User):
    """
    Kontroleer of gebruiker toegang het tot FBS-stelsel.
    Slegs role_id >= 2 (FK-koördineerder en Administrator) mag aanmeld.
    Gewone gebruikers (role_id=1) word geweier met 403-fout.
    """
    if user.role_id == 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Jy het nie toegang tot die FBS stelsel nie. Kontak Administrasie asseblief: admin@akademia.co.za"
        )


@router.get("/me", response_model=UserRead)
def current_user(request: Request, session: Session = Depends(getSession)):
    user = _get_current_user(request, session)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated.")
    return user


@router.post("/logout")
def logout():
    return {"detail": "Logged out."}


class LoginRequest(BaseModel):
    user_email: str
    user_password: str


@router.post("/login")
def login(request: LoginRequest, session: Session = Depends(getSession)):
    """
    Plaaslike aanmelding met e-pos en wagwoord.
    1. Soek gebruiker op e-posadres
    2. Verifieer wagwoord
    3. Kontroleer rol-toegang (role_id >= 2)
    4. Gee app-sessietoken terug
    """
    # Soek gebruiker op basis van e-pos
    user = user_service.get_by_email(session, request.user_email)
    
    # Verifieer dat gebruiker bestaan en wagwoord korrekt is
    if not user or user.user_password != request.user_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    # Kontroleer of gebruiker se rol toelaat toegang tot stelsel
    # Hierdie gee 403-fout vir gewone gebruikers (role_id=1)
    _check_system_access(user)
    
    # Skep app-sessietoken vir gekwalifiseerde gebruiker
    app_token = create_session_token(user.user_id)
    return {
        "access_token": app_token,
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
    
    # Verifieer token handtekening en verstryking
    payload = verify_session_token(token)
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
    """
    Vernuwe sessie deur nuwe token uit te gee.
    Gebruik wanneer token binnekort verstryk.
    """
    # Haal huidige token uit request
    token = _get_bearer_token(request)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated.")
    
    # Verifieer token
    payload = verify_session_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session.")
    
    # Haal gebruiker en kontroleer dat bestaan
    user = user_service.getByID(session, payload.get("user_id"))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")

    # Skep nuwe token met verlengde verstryking
    new_token = create_session_token(user.user_id)
    return {"detail": "session refreshed", "user_id": user.user_id, "session_token": new_token}


@router.post("/revoke")
def revoke_session():
    return {"detail": "session revoked"}


@router.post("/microsoft")
async def microsoft_login(request: MicrosoftTokenRequest, session: Session = Depends(getSession)):
    """
    Microsoft Azure AD aanmelding.
    1. Valideer Microsoft-token via Graph API
    2. Haal gebruiker se inligting van Microsoft
    3. Soek of skep gebruiker in ons database
    4. Kontroleer rol-toegang
    5. Gee app-token terug
    """
    try:
        # Stuur Microsoft-token na Graph API vir validasie en gebruiker-data
        async with httpx.AsyncClient() as client:
            graph_response = await client.get(
                "https://graph.microsoft.com/v1.0/me",
                headers={"Authorization": f"Bearer {request.microsoft_token}"}
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
            # Skep nuwe gebruiker met standaard-rol (ID 1 = gewone Gebruiker)
            user = User(
                user_name=user_name,
                user_surname=user_surname,
                user_email=user_email,
                user_password="microsoft_oauth",  # Plaasvervanger vir OAuth-gebruikers
                user_status="active",
                role_id=1  # Standaard rol
            )
            session.add(user)
            session.commit()
            session.refresh(user)

        # Kontroleer of gebruiker se rol toelaat toegang tot stelsel
        # Hierdie gee 403-fout vir gewone gebruikers (role_id=1)
        _check_system_access(user)

        # Skep ons app se sessietoken (nie Microsoft se token nie)
        app_token = create_session_token(user.user_id)
        return {
            "access_token": app_token,
            "token_type": "bearer",
            "user_id": user.user_id
        }

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
