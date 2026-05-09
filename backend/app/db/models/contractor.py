# models/contractor.py
from typing import Optional
from sqlmodel import Field
from .base import Base

class Contractor(Base, table=True):
    contractor_id: Optional[int] = Field(default=None, primary_key=True)
    contractor_name: Optional[str] = Field(default=None, max_length=100)
    contractor_surname: Optional[str] = Field(default=None, max_length=100)
    contractor_email: Optional[str] = Field(default=None, max_length=150)
    contractor_number: Optional[str] = Field(default=None, max_length=20)
    contractor_type: Optional[str] = Field(default=None, max_length=50)


