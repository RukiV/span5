from ..models.quote import Quote, QuoteCreate, QuoteUpdate
from .base_service import BaseService

quote_service = BaseService[Quote, QuoteCreate, QuoteUpdate](Quote)