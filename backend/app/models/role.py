from typing import Optional
from sqlmodel import SQLModel, Field
from .base import Base

class RightsBase(SQLModel):
    right_name: str = Field(max_length=100)
    right_description: Optional[str] = None


class Rights(RightsBase, Base, table=True):
    right_id: Optional[int] = Field(default=None, primary_key=True)


class RightsCreate(RightsBase):
    pass


class RightsRead(RightsBase):
    right_id: int


class RightsUpdate(SQLModel):
    right_name: Optional[str] = None
    right_description: Optional[str] = None


class RoleBase(SQLModel):
    role_name: str = Field(max_length=100)


class Role(RoleBase, Base, table=True):
    role_id: Optional[int] = Field(default=None, primary_key=True)


class RoleCreate(RoleBase):
    pass


class RoleRead(RoleBase):
    role_id: int


class RoleUpdate(SQLModel):
    role_name: Optional[str] = None


class RoleRightBase(SQLModel):
    pass


class RoleRight(RoleRightBase, Base, table=True):
    role_id: int = Field(foreign_key="role.role_id", primary_key=True)
    right_id: int = Field(foreign_key="rights.right_id", primary_key=True)


class RoleRightCreate(RoleRightBase):
    role_id: int
    right_id: int


class RoleRightRead(RoleRightBase):
    role_id: int
    right_id: int


class RoleRightUpdate(SQLModel):
    pass