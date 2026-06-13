from typing import Optional
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .validators import sanitize_text

class ReportsBase(SQLModel):
    report_name: str = Field(max_length=100)
    report_desc: str
    report_file: Optional[str] = None

    @field_validator('report_name', 'report_desc', 'report_file', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)


class Reports(ReportsBase, Base, table=True):
    report_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")


class ReportsCreate(ReportsBase):
    pass


class ReportsRead(ReportsBase):
    report_id: int
    user_id: Optional[int] = None


class ReportsUpdate(SQLModel):
    report_name: Optional[str] = None
    report_desc: Optional[str] = None
    report_file: Optional[str] = None
    user_id: Optional[int] = None