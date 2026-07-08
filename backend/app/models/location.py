from typing import Optional
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .enums import BuildingType, RoomType, RoomStatus
from .validators import sanitize_text, validate_positive_int


class BuildingBase(SQLModel):
    """Base model for building data."""
    building_name: str = Field(max_length=100)
    building_type: BuildingType = Field(default=BuildingType.OTHER)

    @field_validator('building_name', mode='before')
    @classmethod
    def _sanitize_building(cls, v, info):
        return sanitize_text(v)


class Building(BuildingBase, Base, table=True):
    """Model for building data."""
    building_id: Optional[int] = Field(default=None, primary_key=True)
    location_id: int = Field(foreign_key="location.location_id")


class BuildingCreate(BuildingBase):
    """Input model for creating building records."""
    location_id: int


class BuildingRead(BuildingBase):
    """Output model for reading building records."""
    building_id: int
    location_id: int


class BuildingUpdate(SQLModel):
    """Input model for updating building records."""
    building_name: Optional[str] = None
    building_type: Optional[BuildingType] = None
    location_id: Optional[int] = None


class LocationBase(SQLModel):
    """Base model for location data."""
    location_name: str = Field(max_length=100)
    location_type: str = Field(max_length=50)
    location_streetnum: str = Field(max_length=20)
    location_streetname: str = Field(max_length=100)
    location_suburb: str = Field(default="", max_length=100)
    location_city: str = Field(default="", max_length=100)
    location_province: str = Field(default="", max_length=100)
    location_country: str = Field(default="", max_length=100)

    @field_validator('location_name', 'location_type', 'location_streetnum', 'location_streetname',
                     'location_suburb', 'location_city', 'location_province', 'location_country', mode='before')
    @classmethod
    def _sanitize_location(cls, v, info):
        return sanitize_text(v)


class Location(LocationBase, Base, table=True):
    """Model for location data."""
    location_id: Optional[int] = Field(default=None, primary_key=True)


class LocationCreate(LocationBase):
    """Input model for creating location records."""
    pass


class LocationRead(LocationBase):
    """Output model for reading location records."""
    location_id: int


class LocationUpdate(SQLModel):
    """Input model for updating location records."""
    location_name: Optional[str] = None
    location_type: Optional[str] = None
    location_streetnum: Optional[str] = None
    location_streetname: Optional[str] = None
    location_suburb: Optional[str] = None
    location_city: Optional[str] = None
    location_province: Optional[str] = None
    location_country: Optional[str] = None


class RoomBase(SQLModel):
    """Base model for room data."""
    room_name: str = Field(max_length=100)
    room_code: str = Field(default=None, max_length=20)
    room_capacity: Optional[int] = None
    room_type: RoomType = Field(default=RoomType.OTHER)
    room_status: RoomStatus = Field(default=RoomStatus.OPERATIONAL)

    @field_validator('room_name', mode='before')
    @classmethod
    def _sanitize_room_name(cls, v, info):
        return sanitize_text(v)

    @field_validator('room_capacity', mode='before')
    @classmethod
    def _room_capacity_positive(cls, v, info):
        return validate_positive_int(v)


class Room(RoomBase, Base, table=True):
    """Model for room data."""
    room_id: Optional[int] = Field(default=None, primary_key=True)
    building_id: int = Field(foreign_key="building.building_id")


class RoomCreate(RoomBase):
    """Input model for creating room records."""
    building_id: int


class RoomRead(RoomBase):
    """Output model for reading room records."""
    room_id: int
    building_id: int


class RoomUpdate(SQLModel):
    """Input model for updating room records."""
    room_name: Optional[str] = None
    room_code: Optional[str] = None
    room_capacity: Optional[int] = None
    room_type: Optional[RoomType] = None
    room_status: Optional[RoomStatus] = None
    building_id: Optional[int] = None