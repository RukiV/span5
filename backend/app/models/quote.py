# models/quote.py
from typing import Optional
from datetime import date
from decimal import Decimal
from sqlmodel import SQLModel, Field
from .base import Base

class QuoteBase(SQLModel):
    quote_price: Decimal = Field(decimal_places=2)
    quote_desc: str
    quote_date: date
    quote_status: str = Field(max_length=50)


class Quote(QuoteBase, Base, table=True):
    quote_id: Optional[int] = Field(default=None, primary_key=True)
    contractor_id: Optional[int] = Field(default=None, foreign_key="contractor.contractor_id")


class QuoteCreate(QuoteBase):
    pass


class QuoteRead(QuoteBase):
    quote_id: int
    contractor_id: Optional[int] = None


class QuoteUpdate(SQLModel):
    quote_price: Optional[Decimal] = None
    quote_desc: Optional[str] = None
    quote_date: Optional[date] = None
    quote_status: Optional[str] = None
    contractor_id: Optional[int] = None