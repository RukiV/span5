from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List, Optional
from datetime import datetime

from ....auth.permissions import get_current_user, require_right, user_has_right
from ....db.database import getSession
from ....models.enums import FaultStatus, JobStatus
from ....models.fault import Faultcard, FaultcardUpdate
from ....models.job import Jobcard, JobcardRead, JobcardCreate, JobcardUpdate
from ....models.asset import Asset
from ....models.user import User
from ....services.fault_service import fault_service
from ....services.job_service import derive_job_status, job_service
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


def _user_display_name(session: Session, user_id: Optional[int]) -> Optional[str]:
    if user_id is None:
        return None
    user = session.get(User, user_id)
    if not user:
        return None
    return f"{user.user_name} {user.user_surname}".strip()


def _read_with_names(session: Session, job: Jobcard) -> JobcardRead:
    """Serialize a jobcard with the assigned staff member's and contractor's names.

    Names are resolved server-side so that contractors (who have no access to
    /users/assignable) still see real names instead of raw user ids.
    """
    read = JobcardRead.model_validate(job)
    read.assigned_name = _user_display_name(session, job.assigned_to)
    read.contractor_name = _user_display_name(session, job.contractor_id)
    return read

# Authorization is driven by the rights system (see auth/permissions.py):
#   - jobs.manage            : Admin/FK — create/delete/edit any job.
#   - jobs.view_own          : Contractor — see only jobs assigned to you.
#   - jobs.update_own_status : Contractor — patch only job_status /
#                              job_finisheddatetime / job_notes on your own jobs.
# The contractor ownership scoping and the PATCH field-allowlist are preserved
# exactly; only their trigger conditions changed from role_id to rights.


