from datetime import datetime, timezone

from ..models.fault import Faultcard, FaultcardCreate, FaultcardUpdate
from .base_service import BaseService


class FaultService(BaseService[Faultcard, FaultcardCreate, FaultcardUpdate]):
    def create(self, session, data, user_id=None):
        obj = self.model.model_validate(data)
        obj.fault_reportdatetime = datetime.now(timezone.utc)

        session.add(obj)
        try:
            session.flush()
            affected_id = self._extract_obj_id(obj)
            self._create_audit_log(
                session,
                "create",
                {
                    "previous_value": None,
                    "new_value": obj.model_dump(mode="json"),
                },
                affected_columns=None,
                user_id=user_id,
                affected_id=affected_id,
                json_data=obj.model_dump(mode="json"),
            )
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise

        return obj

    def update(self, session, id, data, user_id=None):
        obj = session.get(self.model, id)
        if not obj:
            return None

        update_data = data.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(obj, key, value)
        obj.fault_updatedatetime = datetime.now(timezone.utc)

        session.add(obj)
        try:
            session.flush()
            affected_id = self._extract_obj_id(obj)
            self._create_audit_log(
                session,
                "update",
                {
                    "previous_value": None,
                    "new_value": obj.model_dump(mode="json"),
                },
                affected_columns=list(update_data.keys()),
                user_id=user_id,
                affected_id=affected_id,
                json_data=obj.model_dump(mode="json"),
            )
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise

        return obj


fault_service = FaultService(Faultcard)
