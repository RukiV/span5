from typing import Optional
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .enums import RoomType
from .validators import sanitize_text, validate_positive_int

class ZipcodeBase(SQLModel):
    zipcode_suburb: str = Field(max_length=100)
    zipcode_city: str = Field(max_length=100)
    zipcode_province: str = Field(max_length=100)
    zipcode_country: str = Field(max_length=100)

    @field_validator('zipcode_suburb', 'zipcode_city', 'zipcode_province', 'zipcode_country', mode='before')
    @classmethod
    def _sanitize_zip(cls, v, info):
        return sanitize_text(v)


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

    @field_validator('location_name', 'location_type', 'location_streetnum', 'location_streetname', mode='before')
    @classmethod
    def _sanitize_location(cls, v, info):
        return sanitize_text(v)


class Location(LocationBase, Base, table=True):
    location_id: Optional[int] = Field(default=None, primary_key=True)
    zipcode_id: int = Field(foreign_key="zipcode.zipcode_id")


class LocationCreate(LocationBase):
    zipcode_id: int


class LocationRead(LocationBase):
    location_id: int
    zipcode_id: int


class LocationUpdate(SQLModel):
    location_name: Optional[str] = None
    location_type: Optional[str] = None
    location_streetnum: Optional[str] = None
    location_streetname: Optional[str] = None
    zipcode_id: Optional[int] = None


class RoomBase(SQLModel):
    room_name: str = Field(max_length=100)
    room_capacity: Optional[int] = None
    room_type: RoomType = Field(default=RoomType.OTHER)

    @field_validator('room_name', mode='before')
    @classmethod
    def _sanitize_room_name(cls, v, info):
        return sanitize_text(v)

    @field_validator('room_capacity', mode='before')
    @classmethod
    def _room_capacity_positive(cls, v, info):
        return validate_positive_int(v)


class Room(RoomBase, Base, table=True):
    room_id: Optional[int] = Field(default=None, primary_key=True)
    location_id: int = Field(foreign_key="location.location_id")


class RoomCreate(RoomBase):
    location_id: int


class RoomRead(RoomBase):
    room_id: int
    location_id: int


class RoomUpdate(SQLModel):
    room_name: Optional[str] = None
    room_capacity: Optional[int] = None
    room_type: Optional[RoomType] = None
    location_id: Optional[int] = None