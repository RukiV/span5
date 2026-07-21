from typing import Optional
from datetime import datetime

from sqlmodel import Session, select

from ..models.user import User, UserCreate, UserUpdate
from .base_service import BaseService
from ..auth.passwords import hash_password


class UserService(BaseService[User, UserCreate, UserUpdate]):
    """
    UserService - Gebruiker-bestuursdiens
    
    Hanteer gebruiker-verwante operasies soos soeken en laaste aanmelding-track.
    """
    
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

    def create(self, session: Session, data: UserCreate, user_id: Optional[int] = None) -> User:
        # Hash password before persisting
        payload = data.model_dump()
        if payload.get("user_password"):
            payload["user_password"] = hash_password(payload["user_password"])

        obj = self.model.model_validate(payload)

        session.add(obj)
        try:
            session.flush()
            affected_id = self._extract_obj_id(obj)
            self._create_audit_log(
                session,
                "create",
                {
                    "previous_value": None,
                    "new_value": obj.model_dump(mode="json"),
                },
                affected_columns=None,
                user_id=user_id,
                affected_id=affected_id,
                json_data=obj.model_dump(mode="json"),
            )
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise

        return obj

    def update(self, session: Session, id: int, data: UserUpdate, user_id: Optional[int] = None) -> Optional[User]:
        obj = session.get(self.model, id)
        if not obj:
            return None

        before_data = obj.model_dump(mode="json")
        update_data = data.model_dump(exclude_unset=True)
        # If password present, hash it before updating
        if update_data.get("user_password"):
            update_data["user_password"] = hash_password(update_data["user_password"])
        obj.sqlmodel_update(update_data)

        session.add(obj)
        try:
            after_data = obj.model_dump(mode="json")
            changed_fields = self._get_changed_fields(before_data, after_data, update_data)
            if changed_fields:
                filtered_before = {field: before_data[field] for field in changed_fields}
                filtered_after = {field: after_data[field] for field in changed_fields}
                affected_id = self._extract_obj_id(obj)
                self._create_audit_log(
                    session,
                    "update",
                    {
                        "previous_value": filtered_before,
                        "new_value": filtered_after,
                    },
                    affected_columns=changed_fields,
                    user_id=user_id,
                    affected_id=affected_id,
                    json_data=after_data,
                )
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise

        return obj

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