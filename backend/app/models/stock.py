from typing import Optional
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .validators import sanitize_text, validate_positive_int


class StockBase(SQLModel):
    """Base model for stock data."""
    stock_name: Optional[str] = Field(max_length=100)
    stock_brand: str = Field(max_length=100)
    stock_amount: int = Field(default=0)
    stock_minimum: int = Field(default=0)
    stock_boxTotal: int = Field(default=0)
    stock_type: str = Field(max_length=100)
    stock_desc: Optional[str] = Field(max_length=500)

    @field_validator('stock_name', 'stock_brand', 'stock_type', 'stock_desc', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)

    @field_validator('stock_amount', mode='before')
    @classmethod
    def _positive_amount(cls, v, info):
        return validate_positive_int(v)


class Stock(StockBase, Base, table=True):
    """Model for stock data."""
    stock_id: Optional[int] = Field(default=None, primary_key=True)
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")


class StockCreate(StockBase):
    """Input model for creating stock records."""
    room_id: Optional[int] = None


class StockRead(StockBase):
    """Output model for reading stock records."""
    stock_id: int
    room_id: Optional[int] = None


class StockUpdate(SQLModel):
    """Input model for updating stock records."""
    stock_name: Optional[str] = None
    stock_brand: Optional[str] = None
    stock_amount: Optional[int] = None
    stock_minimum: Optional[int] = None
    stock_boxTotal: Optional[str] = None
    stock_type: Optional[str] = None
    stock_desc: Optional[str] = None
    room_id: Optional[int] = None
