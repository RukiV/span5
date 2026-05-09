from typing import Optional
from datetime import datetime
from sqlmodel import Field
from .base import Base

class User(Base, table=True):
    user_id: Optional[int] = Field(default=None, primary_key=True)
    role_id: Optional[int] = Field(default=None, foreign_key="role.role_id")

    user_name: Optional[str] = Field(default=None, max_length=100)
    user_surname: Optional[str] = Field(default=None, max_length=100)
    user_email: Optional[str] = Field(default=None, max_length=150)
    user_number: Optional[str] = Field(default=None, max_length=20)
    user_password: Optional[str] = None

    user_lastlogintime: Optional[datetime] = None
    user_lastlogouttime: Optional[datetime] = None
    user_status: Optional[str] = Field(default=None, max_length=50)