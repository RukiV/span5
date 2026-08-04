from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List
from datetime import datetime

from ....auth.permissions import get_current_user, require_right, user_has_right
from ....db.database import getSession
from ....models.job import Jobcard, JobcardRead, JobcardCreate, JobcardUpdate
from ....models.asset import Asset
from ....models.user import User
from ....services.job_service import job_service
from ....services.notification_service import NotificationService

router = APIRouter()


def _job_summary(session: Session, job: Jobcard, max_desc_len: int = 60) -> str:
    parts = [f"Werksopdrag #{job.jobcard_id}"]
    if job.job_desc:
        desc = job.job_desc.strip()
        if len(desc) > max_desc_len:
            desc = desc[:max_desc_len].rsplit(" ", 1)[0] + "…"
        parts.append(desc)
    if job.asset_id:
        asset = session.get(Asset, job.asset_id)
        if asset:
            parts.append(f"({asset.asset_name})")
    return " — ".join(parts)

# Authorization is driven by the rights system (see auth/permissions.py):
#   - jobs.manage            : Admin/FK — create/delete/edit any job.
#   - jobs.view_own          : Contractor — see only jobs assigned to you.
#   - jobs.update_own_status : Contractor — patch only job_status /
#                              job_finisheddatetime on your own jobs.
# The contractor ownership scoping and the PATCH field-allowlist are preserved
# exactly; only their trigger conditions changed from role_id to rights.


@router.get("", response_model=List[JobcardRead])
def readJobs(session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Fetch jobcards. jobs.manage sees all; jobs.view_own sees only assigned."""
    if user_has_right(session, user.role_id, "jobs.manage"):
        return job_service.getAll(session)
    if user_has_right(session, user.role_id, "jobs.view_own"):
        return session.exec(
            select(Jobcard).where(Jobcard.contractor_id == user.user_id)
        ).all()
    raise HTTPException(status_code=403, detail="Insufficient permissions")


@router.get("/scheduled/upcoming", response_model=List[JobcardRead])
def readScheduledJobs(session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Fetch scheduled jobcards. jobs.view_own is scoped to assigned jobs."""
    manage = user_has_right(session, user.role_id, "jobs.manage")
    view_own = user_has_right(session, user.role_id, "jobs.view_own")
    if not (manage or view_own):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    query = (
        select(Jobcard)
        .where(Jobcard.job_scheduled_datetime.isnot(None))
        .order_by(Jobcard.job_scheduled_datetime.asc())
    )
    if not manage:
        query = query.where(Jobcard.contractor_id == user.user_id)
    return session.exec(query).all()


@router.get("/{jobID}", response_model=JobcardRead)
def readJob(jobID: int, session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Fetch single jobcard. Without jobs.manage, only assigned jobs are visible."""
    manage = user_has_right(session, user.role_id, "jobs.manage")
    if not (manage or user_has_right(session, user.role_id, "jobs.view_own")):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    job = job_service.getByID(session, jobID)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if not manage and job.contractor_id != user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")
    return job


@router.post("", response_model=JobcardRead, status_code=status.HTTP_201_CREATED)
def addJob(jobIn: JobcardCreate, session: Session = Depends(getSession), user: User = Depends(require_right("jobs.manage"))):
    """Create new jobcard. Requires jobs.manage (Admin/FK)."""
    job = job_service.create(session, jobIn, user_id=user.user_id)
    notif_svc = NotificationService(session)
    summary = _job_summary(session, job)
    notif_svc.notify_admins(
        notification_type="job.created",
        title="Nuwe werksopdrag",
        message=f"{summary} geskep deur {user.user_name}",
        actor_id=user.user_id,
        reference_type="job",
        reference_id=job.jobcard_id,
    )
    if job.location_id:
        notif_svc.notify_location_users(
            location_id=job.location_id,
            notification_type="job.created",
            title="Nuwe werksopdrag",
            message=f"{summary} by jou terrein",
            actor_id=user.user_id,
            reference_type="job",
            reference_id=job.jobcard_id,
        )
    return job


@router.patch("/{jobID}", response_model=JobcardRead)
def patchJob(jobID: int, jobIn: JobcardUpdate, session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Update jobcard. jobs.manage updates anything; jobs.update_own_status updates
    only status fields on own jobs."""
    manage = user_has_right(session, user.role_id, "jobs.manage")
    can_update_status = user_has_right(session, user.role_id, "jobs.update_own_status")
    if not (manage or can_update_status):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    job = job_service.getByID(session, jobID)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if not manage:
        # Contractor path: own jobs only, and only the allowlisted status fields.
        if job.contractor_id != user.user_id:
            raise HTTPException(status_code=403, detail="Access denied")
        allowed_fields = {"job_status", "job_finisheddatetime"}
        update_data = jobIn.model_dump(exclude_unset=True)
        disallowed = set(update_data.keys()) - allowed_fields
        if disallowed:
            raise HTTPException(status_code=403, detail="Contractors can only update job status")
    old_status = job.job_status if job else None
    result = job_service.update(session, jobID, jobIn, user_id=user.user_id)
    result = job_service.getByID(session, jobID)

    if (
        jobIn.job_status is not None
        and old_status != result.job_status
    ):
        notif_svc = NotificationService(session)
        summary = _job_summary(session, result)
        if result.contractor_id:
            notif_svc.create_notification(
                user_id=result.contractor_id,
                notification_type="job.status_changed",
                title="Werksopdrag status verander",
                message=f"{summary} status verander na {result.job_status.value}",
                actor_id=user.user_id,
                reference_type="job",
                reference_id=result.jobcard_id,
            )
        # Stuur ook aan Admin / FK sodat hulle weet die status het verander
        notif_svc.notify_admins(
            notification_type="job.status_changed",
            title="Werksopdrag status verander",
            message=f"{summary} status verander na {result.job_status.value}",
            actor_id=user.user_id,
            reference_type="job",
            reference_id=result.jobcard_id,
        )
        if result.location_id:
            notif_svc.notify_location_users(
                location_id=result.location_id,
                notification_type="job.status_changed",
                title="Werksopdrag status verander",
                message=f"{summary} status verander na {result.job_status.value}",
                actor_id=user.user_id,
                reference_type="job",
                reference_id=result.jobcard_id,
            )

    return result


@router.delete("/{jobID}", status_code=status.HTTP_204_NO_CONTENT)
def removeJob(jobID: int, session: Session = Depends(getSession), user: User = Depends(require_right("jobs.manage"))):
    """Delete jobcard. Requires jobs.manage (Admin/FK)."""
    if not job_service.delete(session, jobID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Job not found")
    return None
