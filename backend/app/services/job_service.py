from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Session

from ..models.enums import JobStatus
from ..models.fault import Faultcard
from ..models.job import Jobcard, JobcardCreate, JobcardUpdate
from .base_service import BaseService
from .mappoint_service import mappoint_service
from . import cascade_delete


class JobcardService(BaseService[Jobcard, JobcardCreate, JobcardUpdate]):
    """Werksopdrag-diens met kaartligging-ondersteuning.

    'n Werksopdrag kry sy presiese ligging deur:
      1. 'n eksplisiete mappoint_id op die Create/Update; of
      2. die foutkaartjie (fault_id) se mappoint te erf; of
      3. transiënte latitude/longitude wat 'n nuwe Mappoint skep.
    So sien die kontrakteur altyd waar die fout is.
    """

    def _apply_mappoint(self, session, obj, data):
        """Transiënte lat/lng → Mappoint-koppeling (soos by foutkaartjies)."""
        latitude = getattr(data, "latitude", None)
        longitude = getattr(data, "longitude", None)
        if latitude is not None and longitude is not None:
            mappoint_service.create_or_update(session, obj, latitude, longitude)

    def _inherit_mappoint_from_fault(self, session, obj, data):
        """Erf die foutkaartjie se kaartligging as die werksopdrag uit 'n fout
        geskep word en nie self 'n mappoint het nie."""
        if obj.mappoint_id is not None:
            return
        fault_id = getattr(data, "fault_id", None)
        if fault_id is None:
            return
        fault = session.get(Faultcard, fault_id)
        if fault is not None and fault.mappoint_id is not None:
            obj.mappoint_id = fault.mappoint_id

    def create(self, session, data, user_id=None):
        obj = self.model.model_validate(data)
        if user_id is not None:
            obj.user_id = user_id

        self._inherit_mappoint_from_fault(session, obj, data)
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

    def delete(self, session: Session, id: int, user_id: Optional[int] = None) -> bool:
        obj = session.get(self.model, id)
        if not obj:
            return False

        payload = obj.model_dump(mode="json")
        cascade_delete.cascade_delete_job(session, id)
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


job_service = JobcardService(Jobcard)


def _aware(dt: datetime) -> datetime:
    """Behandel naïewe datums as UTC (konsekwent met die kalender-herinnerings)."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def derive_job_status(job: Jobcard, now: Optional[datetime] = None) -> JobStatus:
    """Bepaal die status van 'n geskeduleerde werksopdrag uit sy skedule.

    - 'n Skedule in die toekoms  → Geskeduleer
    - Skedule begin-tyd het verbygegaan → Besig (bly Besig tot dit voltooi of
      gekanselleer word)
    - Geen skedule of 'n terminale status → onveranderd
    """
    if now is None:
        now = datetime.now(timezone.utc)

    if job.job_scheduled_datetime is None:
        return job.job_status

    if job.job_status in (JobStatus.COMPLETED, JobStatus.CANCELLED):
        return job.job_status

    if _aware(job.job_scheduled_datetime) <= now:
        return JobStatus.IN_PROGRESS

    return JobStatus.SCHEDULED
