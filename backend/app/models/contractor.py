# models/contractor.py
from typing import Optional
from sqlmodel import SQLModel, Field
from .base import Base

class ContractorBase(SQLModel):
    contractor_name: str = Field(max_length=100)
    contractor_surname: str = Field(max_length=100)
    contractor_email: str = Field(max_length=150)
    contractor_number: Optional[str] = Field(default=None, max_length=20)
    contractor_type: Optional[str] = Field(default=None, max_length=50)


class Contractor(ContractorBase, Base, table=True):
    contractor_id: Optional[int] = Field(default=None, primary_key=True)


class ContractorCreate(ContractorBase):
    pass


class ContractorRead(ContractorBase):
    contractor_id: int


class ContractorUpdate(SQLModel):
    contractor_name: Optional[str] = None
    contractor_surname: Optional[str] = None
    contractor_email: Optional[str] = None
    contractor_number: Optional[str] = None
    contractor_type: Optional[str] = None

