from typing import Optional, Any
from datetime import datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .enums import AssetStatus
from .validators import sanitize_text, validate_positive_int

class AssettypeBase(SQLModel):
    """Base model for assettype data."""
    assettype_name: str = Field(max_length=100)
    assettype_avg_lifespan: Optional[int] = None
    assettype_min_lifespan: Optional[int] = None
    assettype_max_lifespan: Optional[int] = None
    assettype_service_interval: Optional[int] = None

    @field_validator('assettype_name', mode='before')
    @classmethod
    def _sanitize_name(cls, v, info):
        return sanitize_text(v)

    @field_validator('assettype_avg_lifespan', 'assettype_min_lifespan', 'assettype_max_lifespan', 'assettype_service_interval', mode='before')
    @classmethod
    def _positive_ints(cls, v, info):
        return validate_positive_int(v)


class Assettype(AssettypeBase, Base, table=True):
    """Model for assettype data."""
    assettype_id: Optional[int] = Field(default=None, primary_key=True)


class AssettypeCreate(AssettypeBase):
    """Input model for creating assettype records."""
    pass


class AssettypeRead(AssettypeBase):
    """Output model for reading assettype records."""
    assettype_id: int


class AssettypeUpdate(SQLModel):
    """Input model for updating assettype records."""
    assettype_name: Optional[str] = None
    assettype_avg_lifespan: Optional[int] = None
    assettype_min_lifespan: Optional[int] = None
    assettype_max_lifespan: Optional[int] = None
    assettype_service_interval: Optional[int] = None


class AssetBase(SQLModel):
    """Base model for asset data."""
    asset_name: str = Field(max_length=100)
    asset_brand: str = Field(max_length=100)
    asset_serial: str = Field(default=None, max_length=20)
    asset_status: AssetStatus = Field(default=AssetStatus.ACTIVE)
    asset_isoutdoor: Optional[bool] = None

    @field_validator('asset_name', 'asset_serial', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)


class Asset(AssetBase, Base, table=True):
    """Model for asset data."""
    asset_id: Optional[int] = Field(default=None, primary_key=True)
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    assettype_id: int = Field(foreign_key="assettype.assettype_id")


class AssetCreate(AssetBase):
    """Input model for creating asset records."""
    assettype_id: int
    room_id: Optional[int] = None


class AssetRead(AssetBase):
    """Output model for reading asset records."""
    asset_id: int
    room_id: Optional[int] = None
    assettype_id: int


class AssetUpdate(SQLModel):
    """Input model for updating asset records."""
    asset_name: Optional[str] = None
    asset_brand: Optional[str] = None
    asset_serial: Optional[str] = None
    asset_status: Optional[AssetStatus] = None
    asset_isoutdoor: Optional[bool] = None
    room_id: Optional[int] = None
    assettype_id: Optional[int] = None


class AssetHistoryEventBase(SQLModel):
    """Normalized asset timeline event for room and maintenance history."""
    event_type: str
    event_datetime: datetime
    event_title: str
    event_description: Optional[str] = None
    asset_id: int
    source: str
    event_id: Optional[int] = None
    event_metadata: Optional[dict[str, Any]] = None


class AssetHistoryEventRead(AssetHistoryEventBase):
    pass
