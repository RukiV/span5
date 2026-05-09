# models/quote.py
from typing import Optional
from datetime import date
from decimal import Decimal
from sqlmodel import Field
from .base import Base

class Quote(Base, table=True):
    quote_id: Optional[int] = Field(default=None, primary_key=True)
    contractor_id: Optional[int] = Field(default=None, foreign_key="contractor.contractor_id")

    quote_price: Optional[Decimal] = Field(default=None, decimal_places=2)
    quote_desc: Optional[str] = None
    quote_date: Optional[date] = None
    quote_status: Optional[str] = Field(default=None, max_length=50)