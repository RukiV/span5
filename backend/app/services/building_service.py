from ..models.location import Building, BuildingCreate, BuildingUpdate
from .base_service import BaseService

building_service = BaseService[Building, BuildingCreate, BuildingUpdate](Building)
