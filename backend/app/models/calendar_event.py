from typing import Optional
from datetime import datetime, timezone
from sqlmodel import SQLModel, Field, Column, DateTime
from .base import Base

def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)

class CalendarEventBase(SQLModel):
    title: str = Field(max_length=200)
    description: Optional[str] = Field(default=None, max_length=2000)
    start_datetime: datetime
    end_datetime: Optional[datetime] = None
    all_day: bool = False
    location: Optional[str] = Field(default=None, max_length=300)
    color: Optional[str] = Field(default=None, max_length=7)
    notify_email: bool = False
    reminder_minutes: Optional[int] = Field(default=None)
    reminder_sent: bool = False
    outlook_event_id: Optional[str] = Field(default=None, max_length=300)
    outlook_synced: bool = False

class CalendarEvent(CalendarEventBase, Base, table=True):
    event_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: Optional[datetime] = Field(default=None, sa_column=Column(DateTime, onupdate=_utcnow))

class CalendarEventCreate(CalendarEventBase):
    pass

class CalendarEventRead(CalendarEventBase):
    event_id: int
    user_id: Optional[int] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

class CalendarEventUpdate(SQLModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_datetime: Optional[datetime] = None
    end_datetime: Optional[datetime] = None
    all_day: Optional[bool] = None
    location: Optional[str] = None
    color: Optional[str] = None
    user_id: Optional[int] = None
    notify_email: Optional[bool] = None
    reminder_minutes: Optional[int] = None
    outlook_event_id: Optional[str] = None
    outlook_synced: Optional[bool] = None
