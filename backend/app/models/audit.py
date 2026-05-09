from typing import Optional, Dict
from datetime import datetime
from sqlmodel import Field, Column
from sqlalchemy.dialects.postgresql import JSONB
from .base import Base

class Auditlog(Base, table=True):
    auditlog_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")

    action: Optional[str] = Field(default=None, max_length=100)
    affectedtable: Optional[str] = Field(default=None, max_length=100)
    affectedcolumn: Optional[str] = Field(default=None, max_length=100)

    json_data: Optional[Dict] = Field(default=None, sa_column=Column(JSONB))
    actiondatetime: Optional[datetime] = None