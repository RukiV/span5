from ..models.quote import Quote, QuoteCreate, QuoteUpdate
from .base_service import BaseService

# Service instance for Quote operations
quote_service = BaseService[Quote, QuoteCreate, QuoteUpdate](Quote)