from ..models.room_check_session import RoomCheckSession, RoomCheckSessionCreate, RoomCheckSessionUpdate
from .base_service import BaseService

class RoomCheckSessionService(BaseService[RoomCheckSession, RoomCheckSessionCreate, RoomCheckSessionUpdate]):
    pass

room_check_session_service = RoomCheckSessionService(RoomCheckSession)
