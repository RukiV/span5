from typing import Optional

from sqlmodel import Session, select

from ..auth.security import hash_password
from ..models.user import User, UserCreate, UserUpdate
from .base_service import BaseService


class UserService(BaseService[User, UserCreate, UserUpdate]):
    def create(self, session: Session, data: UserCreate) -> User:
        if data.user_password:
            data.user_password = hash_password(data.user_password)
        return super().create(session, data)

    def update(self, session: Session, id: int, data: UserUpdate) -> Optional[User]:
        if data.user_password:
            data.user_password = hash_password(data.user_password)
        return super().update(session, id, data)

    def get_by_email(self, session: Session, email: str) -> Optional[User]:
        return session.exec(select(User).where(User.user_email == email)).first()


user_service = UserService(User)