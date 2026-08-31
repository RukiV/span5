from typing import Optional
from datetime import datetime

<<<<<<< HEAD
from fastapi import HTTPException
from sqlmodel import Session, select

from ..auth.security import hash_password, validate_password_strength
from ..auth.crypto import encrypt_value, decrypt_value
=======
from sqlmodel import Session, select

>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
from ..models.user import User, UserCreate, UserUpdate
from .base_service import BaseService


class UserService(BaseService[User, UserCreate, UserUpdate]):
    """
    UserService - Gebruiker-bestuursdiens
<<<<<<< HEAD

    Hanteer gebruiker-verwante operasies soos soeken en laaste aanmelding-track.
    """

    def create(self, session: Session, data: UserCreate, user_id: Optional[int] = None) -> User:
        if self.get_by_email(session, data.user_email):
            raise HTTPException(
                status_code=409,
                detail="Daar is reeds 'n gebruiker met hierdie e-posadres.",
            )
        if getattr(data, "user_password", None):
            validate_password_strength(data.user_password)
            data = data.model_copy(update={"user_password": hash_password(data.user_password)})
        if getattr(data, "user_number", None):
            data = data.model_copy(update={"user_number": encrypt_value(data.user_number)})
        return super().create(session, data, user_id=user_id)

    def update(self, session: Session, id: int, data: UserUpdate, user_id: Optional[int] = None) -> Optional[User]:
        if getattr(data, "user_email", None):
            existing = self.get_by_email(session, data.user_email)
            if existing and existing.user_id != id:
                raise HTTPException(
                    status_code=409,
                    detail="Daar is reeds 'n gebruiker met hierdie e-posadres.",
                )
        if getattr(data, "user_password", None):
            validate_password_strength(data.user_password)
            data = data.model_copy(update={"user_password": hash_password(data.user_password)})
        if getattr(data, "user_number", None):
            data = data.model_copy(update={"user_number": encrypt_value(data.user_number)})
        return super().update(session, id, data, user_id=user_id)

=======
    
    Hanteer gebruiker-verwante operasies soos soeken en laaste aanmelding-track.
    """
    
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
    def get_by_email(self, session: Session, email: str) -> Optional[User]:
        """
        Soek gebruiker op e-posadres.
        Gebruik vir aanmelding en e-pos-duplikaat-kontrole.
<<<<<<< HEAD
=======
        
        Args:
            session: Databasis-sessie
            email: Gebruiker se e-posadres
            
        Returns:
            Gebruiker-objek of None as nie gevind
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
        """
        return session.exec(select(User).where(User.user_email == email)).first()

    def last_login(self, session: Session, user: User) -> User:
        """
        Opdateer laaste-aanmelding-tyd vir gebruiker.
        Geroep na suksesvolle aanmelding.
<<<<<<< HEAD

        Args:
            session: Databasis-sessie
            user: Gebruiker-objek om op te dateer

=======
        
        Args:
            session: Databasis-sessie
            user: Gebruiker-objek om op te dateer
            
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
        Returns:
            Opdateerde gebruiker-objek
        """
        # Stel huidige tyd as laaste aanmelding
        user.user_lastlogintime = datetime.utcnow()
<<<<<<< HEAD

=======
        
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
        # Stoor en herlaai uit database
        session.add(user)
        session.commit()
        session.refresh(user)

        return user

<<<<<<< HEAD

# Globale instansie van UserService vir lande-wye gebruik
user_service = UserService(User)
=======
# Globale instansie van UserService vir lande-wye gebruik
user_service = UserService(User)
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
