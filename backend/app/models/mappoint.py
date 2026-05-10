from typing import Optional
from sqlmodel import SQLModel, Field
from .base import Base


class MappointBase(SQLModel):
    latitude: float
    longitude: float


class Mappoint(MappointBase, Base, table=True):
    mappoint_id: Optional[int] = Field(default=None, primary_key=True)


class MappointCreate(MappointBase):
    pass


class MappointRead(MappointBase):
    mappoint_id: int


class MappointUpdate(SQLModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None
