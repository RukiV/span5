from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List
from datetime import datetime

from ....auth.dependencies import get_current_user
from ....db.database import getSession
from ....models.job import Jobcard, JobcardRead, JobcardCreate, JobcardUpdate
from ....models.user import User
from ....services.job_service import job_service

router = APIRouter()

# Role IDs matching backend/app/db/seed.py
ROLE_STUDENT = 1
ROLE_FK = 2
ROLE_ADMIN = 3
ROLE_CONTRACTOR = 4


@router.get("", response_model=List[JobcardRead])
def readJobs(session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Fetch jobcards. Contractors only see assigned jobs; Admin/FK see all."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    if user.role_id == ROLE_CONTRACTOR:
        return session.exec(
            select(Jobcard).where(Jobcard.contractor_id == user.user_id)
        ).all()
    return job_service.getAll(session)


@router.get("/scheduled/upcoming", response_model=List[JobcardRead])
def readScheduledJobs(session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Fetch scheduled jobcards. Contractors only see assigned jobs."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    query = (
        select(Jobcard)
        .where(Jobcard.job_scheduled_datetime.isnot(None))
        .order_by(Jobcard.job_scheduled_datetime.asc())
    )
    if user.role_id == ROLE_CONTRACTOR:
        query = query.where(Jobcard.contractor_id == user.user_id)
    return session.exec(query).all()


@router.get("/{jobID}", response_model=JobcardRead)
def readJob(jobID: int, session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Fetch single jobcard. Contractors can only view assigned jobs."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    job = job_service.getByID(session, jobID)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if user.role_id == ROLE_CONTRACTOR and job.contractor_id != user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")
    return job


@router.post("", response_model=JobcardRead, status_code=status.HTTP_201_CREATED)
def addJob(jobIn: JobcardCreate, session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Create new jobcard. Requires Admin or FK role."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    if user.role_id not in (ROLE_ADMIN, ROLE_FK):
        raise HTTPException(status_code=403, detail="Only Admin or FK can create jobcards")
    return job_service.create(session, jobIn, user_id=user.user_id)


@router.patch("/{jobID}", response_model=JobcardRead)
def patchJob(jobID: int, jobIn: JobcardUpdate, session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Update jobcard. Admin/FK can update all. Contractors can only update status on their assigned jobs."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    job = job_service.getByID(session, jobID)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if user.role_id == ROLE_CONTRACTOR:
        if job.contractor_id != user.user_id:
            raise HTTPException(status_code=403, detail="Access denied")
        allowed_fields = {"job_status", "job_finisheddatetime"}
        update_data = jobIn.model_dump(exclude_unset=True)
        disallowed = set(update_data.keys()) - allowed_fields
        if disallowed:
            raise HTTPException(status_code=403, detail="Contractors can only update job status")
    result = job_service.update(session, jobID, jobIn, user_id=user.user_id)
    return result


@router.delete("/{jobID}", status_code=status.HTTP_204_NO_CONTENT)
def removeJob(jobID: int, session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Delete jobcard. Requires Admin or FK role."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    if user.role_id not in (ROLE_ADMIN, ROLE_FK):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    if not job_service.delete(session, jobID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Job not found")
    return None