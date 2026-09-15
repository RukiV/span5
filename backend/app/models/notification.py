# =============================================================================
# Notification-stelsel datamodelle
# Vloei:  endpoint → NotificationService → hierdie modelle
# =============================================================================
from typing import Optional
from datetime import datetime, timezone
from pydantic import BaseModel
from sqlmodel import SQLModel, Field, Column, DateTime
from .base import Base

def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)

# --- Basis kolomme vir 'n kennisgewing (word in beide Notification en NotificationRead gebruik) ---
class NotificationBase(SQLModel):
    user_id: int = Field(foreign_key="user.user_id", index=True)        # vir wie is die kennisgewing
    actor_id: Optional[int] = Field(default=None, foreign_key="user.user_id")  # wie het dit veroorsaak
    notification_type: str = Field(max_length=50)                       # bv. fault.created, stock.low
    title: str = Field(max_length=255)
    message: str = Field(max_length=2000)
    reference_type: Optional[str] = Field(default=None, max_length=50)  # fault/job/stock/calendar
    reference_id: Optional[int] = Field(default=None)                   # FK na die relevante item
    is_read: bool = False
    is_seen: bool = False

# --- Hoof tabel: gestoorde kennisgewings (NotificationService.create_notification skryf hierheen) ---
class Notification(NotificationBase, Base, table=True):
    notification_id: Optional[int] = Field(default=None, primary_key=True)
    created_at: datetime = Field(default_factory=_utcnow)

# --- Gebruik vir die skep van 'n kennisgewing (tussenlaag, nie 'n tabel nie) ---
class NotificationCreate(SQLModel):
    user_id: int
    actor_id: Optional[int] = None
    notification_type: str
    title: str
    message: str
    reference_type: Optional[str] = None
    reference_id: Optional[int] = None

# --- Uitvoer-formaat vir API response ---
class NotificationRead(NotificationBase):
    notification_id: int
    created_at: datetime

# --- Gebruiker-voorkeure per kennisgewing-tipe
#     Drie kanale: in-app (DB/FCM stoot), e-pos, FCM-stoot.
#     Stelsel kontroleer in_app_enabled voordat hy 'n Notification skep,
#     en push_enabled voordat hy FCM stuur.  email_enabled is tans ongebruik. ---
class NotificationPreference(SQLModel, table=True):
    __tablename__ = "notification_preferences"
    user_id: int = Field(foreign_key="user.user_id", primary_key=True)
    notification_type: str = Field(max_length=50, primary_key=True)
    in_app_enabled: bool = True     # opt-out: as die gebruiker dit afskakel, word geen Notification geskep nie
    email_enabled: bool = False     # opt-in: nog nie geïmplementeer nie
    push_enabled: bool = True       # opt-out: FCM-stoot word gestuur tensy die gebruiker dit afskakel

# --- Pydantic-schema vir PATCH /notifications/preferences ---
class NotificationPreferenceUpdate(SQLModel):
    in_app_enabled: Optional[bool] = None
    email_enabled: Optional[bool] = None
    push_enabled: Optional[bool] = None

# --- FCM-toestel-tokens vir stootkennisgewings
#     NotificationService._send_fcm_push haal alle tokens vir 'n gebruiker en stuur 'n Firebase-berig na elk ---
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
