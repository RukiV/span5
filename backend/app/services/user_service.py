from typing import Optional
from datetime import datetime

from sqlmodel import Session, select

from ..auth.security import hash_password
from ..models.user import User, UserCreate, UserUpdate
from .base_service import BaseService


class UserService(BaseService[User, UserCreate, UserUpdate]):
    """
    UserService - Gebruiker-bestuursdiens

    Hanteer gebruiker-verwante operasies soos soeken en laaste aanmelding-track.
    """

    def create(self, session: Session, data: UserCreate, user_id: Optional[int] = None) -> User:
        # Never persist a plaintext password.
        if getattr(data, "user_password", None):
            data = data.model_copy(update={"user_password": hash_password(data.user_password)})
        return super().create(session, data, user_id=user_id)

    def update(self, session: Session, id: int, data: UserUpdate, user_id: Optional[int] = None) -> Optional[User]:
        # Only re-hash when a new password is actually supplied.
        if getattr(data, "user_password", None):
            data = data.model_copy(update={"user_password": hash_password(data.user_password)})
        return super().update(session, id, data, user_id=user_id)

    def get_by_email(self, session: Session, email: str) -> Optional[User]:
        """
        Soek gebruiker op e-posadres.
        Gebruik vir aanmelding en e-pos-duplikaat-kontrole.
        
        Args:
            session: Databasis-sessie
            email: Gebruiker se e-posadres
            
        Returns:
            Gebruiker-objek of None as nie gevind
        """
        return session.exec(select(User).where(User.user_email == email)).first()

    def last_login(self, session: Session, user: User) -> User:
        """
        Opdateer laaste-aanmelding-tyd vir gebruiker.
        Geroep na suksesvolle aanmelding.
        
        Args:
            session: Databasis-sessie
            user: Gebruiker-objek om op te dateer
            
        Returns:
            Opdateerde gebruiker-objek
        """
        # Stel huidige tyd as laaste aanmelding
        user.user_lastlogintime = datetime.utcnow()
        
        # Stoor en herlaai uit database
        session.add(user)
        session.commit()
        session.refresh(user)

        return user

# Globale instansie van UserService vir lande-wye gebruik
user_service = UserService(User)