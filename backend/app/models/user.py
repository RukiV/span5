from typing import Optional, Any
from datetime import datetime
from uuid import uuid4
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .validators import sanitize_text

_MAX_FAILED_ATTEMPTS = 5
_LOCKOUT_MINUTES = 15


class UserBase(SQLModel):
    """Base model for user data."""
    user_name: str = Field(min_length=1, max_length=100)
    user_surname: str = Field(min_length=1, max_length=100)
    user_email: str = Field(max_length=150, regex=r'^[\w\.-]+@[\w\.-]+\.\w+$')
    user_number: Optional[str] = Field(default=None, max_length=255)
    user_lastlogintime: Optional[datetime] = None
    user_lastlogouttime: Optional[datetime] = None
    user_status: str = Field(max_length=50)
    location_id: Optional[int] = None
    failed_login_attempts: int = Field(default=0)
    locked_until: Optional[datetime] = None

    @field_validator('user_name', 'user_surname', 'user_email', 'user_number', mode='before')
    @classmethod
    def sanitize_input(cls, v: Any, info) -> Any:
        return sanitize_text(v)


class User(UserBase, Base, table=True):
    """Model for user data."""
    user_id: Optional[int] = Field(default=None, primary_key=True)
    user_uuid: str = Field(default_factory=lambda: str(uuid4()), unique=True, index=True, max_length=36)
    role_id: int = Field(foreign_key="role.role_id")
    user_password: str = Field(max_length=255)

    @property
    def is_locked(self) -> bool:
        if self.locked_until is None:
            return False
        return datetime.utcnow() < self.locked_until


class UserCreate(UserBase):
    """Input model for creating user records."""
    user_password: str
    role_id: int


class UserRead(UserBase):
    """Output model for reading user records."""
    user_id: int
    user_uuid: str
    user_name: str
    user_surname: str
    user_email: str
    user_number: Optional[str] = None
    user_lastlogintime: Optional[datetime] = None
    user_lastlogouttime: Optional[datetime] = None
    user_status: str
    role_id: int
    failed_login_attempts: int = 0
    locked_until: Optional[datetime] = None
    user_password: str = Field(exclude=True)


class UserUpdate(SQLModel):
    """Input model for updating user records."""
    user_name: Optional[str] = None
    user_surname: Optional[str] = None
    user_email: Optional[str] = None
    user_number: Optional[str] = None
    user_password: Optional[str] = None
    user_lastlogintime: Optional[datetime] = None
    user_lastlogouttime: Optional[datetime] = None
    user_status: Optional[str] = None
    role_id: Optional[int] = None
    failed_login_attempts: Optional[int] = None
    locked_until: Optional[datetime] = None
