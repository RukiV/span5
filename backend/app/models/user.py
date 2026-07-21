from typing import Optional, Any
from datetime import datetime
from uuid import uuid4
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .validators import sanitize_text   # ← Import here

class UserBase(SQLModel):
    """Base model for user data."""
    user_name: str = Field(min_length=1, max_length=100)
    user_surname: str = Field(min_length=1, max_length=100)
    user_email: str = Field(max_length=150, regex=r'^[\w\.-]+@[\w\.-]+\.\w+$')
    user_number: Optional[str] = Field(default=None, max_length=20)
    user_password: str
    user_lastlogintime: Optional[datetime] = None
    user_lastlogouttime: Optional[datetime] = None
    user_status: str = Field(max_length=50)
    location_id: Optional[int] = None

    @field_validator('user_name', 'user_surname', 'user_email', 'user_number', mode='before')
    @classmethod
    def sanitize_input(cls, v: Any, info) -> Any:
        return sanitize_text(v)

class User(UserBase, Base, table=True):
    """Model for user data."""
    user_id: Optional[int] = Field(default=None, primary_key=True)
    user_uuid: str = Field(default_factory=lambda: str(uuid4()), unique=True, index=True, max_length=36)
    role_id: int = Field(foreign_key="role.role_id")
    location_id: Optional[int] = Field(default=None, foreign_key="location.location_id")


class UserCreate(UserBase):
    """Input model for creating user records."""
    role_id: int
    location_id: Optional[int] = None


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
    location_id: Optional[int] = None


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
    location_id: Optional[int] = None
