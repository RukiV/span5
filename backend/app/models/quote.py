# models/quote.py
from typing import Optional
from datetime import date
from pydantic import field_validator
from sqlmodel import SQLModel, Field, Relationship
from .base import Base
from .validators import sanitize_text

from .image import ImageAsset, ImageAssetRead

class QuoteBase(SQLModel):
    """Base model for quote data."""
    quote_date: date
    quote_status: str = Field(max_length=50)
    contractor_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    contractor_name: Optional[str] = Field(default=None, max_length=100)
    quote_selection_reason: Optional[str] = None

    @field_validator('quote_status', 'quote_selection_reason', 'contractor_name', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)


class Quote(QuoteBase, Base, table=True):
    """Model for quote data."""
    quote_id: Optional[int] = Field(default=None, primary_key=True)
            
    # Universal Foreign Key linking to the separate image module
    image_id: Optional[int] = Field(default=None, foreign_key="image.image_id")
    
    # Unidirectional relationship 
    image: Optional[ImageAsset] = Relationship()


class QuoteCreate(QuoteBase):
    """Input model for creating quote records."""
    image_id: Optional[int] = None
    pass


class QuoteRead(QuoteBase):
    """Output model for reading quote records."""
    quote_id: int
    contractor_id: Optional[int] = None
    image_id: Optional[int] = None
    
    image: Optional[ImageAssetRead] = None


class QuoteUpdate(SQLModel):
    """Input model for updating quote records."""
    quote_date: Optional[date] = None
    quote_status: Optional[str] = None
    quote_selection_reason: Optional[str] = None
    contractor_id: Optional[int] = None
    contractor_name: Optional[str] = None
    image_id: Optional[int] = None

