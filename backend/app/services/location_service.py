from ..models.location import Location, LocationCreate, LocationUpdate
from .base_service import BaseService

location_service = BaseService[Location, LocationCreate, LocationUpdate](Location)