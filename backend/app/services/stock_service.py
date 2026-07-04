from ..models.stock import Stock, StockCreate, StockUpdate
from .base_service import BaseService

stock_service = BaseService[Stock, StockCreate, StockUpdate](Stock)