from typing import Optional
from datetime import datetime, timezone
from pydantic import BaseModel
from sqlmodel import SQLModel, Field, Column, DateTime
from .base import Base

def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)

class NotificationBase(SQLModel):
    user_id: int = Field(foreign_key="user.user_id", index=True)
    actor_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    notification_type: str = Field(max_length=50)
    title: str = Field(max_length=255)
    message: str = Field(max_length=2000)
    reference_type: Optional[str] = Field(default=None, max_length=50)
    reference_id: Optional[int] = Field(default=None)
    is_read: bool = False
    is_seen: bool = False

class Notification(NotificationBase, Base, table=True):
    notification_id: Optional[int] = Field(default=None, primary_key=True)
    created_at: datetime = Field(default_factory=_utcnow)

class NotificationCreate(SQLModel):
    user_id: int
    actor_id: Optional[int] = None
    notification_type: str
    title: str
    message: str
    reference_type: Optional[str] = None
    reference_id: Optional[int] = None

class NotificationRead(NotificationBase):
    notification_id: int
    created_at: datetime

class NotificationPreference(SQLModel, table=True):
    __tablename__ = "notification_preferences"
    user_id: int = Field(foreign_key="user.user_id", primary_key=True)
    notification_type: str = Field(max_length=50, primary_key=True)
    in_app_enabled: bool = True
    email_enabled: bool = False
    push_enabled: bool = False

class NotificationPreferenceUpdate(SQLModel):
    in_app_enabled: Optional[bool] = None
    email_enabled: Optional[bool] = None
    push_enabled: Optional[bool] = None

class DeviceToken(SQLModel, table=True):
    __tablename__ = "device_tokens"
    token_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.user_id", index=True)
    fcm_token: str
    platform: str = Field(max_length=10)
    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow, sa_column=Column(DateTime, onupdate=_utcnow))

class DeviceTokenRegister(BaseModel):
    fcm_token: str
    platform: str = "android"

class DeviceTokenUnregister(BaseModel):
    fcm_token: str
