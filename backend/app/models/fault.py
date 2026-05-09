from typing import Optional
from datetime import datetime
from sqlmodel import Field
from .base import Base
from .enums import FaultStatus, Priority

class Faultcard(Base, table=True):
    fault_id: Optional[int] = Field(default=None, primary_key=True)

    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    asset_id: Optional[int] = Field(default=None, foreign_key="asset.asset_id")
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    mappoint_id: Optional[int] = Field(default=None, foreign_key="mappoint.mappoint_id")

    fault_description: Optional[str] = None
    fault_type: Optional[str] = Field(default=None, max_length=50)   # Can be changed to Type enum later
    fault_status: FaultStatus = Field(default=FaultStatus.WAIT)
    fault_priority: Priority = Field(default=Priority.MEDIUM)

    fault_reportdatetime: Optional[datetime] = None
    fault_updatedatetime: Optional[datetime] = None