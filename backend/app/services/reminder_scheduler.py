import asyncio
import logging
import os
from datetime import datetime, timedelta, timezone
from sqlmodel import Session, select

from ..db.database import engine, purge_expired_revoked_tokens
from ..models.calendar_event import CalendarEvent
from ..models.enums import JobStatus
from ..models.job import Jobcard
from ..models.user import User
from .email_service import send_reminder
from .notification_service import NotificationService

logger = logging.getLogger(__name__)

CHECK_INTERVAL = int(os.getenv("REMINDER_CHECK_INTERVAL", "60"))

async def reminder_loop():
    while True:
        try:
            _check_and_send_reminders()
        except Exception as e:
            logger.error(f"Reminder loop fout: {e}")
        try:
            _check_and_start_scheduled_jobs()
        except Exception as e:
            logger.error(f"Geskeduleerde werksopdrag-loop fout: {e}")
        try:
            purge_expired_revoked_tokens()
        except Exception as e:
            logger.error(f"Token purge fout: {e}")
        await asyncio.sleep(CHECK_INTERVAL)

def _check_and_send_reminders():
    now = datetime.now(timezone.utc)
    with Session(engine) as session:
        events = session.exec(
            select(CalendarEvent).where(
                CalendarEvent.notify_email == True,
                CalendarEvent.reminder_sent == False,
                CalendarEvent.reminder_minutes.isnot(None),
            )
        ).all()

        for event in events:
            if event.reminder_minutes is None:
                continue
            start = event.start_datetime
            if start.tzinfo is None:
                start = start.replace(tzinfo=timezone.utc)
            reminder_time = start - timedelta(minutes=event.reminder_minutes)
            if reminder_time <= now < start:
                user = session.get(User, event.user_id)
                if user and user.user_email:
                    start_str = start.strftime("%Y-%m-%d %H:%M")
                    success = send_reminder(
                        to_email=user.user_email,
                        event_title=event.title,
                        start_datetime_str=start_str,
                        location=event.location or "",
                        description=event.description or "",
                    )
                    if success:
                        event.reminder_sent = True
                        session.add(event)
                        session.commit()
                        logger.info(f"Herinnering gestuur vir event {event.event_id}")
                    notif_svc = NotificationService(session)
                    notif_svc.create_notification(
                        user_id=event.user_id,
                        notification_type="calendar.reminder",
                        title="Kalender herinnering",
                        message=f"{event.title} begin om {start_str}",
                        reference_type="calendar",
                        reference_id=event.event_id,
                    )


def _check_and_start_scheduled_jobs(db_engine=None):
    """Geskeduleerde werksopdragte begin outomaties sodra hul begintyd verby is
    (status verander van 'Geskeduleer' na 'Besig')."""
    if db_engine is None:
        db_engine = engine
    now = datetime.now(timezone.utc)
    flipped = []
    with Session(db_engine) as session:
        jobs = session.exec(
            select(Jobcard).where(
                Jobcard.job_status == JobStatus.SCHEDULED,
                Jobcard.job_scheduled_datetime.isnot(None),
            )
        ).all()
        for job in jobs:
            start = job.job_scheduled_datetime
            if start.tzinfo is None:
                start = start.replace(tzinfo=timezone.utc)
            if start <= now:
                job.job_status = JobStatus.IN_PROGRESS
                session.add(job)
                flipped.append(job)
        if not flipped:
            return
        session.commit()
        logger.info(f"{len(flipped)} geskeduleerde werksopdrag(te) na 'Besig' geskuif.")

        notif_svc = NotificationService(session)
        for job in flipped:
            summary = f"Werksopdrag #{job.jobcard_id}"
            if job.job_desc:
                summary += f" — {job.job_desc.strip()[:60]}"
            title = "Werksopdrag begin"
            message = f"{summary} het begin (status: Besig)"
            if job.contractor_id:
                notif_svc.create_notification(
                    user_id=job.contractor_id,
                    notification_type="job.status_changed",
                    title=title,
                    message=message,
                    reference_type="job",
                    reference_id=job.jobcard_id,
                )
            notif_svc.notify_admins(
                notification_type="job.status_changed",
                title=title,
                message=message,
                reference_type="job",
                reference_id=job.jobcard_id,
            )
