<<<<<<< HEAD
from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Session

from ..models.fault import Faultcard, FaultcardCreate, FaultcardUpdate
from .base_service import BaseService
from .prediction_service import prediction_service
from .mappoint_service import mappoint_service
from . import cascade_delete


class FaultService(BaseService[Faultcard, FaultcardCreate, FaultcardUpdate]):
    def _apply_mappoint(self, session, obj, data):
        """Koppel 'n kaartligging (lat/lng) aan die foutkaartjie as beide gegee is.

        Die lat/lng-velde is transiënt — hulle word nie as kolomme gestoor nie,
        maar 'n Mappoint word geskep/opgedateer en mappoint_id word gekoppel.
        """
        latitude = getattr(data, "latitude", None)
        longitude = getattr(data, "longitude", None)
        if latitude is not None and longitude is not None:
            mappoint_service.create_or_update(session, obj, latitude, longitude)

    def create(self, session, data, user_id=None):
        obj = self.model.model_validate(data)
        obj.fault_reportdatetime = datetime.now(timezone.utc)
        if user_id is not None:
            obj.user_id = user_id

        self._apply_mappoint(session, obj, data)

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

        # Invalidate predictions cache since new fault affects predictions
        prediction_service.invalidateCache()
        
        return obj

    def update(self, session, id, data, user_id=None):
        obj = session.get(self.model, id)
        if not obj:
            return None

        update_data = data.model_dump(exclude_unset=True)
        # Transiënte velde word nie as kolomme gestoor nie — slegs die
        # Mappoint-koppeling word daaruit afgelei.
        update_data.pop("latitude", None)
        update_data.pop("longitude", None)
        for key, value in update_data.items():
            setattr(obj, key, value)

        self._apply_mappoint(session, obj, data)

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

        # Invalidate predictions cache since fault update affects predictions
        prediction_service.invalidateCache()
        
        return obj

    def delete(self, session: Session, id: int, user_id: Optional[int] = None) -> bool:
        obj = session.get(self.model, id)
        if not obj:
            return False

        payload = obj.model_dump(mode="json")
        cascade_delete.cascade_delete_fault(session, id)
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
        prediction_service.invalidateCache()
        return True


fault_service = FaultService(Faultcard)
=======
from ..models.fault import Faultcard, FaultcardCreate, FaultcardUpdate
from .base_service import BaseService

fault_service = BaseService[Faultcard, FaultcardCreate, FaultcardUpdate](Faultcard)
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
