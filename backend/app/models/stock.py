from typing import Optional
from sqlmodel import SQLModel, Field
from .base import Base


class StockBase(SQLModel):
    stock_name: Optional[str] = Field(max_length=100)
    stock_brand: str = Field(max_length=100)
    stock_amount: int = Field(default=0)
    stock_type: str = Field(max_length=100)
    stock_desc: Optional[str] = Field(max_length=500)


class Stock(StockBase, Base, table=True):
    stock_id: Optional[int] = Field(default=None, primary_key=True)
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")


class StockCreate(StockBase):
    room_id: Optional[int] = None


class StockRead(StockBase):
    stock_id: int
    room_id: Optional[int] = None


class StockUpdate(SQLModel):
    stock_name: Optional[str] = None
    stock_brand: Optional[str] = None
    stock_amount: Optional[int] = None
    stock_type: Optional[str] = None
    stock_desc: Optional[str] = None
    room_id: Optional[int] = None