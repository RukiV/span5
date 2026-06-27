from ..models.contractor import Contractor, ContractorCreate, ContractorUpdate
from .base_service import BaseService

contractor_service = BaseService[Contractor, ContractorCreate, ContractorUpdate](Contractor)