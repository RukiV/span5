from typing import Optional
from sqlmodel import Field
from .base import Base
from .enums import AssetStatus

class Assettype(Base, table=True):
    assettype_id: Optional[int] = Field(default=None, primary_key=True)
    assettype_name: Optional[str] = Field(default=None, max_length=100)
    assettype_avg_lifespan: Optional[int] = None
    assettype_min_lifespan: Optional[int] = None
    assettype_max_lifespan: Optional[int] = None
    assettype_service_interval: Optional[int] = None


class Asset(Base, table=True):
    asset_id: Optional[int] = Field(default=None, primary_key=True)
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    assettype_id: Optional[int] = Field(default=None, foreign_key="assettype.assettype_id")

    asset_name: Optional[str] = Field(default=None, max_length=100)
    asset_status: AssetStatus = Field(default=AssetStatus.ACTIVE)
    asset_isoutdoor: Optional[bool] = None