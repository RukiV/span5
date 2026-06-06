from typing import Optional
from datetime import datetime

from sqlmodel import Session, select

from ..models.user import User, UserCreate, UserUpdate
from .base_service import BaseService


class UserService(BaseService[User, UserCreate, UserUpdate]):
    def get_by_email(self, session: Session, email: str) -> Optional[User]:
        return session.exec(select(User).where(User.user_email == email)).first()

    def last_login(self, session: Session, user: User) -> User:
        user.user_lastlogintime = datetime.utcnow()
        
        session.add(user)
        session.commit()
        session.refresh(user)

        return user

user_service = UserService(User)