from ..models.fault import Faultcard, FaultcardCreate, FaultcardUpdate
from .base_service import BaseService

fault_service = BaseService[Faultcard, FaultcardCreate, FaultcardUpdate](Faultcard)