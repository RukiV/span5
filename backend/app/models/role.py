from typing import Optional
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .validators import sanitize_text

class RightsBase(SQLModel):
    """Base model for rights data."""
    right_name: str = Field(max_length=100)
    right_description: Optional[str] = None

    @field_validator('right_name', 'right_description', mode='before')
    @classmethod
    def _sanitize_rights(cls, v, info):
        return sanitize_text(v)


class Rights(RightsBase, Base, table=True):
    """Model for rights data."""
    right_id: Optional[int] = Field(default=None, primary_key=True)


class RightsCreate(RightsBase):
    """Input model for creating rights records."""
    pass


class RightsRead(RightsBase):
    """Output model for reading rights records."""
    right_id: int


class RightsUpdate(SQLModel):
    """Input model for updating rights records."""
    right_name: Optional[str] = None
    right_description: Optional[str] = None


class RoleBase(SQLModel):
    """Base model for role data."""
    role_name: str = Field(max_length=100)

    @field_validator('role_name', mode='before')
    @classmethod
    def _sanitize_role(cls, v, info):
        return sanitize_text(v)


class Role(RoleBase, Base, table=True):
    """Model for role data."""
    role_id: Optional[int] = Field(default=None, primary_key=True)


class RoleCreate(RoleBase):
    """Input model for creating role records."""
    pass


class RoleRead(RoleBase):
    """Output model for reading role records."""
    role_id: int


class RoleUpdate(SQLModel):
    """Input model for updating role records."""
    role_name: Optional[str] = None


class RoleRightBase(SQLModel):
    """Base model for role right data."""
    pass


class RoleRight(RoleRightBase, Base, table=True):
    """Association model linking roles to rights."""
    role_id: int = Field(foreign_key="role.role_id", primary_key=True)
    right_id: int = Field(foreign_key="rights.right_id", primary_key=True)


class RoleRightCreate(RoleRightBase):
    """Input model for creating role right records."""
    role_id: int
    right_id: int


class RoleRightRead(RoleRightBase):
    """Output model for reading role right records."""
    role_id: int
    right_id: int


class RoleRightUpdate(SQLModel):
    """Input model for updating role right records."""
    pass
