from typing import Optional, Dict
from datetime import datetime
from sqlmodel import SQLModel, Field, Column
from sqlalchemy.dialects.postgresql import JSONB
from .base import Base

class AuditlogBase(SQLModel):
    action: str = Field(max_length=100)
    affectedtable: str = Field(max_length=100)
    affectedcolumn: Optional[str] = Field(default=None, max_length=100)
    json_data: Optional[Dict] = Field(default=None, sa_column=Column(JSONB))
    actiondatetime: Optional[datetime] = None


class Auditlog(AuditlogBase, Base, table=True):
    auditlog_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")


class AuditlogCreate(AuditlogBase):
    pass


class AuditlogRead(AuditlogBase):
    auditlog_id: int
    user_id: Optional[int] = None


class AuditlogUpdate(SQLModel):
    action: Optional[str] = None
    affectedtable: Optional[str] = None
    affectedcolumn: Optional[str] = None
    json_data: Optional[Dict] = None
    actiondatetime: Optional[datetime] = None
    user_id: Optional[int] = None