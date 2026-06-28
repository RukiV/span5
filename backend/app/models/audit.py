from typing import Optional, Dict
from datetime import datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field, Column
from sqlalchemy.dialects.postgresql import JSONB
from .base import Base
from .validators import sanitize_text

class AuditlogBase(SQLModel):
    action: str = Field(max_length=100)
    affectedtable: str = Field(max_length=100)
    affectedcolumn: Optional[str] = Field(default=None, max_length=100)
    previous_value: Optional[Dict] = Field(default=None, sa_column=Column(JSONB))
    new_value: Optional[Dict] = Field(default=None, sa_column=Column(JSONB))
    json_data: Optional[Dict] = Field(default=None, sa_column=Column(JSONB))
    actiondatetime: Optional[datetime] = None

    @field_validator('action', 'affectedtable', 'affectedcolumn', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)


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
    previous_value: Optional[Dict] = None
    new_value: Optional[Dict] = None
    json_data: Optional[Dict] = None
    actiondatetime: Optional[datetime] = None
    user_id: Optional[int] = None