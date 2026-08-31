from typing import Optional
from datetime import datetime, timezone
from sqlmodel import SQLModel, Field, Column, DateTime, Text
from .base import Base

def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)

class RoomCheckSessionBase(SQLModel):
    room_id: int = Field(foreign_key="room.room_id", index=True)
    assigned_user_id: int = Field(foreign_key="user.user_id", index=True)
    scheduled_datetime: Optional[datetime] = None
    status: str = Field(default="scheduled", max_length=20)
    calendar_event_id: Optional[int] = Field(default=None, index=True)
    room_check_id: Optional[int] = Field(default=None, foreign_key="room_check.room_check_id")
    notes: Optional[str] = Field(default=None, sa_column=Column(Text))

class RoomCheckSession(RoomCheckSessionBase, Base, table=True):
    __tablename__ = "room_check_session"
    session_id: Optional[int] = Field(default=None, primary_key=True)
    created_by: Optional[int] = Field(default=None, foreign_key="user.user_id")
    created_at: datetime = Field(default_factory=_utcnow)

class RoomCheckSessionCreate(SQLModel):
    room_id: int
    assigned_user_id: int
    scheduled_datetime: Optional[datetime] = None
    status: str = "scheduled"
    notes: Optional[str] = None

class RoomCheckSessionUpdate(SQLModel):
    room_id: Optional[int] = None
    assigned_user_id: Optional[int] = None
    scheduled_datetime: Optional[datetime] = None
    status: Optional[str] = None
    notes: Optional[str] = None

class RoomCheckSessionRead(RoomCheckSessionBase):
    session_id: int
    created_by: Optional[int] = None
    created_at: datetime
    room_name: Optional[str] = None
    assigned_user_name: Optional[str] = None
