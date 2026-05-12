from typing import Optional
from datetime import datetime
from sqlmodel import SQLModel, Field
from .base import Base

class UserBase(SQLModel):
    user_name: str = Field(max_length=100)
    user_surname: str = Field(max_length=100)
    user_email: str = Field(max_length=150)
    user_number: Optional[str] = Field(default=None, max_length=20)
    user_password: str
    user_lastlogintime: Optional[datetime] = None
    user_lastlogouttime: Optional[datetime] = None
    user_status: str = Field(max_length=50)


class User(UserBase, Base, table=True):
    user_id: Optional[int] = Field(default=None, primary_key=True)
    role_id: int = Field(foreign_key="role.role_id")


class UserCreate(UserBase):
    role_id: int


class UserRead(UserBase):
    user_id: int
    role_id: int


class UserUpdate(SQLModel):
    user_name: Optional[str] = None
    user_surname: Optional[str] = None
    user_email: Optional[str] = None
    user_number: Optional[str] = None
    user_password: Optional[str] = None
    user_lastlogintime: Optional[datetime] = None
    user_lastlogouttime: Optional[datetime] = None
    user_status: Optional[str] = None
    role_id: Optional[int] = None