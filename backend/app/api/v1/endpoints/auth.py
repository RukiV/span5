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


class MicrosoftTokenRequest(BaseModel):
    microsoft_token: str


def _get_bearer_token(request: Request) -> Optional[str]:
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    return auth_header[len("Bearer "):].strip()


def _get_current_user(request: Request, session: Session) -> Optional[User]:
    token = _get_bearer_token(request)
    if not token:
        return None
    payload = verify_session_token(token)
    if not payload:
        return None
    return user_service.getByID(session, payload.get("user_id"))


def _check_system_access(user: User, request: Request):
    """
    Check if user has access to the FBS system.
    Only role_id >= 2 (FK and Admin) can access the Web platform.
    Regular users (role_id=1/Students) are only allowed via the Mobile App.
    """
    client_type = request.headers.get("X-Client-Type")

    if user.role_id == 1 and client_type != "mobile":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Studente het slegs toegang via die mobiele app. Kontak Administrasie vir web-toegang."
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
def login(login_data: LoginRequest, request: Request, session: Session = Depends(getSession)):
    """Local login with email and password."""
    user = user_service.get_by_email(session, login_data.user_email)
    
    if not user or user.user_password != login_data.user_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    # Check if user has access to the FBS system (Mobile vs Web)
    _check_system_access(user, request)
    
    # Create app session token
    app_token = create_session_token(user.user_id)
    return {
        "access_token": app_token,
        "token_type": "bearer",
        "user_id": user.user_id
    }


@router.get("/validate")
def validate_session(request: Request, session: Session = Depends(getSession)):
    token = _get_bearer_token(request)
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
def refresh_session(request: Request, session: Session = Depends(getSession)):
    """Refresh the session expiry by issuing a new session token."""
    token = _get_bearer_token(request)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated.")
    payload = verify_session_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired session.")
    user = user_service.getByID(session, payload.get("user_id"))
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")

    new_token = create_session_token(user.user_id)
    return {"detail": "session refreshed", "user_id": user.user_id, "session_token": new_token}


@router.post("/revoke")
def revoke_session():
    return {"detail": "session revoked"}


@router.post("/microsoft")
async def microsoft_login(token_request: MicrosoftTokenRequest, request: Request, session: Session = Depends(getSession)):
    """Validate Microsoft token via Graph API and create/return app session token."""
    try:
        # Use the Microsoft token to get user info from Graph API
        async with httpx.AsyncClient() as client:
            graph_response = await client.get(
                "https://graph.microsoft.com/v1.0/me",
                headers={"Authorization": f"Bearer {token_request.microsoft_token}"}
            )
            if graph_response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"Invalid Microsoft token: {graph_response.text}"
                )
            user_data = graph_response.json()

        # Extract user info from Microsoft Graph
        user_email = user_data.get("userPrincipalName") or user_data.get("mail")
        user_name = user_data.get("givenName", "User")
        user_surname = user_data.get("surname", "Account")

        if not user_email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not extract email from Microsoft"
            )

        # Find or create user in our database
        existing_user = user_service.get_by_email(session, user_email)
        if existing_user:
            user = existing_user
        else:
            # Nuwe Microsoft gebruikers word nou as Student (1) geskep by verstek
            user = User(
                user_name=user_name,
                user_surname=user_surname,
                user_email=user_email,
                user_password="microsoft_oauth",
                user_status="active",
                role_id=1
            )
            session.add(user)
            session.commit()
            session.refresh(user)

        # Check if user has access to the FBS system (Mobile vs Web)
        _check_system_access(user, request)

        # Create our app's session token (not Microsoft's token)
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
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Could not validate with Microsoft: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Microsoft authentication failed: {str(e)}"
        )
