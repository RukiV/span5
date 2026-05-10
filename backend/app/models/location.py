from typing import Optional
from sqlmodel import SQLModel, Field
from .base import Base
from .enums import RoomType

class ZipcodeBase(SQLModel):
    zipcode_suburb: str = Field(max_length=100)
    zipcode_city: str = Field(max_length=100)
    zipcode_province: str = Field(max_length=100)
    zipcode_country: str = Field(max_length=100)


class Zipcode(ZipcodeBase, Base, table=True):
    zipcode_id: Optional[int] = Field(default=None, primary_key=True)


class ZipcodeCreate(ZipcodeBase):
    pass


class ZipcodeRead(ZipcodeBase):
    zipcode_id: int


class ZipcodeUpdate(SQLModel):
    zipcode_suburb: Optional[str] = None
    zipcode_city: Optional[str] = None
    zipcode_province: Optional[str] = None
    zipcode_country: Optional[str] = None


class TerrainBase(SQLModel):
    terrain_name: str = Field(max_length=100)
    terrain_type: str = Field(max_length=50)
    terrain_streetnum: str = Field(max_length=20)
    terrain_streetname: str = Field(max_length=100)


class Terrain(TerrainBase, Base, table=True):
    terrain_id: Optional[int] = Field(default=None, primary_key=True)
    zipcode_id: int = Field(foreign_key="zipcode.zipcode_id")


class TerrainCreate(TerrainBase):
    zipcode_id: int


class TerrainRead(TerrainBase):
    terrain_id: int
    zipcode_id: int


class TerrainUpdate(SQLModel):
    terrain_name: Optional[str] = None
    terrain_type: Optional[str] = None
    terrain_streetnum: Optional[str] = None
    terrain_streetname: Optional[str] = None
    zipcode_id: Optional[int] = None


class RoomBase(SQLModel):
    room_name: str = Field(max_length=100)
    room_capacity: Optional[int] = None
    room_type: RoomType = Field(default=RoomType.OTHER)


class Room(RoomBase, Base, table=True):
    room_id: Optional[int] = Field(default=None, primary_key=True)
    terrain_id: int = Field(foreign_key="terrain.terrain_id")


class RoomCreate(RoomBase):
    terrain_id: int


class RoomRead(RoomBase):
    room_id: int
    terrain_id: int


class RoomUpdate(SQLModel):
    room_name: Optional[str] = None
    room_capacity: Optional[int] = None
    room_type: Optional[RoomType] = None
    terrain_id: Optional[int] = None