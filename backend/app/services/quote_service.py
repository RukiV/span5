from ..models.quote import Quote, QuoteCreate, QuoteUpdate
from .base_service import BaseService

fault_service = BaseService[Quote, QuoteCreate, QuoteUpdate](Quote)