from typing import Optional
from datetime import datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .enums import FaultStatus, Priority, Type
from .validators import sanitize_text

class FaultcardBase(SQLModel):
    fault_description: str
    fault_type: Optional[Type] = None
    fault_status: FaultStatus = Field(default=FaultStatus.WAIT)
    fault_priority: Priority = Field(default=Priority.MEDIUM)

    # --- MOBILE SUPPORT FIELDS ---
    # fault_image_url: Stores the relative path to the uploaded image file.
    # admin_notes: Stores feedback or internal notes from the management team.
    # REMOVAL NOTICE: These are required by the mobile app's detail views.
    fault_image_url: Optional[str] = None
    admin_notes: Optional[str] = None
    # -----------------------------

    fault_reportdatetime: Optional[datetime] = None
    fault_updatedatetime: Optional[datetime] = None

    @field_validator('fault_description', mode='before')
    @classmethod
    def _sanitize_desc(cls, v, info):
        return sanitize_text(v)


class Faultcard(FaultcardBase, Base, table=True):
    fault_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    asset_id: Optional[int] = Field(default=None, foreign_key="asset.asset_id")
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    mappoint_id: Optional[int] = Field(default=None, foreign_key="mappoint.mappoint_id")


class FaultcardCreate(FaultcardBase):
    asset_id: Optional[int] = None


class FaultcardRead(FaultcardBase):
    fault_id: int
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    mappoint_id: Optional[int] = None


class FaultcardUpdate(SQLModel):
    fault_description: Optional[str] = None
    fault_type: Optional[Type] = None
    fault_status: Optional[FaultStatus] = None
    fault_priority: Optional[Priority] = None
    fault_image_url: Optional[str] = None
    admin_notes: Optional[str] = None
    fault_reportdatetime: Optional[datetime] = None
    fault_updatedatetime: Optional[datetime] = None
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    mappoint_id: Optional[int] = None