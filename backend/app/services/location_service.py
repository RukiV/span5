from ..models.location import Location, JobcardCreate, JobcardUpdate
from .base_service import BaseService

location_service = BaseService[Location, JobcardCreate, JobcardUpdate](Location)