from datetime import datetime
from typing import Optional, Sequence
from sqlmodel import Session, select

from ..models.calendar_event import CalendarEvent, CalendarEventCreate, CalendarEventUpdate
from ..models.job import Jobcard
from .base_service import BaseService

class CalendarService(BaseService[CalendarEvent, CalendarEventCreate, CalendarEventUpdate]):
    def create(self, session: Session, data: CalendarEventCreate, user_id: Optional[int] = None) -> CalendarEvent:
        obj = CalendarEvent.model_validate(data)
        if user_id is not None:
            obj.user_id = user_id
        session.add(obj)
        try:
            session.flush()
            affected_id = self._extract_obj_id(obj)
            self._create_audit_log(
                session, "create",
                {"previous_value": None, "new_value": obj.model_dump(mode="json")},
                affected_columns=None, user_id=user_id,
                affected_id=affected_id, json_data=obj.model_dump(mode="json"),
            )
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise
        return obj

    def get_events_in_range(
        self, session: Session, start: datetime, end: datetime
    ) -> list[dict]:
        calendar_events = session.exec(
            select(CalendarEvent).where(
                CalendarEvent.start_datetime >= start,
                CalendarEvent.start_datetime <= end,
            ).order_by(CalendarEvent.start_datetime.asc())
        ).all()

        job_events = session.exec(
            select(Jobcard).where(
                Jobcard.job_scheduled_datetime.isnot(None),
                Jobcard.job_scheduled_datetime >= start,
                Jobcard.job_scheduled_datetime <= end,
            ).order_by(Jobcard.job_scheduled_datetime.asc())
        ).all()

        result = []

        for event in calendar_events:
            d = event.model_dump(mode="json")
            d["source"] = "calendar_event"
            d["source_id"] = d.pop("event_id")
            result.append(d)

        for job in job_events:
            result.append({
                "source": "jobcard",
                "source_id": job.jobcard_id,
                "title": job.job_desc,
                "description": None,
                "start_datetime": job.job_scheduled_datetime.isoformat() if job.job_scheduled_datetime else None,
                "end_datetime": None,
                "all_day": False,
                "location": None,
                "color": "#935E28",
                "notify_email": False,
                "reminder_minutes": None,
                "reminder_sent": False,
                "outlook_event_id": None,
                "outlook_synced": False,
                "user_id": job.user_id,
                "assigned_to": job.assigned_to,
                "cc_users": job.cc_users,
                "created_at": job.job_createddatetime.isoformat() if job.job_createddatetime else None,
                "updated_at": None,
            })

        result.sort(key=lambda x: x.get("start_datetime") or "")
        return result

calendar_service = CalendarService(CalendarEvent)
