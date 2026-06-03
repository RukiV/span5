from typing import Optional

from sqlmodel import Session, select

from ..models.user import User, UserCreate, UserUpdate
from .base_service import BaseService


class UserService(BaseService[User, UserCreate, UserUpdate]):
    def get_by_email(self, session: Session, email: str) -> Optional[User]:
        return session.exec(select(User).where(User.user_email == email)).first()


user_service = UserService(User)