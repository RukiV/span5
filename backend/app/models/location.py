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


class LocationBase(SQLModel):
    location_name: str = Field(max_length=100)
    location_type: str = Field(max_length=50)
    location_streetnum: str = Field(max_length=20)
    location_streetname: str = Field(max_length=100)


class Location(LocationBase, Base, table=True):
    location_id: Optional[int] = Field(default=None, primary_key=True)
    zipcode_id: int = Field(foreign_key="zipcode.zipcode_id")


class JobcardCreate(LocationBase):
    zipcode_id: int


class JobcardRead(LocationBase):
    location_id: int
    zipcode_id: int


class JobcardUpdate(SQLModel):
    location_name: Optional[str] = None
    location_type: Optional[str] = None
    location_streetnum: Optional[str] = None
    location_streetname: Optional[str] = None
    zipcode_id: Optional[int] = None


class RoomBase(SQLModel):
    room_name: str = Field(max_length=100)
    room_capacity: Optional[int] = None
    room_type: RoomType = Field(default=RoomType.OTHER)


class Room(RoomBase, Base, table=True):
    room_id: Optional[int] = Field(default=None, primary_key=True)
    location_id: int = Field(foreign_key="location.location_id")


class JobcardCreate(RoomBase):
    location_id: int


class JobcardRead(RoomBase):
    room_id: int
    location_id: int


class JobcardUpdate(SQLModel):
    room_name: Optional[str] = None
    room_capacity: Optional[int] = None
    room_type: Optional[RoomType] = None
    location_id: Optional[int] = None