from datetime import datetime, timezone
from typing import Optional

from ..models.enums import JobStatus
from ..models.job import Jobcard, JobcardCreate, JobcardUpdate
from .base_service import BaseService

job_service = BaseService[Jobcard, JobcardCreate, JobcardUpdate](Jobcard)


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
