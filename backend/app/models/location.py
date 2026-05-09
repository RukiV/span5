from typing import Optional
from decimal import Decimal
from sqlmodel import Field
from .base import Base
from .enums import RoomType

class Zipcode(Base, table=True):
    zipcode_id: Optional[int] = Field(default=None, primary_key=True)
    zipcode_suburb: Optional[str] = Field(default=None, max_length=100)
    zipcode_city: Optional[str] = Field(default=None, max_length=100)
    zipcode_province: Optional[str] = Field(default=None, max_length=100)
    zipcode_country: Optional[str] = Field(default=None, max_length=100)


class Terrain(Base, table=True):
    terrain_id: Optional[int] = Field(default=None, primary_key=True)
    zipcode_id: Optional[int] = Field(default=None, foreign_key="zipcode.zipcode_id")

    terrain_name: Optional[str] = Field(default=None, max_length=100)
    terrain_type: Optional[str] = Field(default=None, max_length=50)
    terrain_streetnum: Optional[str] = Field(default=None, max_length=20)
    terrain_streetname: Optional[str] = Field(default=None, max_length=100)


class Room(Base, table=True):
    room_id: Optional[int] = Field(default=None, primary_key=True)
    terrain_id: Optional[int] = Field(default=None, foreign_key="terrain.terrain_id")

    room_name: Optional[str] = Field(default=None, max_length=100)
    room_capacity: Optional[int] = None
    room_type: RoomType = Field(default=RoomType.OTHER)