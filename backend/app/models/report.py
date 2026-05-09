from typing import Optional
from sqlmodel import Field
from .base import Base

class Reports(Base, table=True):
    report_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")

    report_name: Optional[str] = Field(default=None, max_length=100)
    report_desc: Optional[str] = None
    report_file: Optional[str] = None