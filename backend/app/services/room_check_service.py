from datetime import datetime
from ..models.room_check import RoomCheck, RoomCheckCreate, RoomCheckUpdate
from .base_service import BaseService

class RoomCheckService(BaseService[RoomCheck, RoomCheckCreate, RoomCheckUpdate]):
    def create(self, session, data, user_id=None):
        if data.checked_datetime is None:
            data.checked_datetime = datetime.utcnow()
        return super().create(session, data, user_id=user_id)

room_check_service = RoomCheckService(RoomCheck)
