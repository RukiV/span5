from typing import Optional
from sqlmodel import Field
from .base import Base

class Rights(Base, table=True):
    right_id: Optional[int] = Field(default=None, primary_key=True)
    right_name: Optional[str] = Field(default=None, max_length=100)
    right_description: Optional[str] = None


class Role(Base, table=True):
    role_id: Optional[int] = Field(default=None, primary_key=True)
    role_name: Optional[str] = Field(default=None, max_length=100)


class RoleRight(Base, table=True):
    role_id: Optional[int] = Field(
        default=None, foreign_key="role.role_id", primary_key=True
    )
    right_id: Optional[int] = Field(
        default=None, foreign_key="rights.right_id", primary_key=True
    )