@router.get("", response_model=List[JobcardRead])
def readJobs(session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Fetch jobcards. jobs.manage sees all; jobs.view_own sees only assigned."""
    if user_has_right(session, user.role_id, "jobs.manage"):
        return [_read_with_names(session, job) for job in job_service.getAll(session)]
    if user_has_right(session, user.role_id, "jobs.view_own"):
        return [
            _read_with_names(session, job)
            for job in session.exec(
                select(Jobcard).where(Jobcard.contractor_id == user.user_id)
            ).all()
        ]
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
    return [_read_with_names(session, job) for job in session.exec(query).all()]


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
    return _read_with_names(session, job)


@router.post("", response_model=JobcardRead, status_code=status.HTTP_201_CREATED)
def addJob(jobIn: JobcardCreate, session: Session = Depends(getSession), user: User = Depends(require_right("jobs.manage"))):
    """Create new jobcard. Requires jobs.manage (Admin/FK)."""
    job = job_service.create(session, jobIn, user_id=user.user_id)
    derived = derive_job_status(job)
    if derived != job.job_status:
        job = job_service.update(
            session, job.jobcard_id, JobcardUpdate(job_status=derived),
            user_id=user.user_id,
        )
        job = job_service.getByID(session, job.jobcard_id)
    notif_svc = NotificationService(session)
    summary = _job_summary(session, job)
    # Direk geadresseerde ontvangers kry presies EEN kennisgewing. Die admin/FK-
    # en terrein-uitsaaie slaan hulle oor, sodat bv. 'n FK wat beide die
    # foutkaartjie-skepper én die verantwoordelike persoon is nie dubbel kry nie.
    directly_notified: set[int] = set()
    if job.contractor_id:
        directly_notified.add(job.contractor_id)
        notif_svc.create_notification(
            user_id=job.contractor_id,
            notification_type="job.created",
            title="Nuwe werksopdrag",
            message=f"{summary} aan jou toegewys",
            actor_id=user.user_id,
            reference_type="job",
            reference_id=job.jobcard_id,
        )
    if job.fault_id:
        faultcard = session.get(Faultcard, job.fault_id)
        if faultcard and faultcard.user_id and faultcard.user_id != user.user_id:
            creator_id = faultcard.user_id
            cc_ids = [uid.strip() for uid in (job.cc_users or "").split(",") if uid.strip()]
            if str(creator_id) not in cc_ids:
                cc_ids.append(str(creator_id))
                job = job_service.update(
                    session, job.jobcard_id,
                    JobcardUpdate(cc_users=",".join(cc_ids)),
                    user_id=user.user_id,
                )
                job = job_service.getByID(session, job.jobcard_id)
            directly_notified.add(creator_id)
            notif_svc.create_notification(
                user_id=creator_id,
                notification_type="job.created",
                title="Nuwe werksopdrag",
                message=f"{summary} geskep vir jou foutkaartjie #{faultcard.fault_id}",
                actor_id=user.user_id,
                reference_type="job",
                reference_id=job.jobcard_id,
            )
    notif_svc.notify_admins(
        notification_type="job.created",
        title="Nuwe werksopdrag",
        message=f"{summary} geskep deur {user.user_name}",
        actor_id=user.user_id,
        reference_type="job",
        reference_id=job.jobcard_id,
        exclude_user_ids=directly_notified,
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
            exclude_user_ids=directly_notified,
        )
    return _read_with_names(session, job)


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
        allowed_fields = {"job_status", "job_finisheddatetime", "job_notes"}
        update_data = jobIn.model_dump(exclude_unset=True)
        disallowed = set(update_data.keys()) - allowed_fields
        if disallowed:
            raise HTTPException(status_code=403, detail="Contractors can only update job status, finish time and werknotas")
    old_status = job.job_status if job else None
    result = job_service.update(session, jobID, jobIn, user_id=user.user_id)
    result = job_service.getByID(session, jobID)

    # Geskeduleer/Besig word afgelei uit die skedule: as 'n skedule gestel is en
    # die status nie terminaal is nie, kry die werksopdrag die afgeleide status
    # (toekoms → Geskeduleer, begintyd verbygegaan → Besig).
    derived = derive_job_status(result)
    if derived != result.job_status:
        result = job_service.update(
            session, result.jobcard_id, JobcardUpdate(job_status=derived),
            user_id=user.user_id,
        )
        result = job_service.getByID(session, result.jobcard_id)

    if old_status != result.job_status:
        notif_svc = NotificationService(session)
        summary = _job_summary(session, result)
        # Direk geadresseerde ontvangers (kontrakteur + CC-gebruikers) kry presies
        # EEN kennisgewing. Die admin/FK- en terrein-uitsaaie slaan hulle oor,
        # sodat bv. 'n FK wat CC is én by die terrein is nie dubbel kry nie.
        directly_notified: set[int] = set()
        if result.contractor_id:
            directly_notified.add(result.contractor_id)
            notif_svc.create_notification(
                user_id=result.contractor_id,
                notification_type="job.status_changed",
                title="Werksopdrag status verander",
                message=f"{summary} status verander na {result.job_status.value}",
                actor_id=user.user_id,
                reference_type="job",
                reference_id=result.jobcard_id,
            )
        for raw_id in (result.cc_users or "").split(","):
            cc_id = raw_id.strip()
            if not cc_id.isdigit() or int(cc_id) in directly_notified:
                continue
            directly_notified.add(int(cc_id))
            notif_svc.create_notification(
                user_id=int(cc_id),
                notification_type="job.status_changed",
                title="Werksopdrag status verander",
                message=f"{summary} status verander na {result.job_status.value}",
                actor_id=user.user_id,
                reference_type="job",
                reference_id=result.jobcard_id,
            )
        notified = set(directly_notified)
        # Stuur ook aan Admin / FK sodat hulle weet die status het verander
        notified |= notif_svc.notify_admins(
            notification_type="job.status_changed",
            title="Werksopdrag status verander",
            message=f"{summary} status verander na {result.job_status.value}",
            actor_id=user.user_id,
            reference_type="job",
            reference_id=result.jobcard_id,
            exclude_user_ids=notified,
        )
        if result.location_id:
            notified |= notif_svc.notify_location_users(
                location_id=result.location_id,
                notification_type="job.status_changed",
                title="Werksopdrag status verander",
                message=f"{summary} status verander na {result.job_status.value}",
                actor_id=user.user_id,
                reference_type="job",
                reference_id=result.jobcard_id,
                exclude_user_ids=notified,
            )
    else:
        notified: set[int] = set()

    # Wanneer 'n werksopdrag voltooi word, los die gekoppelde foutkaartjie op
    # sodat die student kan sien sy foutverslag is opgelos.
    if (
        result.job_status == JobStatus.COMPLETED
        and old_status != result.job_status
        and result.fault_id
    ):
        fault = session.get(Faultcard, result.fault_id)
        if fault and fault.fault_status not in (FaultStatus.RESOLVED, FaultStatus.CLOSED):
            from ....api.v1.endpoints.fault import notify_fault_status_change
            fault = fault_service.update(
                session, fault.fault_id,
                FaultcardUpdate(fault_status=FaultStatus.RESOLVED),
                user_id=user.user_id,
            )
            if fault:
                notify_fault_status_change(
                    session, fault, FaultStatus.IN_PROGRESS, user,
                    exclude_user_ids=notified,
                )

    return _read_with_names(session, result)


@router.delete("/{jobID}", status_code=status.HTTP_204_NO_CONTENT)
def removeJob(jobID: int, session: Session = Depends(getSession), user: User = Depends(require_right("jobs.manage"))):
    """Delete jobcard. Requires jobs.manage (Admin/FK)."""
    if not job_service.delete(session, jobID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Job not found")
    return None


@router.post("/{jobID}/complete-request")
def requestJobCompletion(
    jobID: int,
    session: Session = Depends(getSession),
    user: User = Depends(get_current_user),
):
    """Contractor asks the responsible staff member (assigned_to) to complete the
    jobcard. The status is NOT changed here — the staff member completes it."""
    if not user_has_right(session, user.role_id, "jobs.update_own_status"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    job = job_service.getByID(session, jobID)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if job.contractor_id != user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    notif_svc = NotificationService(session)
    summary = _job_summary(session, job)
    title = "Werksopdrag voltooiing versoek"
    message = f"{summary} — voltooiing versoek deur {user.user_name}"
    if job.assigned_to:
        notif_svc.create_notification(
            user_id=job.assigned_to,
            notification_type="job.completion_requested",
            title=title,
            message=message,
            actor_id=user.user_id,
            reference_type="job",
            reference_id=job.jobcard_id,
        )
    else:
        notif_svc.notify_admins(
            notification_type="job.completion_requested",
            title=title,
            message=message,
            actor_id=user.user_id,
            reference_type="job",
            reference_id=job.jobcard_id,
        )
    return {"status": "requested", "jobcard_id": job.jobcard_id}
