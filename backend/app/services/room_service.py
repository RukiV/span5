from ..models.location import Room, RoomCreate, RoomUpdate
from .base_service import BaseService

room_service = BaseService[Room, RoomCreate, RoomUpdate](Room)