from typing import Optional, Dict, Any, List
from datetime import datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field, Column
from sqlalchemy.dialects.postgresql import JSONB
from .base import Base
from .validators import sanitize_text

class AuditlogBase(SQLModel):
    """Base model for auditlog data."""
    action: str = Field(max_length=100)
    affectedtable: str = Field(max_length=100)
    # allow a single column name or multiple column names as JSON
    affectedcolumn: Optional[Any] = Field(default=None, sa_column=Column(JSONB))
    # store the id of the affected item (if applicable)
    affectedid: Optional[int] = None
    previous_value: Optional[Dict] = Field(default=None, sa_column=Column(JSONB))
    new_value: Optional[Dict] = Field(default=None, sa_column=Column(JSONB))
    json_data: Optional[Dict] = Field(default=None, sa_column=Column(JSONB))
    actiondatetime: Optional[datetime] = None

    @field_validator('action', 'affectedtable', 'affectedcolumn', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        # sanitize strings or lists of strings; leave other structures intact
        if isinstance(v, str):
            return sanitize_text(v)
        if isinstance(v, list):
            return [sanitize_text(x) if isinstance(x, str) else x for x in v]
        return v


class Auditlog(AuditlogBase, Base, table=True):
    """Model for auditlog data."""
    auditlog_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")


class AuditlogCreate(AuditlogBase):
    """Input model for creating auditlog records."""
    pass


class AuditlogRead(AuditlogBase):
    """Output model for reading auditlog records."""
    auditlog_id: int
    user_id: Optional[int] = None


class AuditlogUpdate(SQLModel):
    """Input model for updating auditlog records."""
    action: Optional[str] = None
    affectedtable: Optional[str] = None
    affectedcolumn: Optional[str] = None
    previous_value: Optional[Dict] = None
    new_value: Optional[Dict] = None
    json_data: Optional[Dict] = None
    actiondatetime: Optional[datetime] = None
    user_id: Optional[int] = None
