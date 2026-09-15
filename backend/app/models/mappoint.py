from typing import Optional
from sqlmodel import SQLModel, Field
from .base import Base


class MappointBase(SQLModel):
    """Base model for mappoint data."""
    latitude: float
    longitude: float


class Mappoint(MappointBase, Base, table=True):
    """Model for mappoint data."""
    mappoint_id: Optional[int] = Field(default=None, primary_key=True)


class MappointCreate(MappointBase):
    """Input model for creating mappoint records."""
    pass


class MappointRead(MappointBase):
    """Output model for reading mappoint records."""
    mappoint_id: int


class MappointUpdate(SQLModel):
    """Input model for updating mappoint records."""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
