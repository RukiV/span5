# models/quote.py
from typing import Optional
from datetime import date
from decimal import Decimal
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .validators import sanitize_text

class QuoteBase(SQLModel):
    """Base model for quote data."""
    quote_price: Decimal = Field(decimal_places=2)
    quote_desc: str
    quote_date: date
    quote_status: str = Field(max_length=50)
    contractor_id: Optional[int] = Field(default=None, foreign_key="contractor.contractor_id")
    quote_selection_reason: Optional[str] = None

    @field_validator('quote_desc', 'quote_status', 'quote_selection_reason', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)


class Quote(QuoteBase, Base, table=True):
    """Model for quote data."""
    quote_id: Optional[int] = Field(default=None, primary_key=True)


class QuoteCreate(QuoteBase):
    """Input model for creating quote records."""
    pass


class QuoteRead(QuoteBase):
    """Output model for reading quote records."""
    quote_id: int
    contractor_id: Optional[int] = None


class QuoteUpdate(SQLModel):
    """Input model for updating quote records."""
    quote_price: Optional[Decimal] = None
    quote_desc: Optional[str] = None
    quote_date: Optional[date] = None
    quote_status: Optional[str] = None
    quote_selection_reason: Optional[str] = None
    contractor_id: Optional[int] = None

