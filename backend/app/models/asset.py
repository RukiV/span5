from typing import Optional
from sqlmodel import SQLModel, Field
from .base import Base
from .enums import AssetStatus

class AssettypeBase(SQLModel):
    assettype_name: str = Field(max_length=100)
    assettype_avg_lifespan: Optional[int] = None
    assettype_min_lifespan: Optional[int] = None
    assettype_max_lifespan: Optional[int] = None
    assettype_service_interval: Optional[int] = None


class Assettype(AssettypeBase, Base, table=True):
    assettype_id: Optional[int] = Field(default=None, primary_key=True)


class AssettypeCreate(AssettypeBase):
    pass


class AssettypeRead(AssettypeBase):
    assettype_id: int


class AssettypeUpdate(SQLModel):
    assettype_name: Optional[str] = None
    assettype_avg_lifespan: Optional[int] = None
    assettype_min_lifespan: Optional[int] = None
    assettype_max_lifespan: Optional[int] = None
    assettype_service_interval: Optional[int] = None


class AssetBase(SQLModel):
    asset_name: str = Field(max_length=100)
    asset_status: AssetStatus = Field(default=AssetStatus.ACTIVE)
    asset_isoutdoor: Optional[bool] = None


class Asset(AssetBase, Base, table=True):
    asset_id: Optional[int] = Field(default=None, primary_key=True)
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    assettype_id: int = Field(foreign_key="assettype.assettype_id")


class AssetCreate(AssetBase):
    assettype_id: int
    room_id: Optional[int] = None


class AssetRead(AssetBase):
    asset_id: int
    room_id: Optional[int] = None
    assettype_id: int


class AssetUpdate(SQLModel):
    asset_name: Optional[str] = None
    asset_status: Optional[AssetStatus] = None
    asset_isoutdoor: Optional[bool] = None
    room_id: Optional[int] = None
    assettype_id: Optional[int] = None