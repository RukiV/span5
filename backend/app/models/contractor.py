# models/contractor.py
from typing import Optional
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .validators import sanitize_text, validate_email, validate_phone

class ContractorBase(SQLModel):
    """Base model for contractor data."""
    contractor_name: str = Field(max_length=100)
    contractor_surname: str = Field(max_length=100)
    contractor_email: str = Field(max_length=150)
    contractor_number: Optional[str] = Field(default=None, max_length=20)
    contractor_type: Optional[str] = Field(default=None, max_length=50)

    @field_validator('contractor_name', 'contractor_surname', 'contractor_number', 'contractor_type', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)

    @field_validator('contractor_email', mode='before')
    @classmethod
    def _validate_email(cls, v, info):
        v = sanitize_text(v)
        return validate_email(v)


class Contractor(ContractorBase, Base, table=True):
    """Model for contractor data."""
    contractor_id: Optional[int] = Field(default=None, primary_key=True)


class ContractorCreate(ContractorBase):
    """Input model for creating contractor records."""
    pass


class ContractorRead(ContractorBase):
    """Output model for reading contractor records."""
    contractor_id: int


class ContractorUpdate(SQLModel):
    """Input model for updating contractor records."""
    contractor_name: Optional[str] = None
    contractor_surname: Optional[str] = None
    contractor_email: Optional[str] = None
    contractor_number: Optional[str] = None
    contractor_type: Optional[str] = None

