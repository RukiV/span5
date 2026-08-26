from typing import Optional, Any
from datetime import datetime
from sqlmodel import SQLModel, Field, Column, Text
from .base import Base

class RoomCheckBase(SQLModel):
    room_id: int = Field(foreign_key="room.room_id")
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    summary: str = Field(sa_column=Column(Text))
    checked_datetime: Optional[datetime] = None

class RoomCheck(RoomCheckBase, Base, table=True):
    __tablename__ = "room_check"
    room_check_id: Optional[int] = Field(default=None, primary_key=True)

class RoomCheckCreate(SQLModel):
    room_id: int
    summary: str
    checked_datetime: Optional[datetime] = None

class RoomCheckRead(RoomCheckBase):
    room_check_id: int
    user_name: Optional[str] = None
    check_status: Optional[str] = None

class RoomCheckUpdate(SQLModel):
    pass
