from ..models.location import Room, JobcardCreate, JobcardUpdate
from .base_service import BaseService

room_service = BaseService[Room, JobcardCreate, JobcardUpdate](Room)