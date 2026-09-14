from datetime import datetime, timedelta
from typing import Optional, Sequence
from sqlalchemy import or_
from sqlmodel import Session, select

from ..auth.permissions import user_has_right
from ..auth.rights_catalog import ROLE_CONTRACTOR
from ..models.calendar_event import CalendarEvent, CalendarEventCreate, CalendarEventUpdate
from ..models.job import Jobcard
from ..models.user import User
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
        self, session: Session, start: datetime, end: datetime, user: Optional[User] = None
    ) -> list[dict]:
        is_contractor = user is not None and user.role_id == ROLE_CONTRACTOR

        # Managers (who assign/schedule room checks or manage the calendar) see all
        # events. Any other viewer (Dosent / contractor) may only see events assigned
        # to them, so their calendar reflects exactly what was allocated to them.
        is_manager = user is not None and (
            user_has_right(session, user.role_id, "room_checks.manage")
            or user_has_right(session, user.role_id, "calendar.manage")
        )

        calendar_events: Sequence[CalendarEvent] = []
        calendar_query = select(CalendarEvent).where(
            CalendarEvent.start_datetime >= start,
            CalendarEvent.start_datetime <= end,
        )
        if not is_manager and user is not None:
            calendar_query = calendar_query.where(CalendarEvent.user_id == user.user_id)
        calendar_events = session.exec(
            calendar_query.order_by(CalendarEvent.start_datetime.asc())
        ).all()

        job_query = select(Jobcard).where(
            Jobcard.job_scheduled_datetime.isnot(None),
            Jobcard.job_scheduled_datetime <= end,
            or_(
                Jobcard.job_scheduled_end_datetime.is_(None),
                Jobcard.job_scheduled_end_datetime >= start,
            ),
        )
        if is_contractor:
            job_query = job_query.where(Jobcard.contractor_id == user.user_id)

        job_events = session.exec(
            job_query.order_by(Jobcard.job_scheduled_datetime.asc())
        ).all()

        result = []

        for event in calendar_events:
            d = event.model_dump(mode="json")
            d["source"] = "calendar_event"
            d["source_id"] = d.pop("event_id")
            result.append(d)

        for job in job_events:
            start_dt = job.job_scheduled_datetime
            end_dt = job.job_scheduled_end_datetime or (start_dt + timedelta(hours=1) if start_dt else None)
            result.append({
                "source": "jobcard",
                "source_id": job.jobcard_id,
                "title": job.job_desc,
                "description": None,
                "start_datetime": start_dt.isoformat() if start_dt else None,
                "end_datetime": end_dt.isoformat() if end_dt else None,
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
                "job_priority": job.job_priority,
                "nature": job.nature,
                "created_at": job.job_createddatetime.isoformat() if job.job_createddatetime else None,
                "updated_at": None,
            })

        result.sort(key=lambda x: x.get("start_datetime") or "")
        return result

calendar_service = CalendarService(CalendarEvent)
