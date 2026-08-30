from typing import Optional
from sqlmodel import Session

from ..models.location import Location, LocationCreate, LocationUpdate
from .base_service import BaseService
from . import cascade_delete


class LocationService(BaseService[Location, LocationCreate, LocationUpdate]):
    def delete(self, session: Session, id: int, user_id: Optional[int] = None) -> bool:
        obj = session.get(self.model, id)
        if not obj:
            return False

        payload = obj.model_dump(mode="json")
        cascade_delete.cascade_delete_location(session, id)
        try:
            self._create_audit_log(
                session,
                "delete",
                {"previous_value": payload, "new_value": None},
                affected_columns=None,
                user_id=user_id,
                affected_id=id,
                json_data=payload,
            )
            session.commit()
        except Exception:
            session.rollback()
            raise
        return True


location_service = LocationService(Location)
