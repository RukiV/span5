<<<<<<< HEAD
from typing import Optional
from sqlmodel import Session

from ..models.location import Building, BuildingCreate, BuildingUpdate
from .base_service import BaseService
from . import cascade_delete


class BuildingService(BaseService[Building, BuildingCreate, BuildingUpdate]):
    def delete(self, session: Session, id: int, user_id: Optional[int] = None) -> bool:
        obj = session.get(self.model, id)
        if not obj:
            return False

        payload = obj.model_dump(mode="json")
        cascade_delete.cascade_delete_building(session, id)
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


building_service = BuildingService(Building)
=======
from ..models.location import Building, BuildingCreate, BuildingUpdate
from .base_service import BaseService

building_service = BaseService[Building, BuildingCreate, BuildingUpdate](Building)
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
