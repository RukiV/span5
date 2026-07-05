from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List
from datetime import datetime

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.job import Jobcard, JobcardRead, JobcardCreate, JobcardUpdate
from ....services.job_service import job_service

router = APIRouter()

@router.get("", response_model=List[JobcardRead])
def readJobs(session: Session = Depends(getSession)):
    #Fetch all jobs
    return job_service.getAll(session)

@router.get("/scheduled/upcoming", response_model=List[JobcardRead])
def readScheduledJobs(session: Session = Depends(getSession)):
    #Fetch all scheduled jobs ordered by scheduled date
    jobs = session.exec(
        select(Jobcard)
        .where(Jobcard.job_scheduled_datetime.isnot(None))
        .order_by(Jobcard.job_scheduled_datetime.asc())
    ).all()
    return jobs

@router.get("/{jobID}", response_model=JobcardRead)
def readJob(jobID: int, session: Session = Depends(getSession)):
    #Fetch single job by id
    job = job_service.getByID(session, jobID)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return job

@router.post("", response_model=JobcardRead, status_code=status.HTTP_201_CREATED)
def addJob(jobIn: JobcardCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Create new job
    return job_service.create(session, jobIn, user_id=user_id)

@router.patch("/{jobID}", response_model=JobcardRead)
def patchJob(jobID: int, jobIn: JobcardUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Update existing job
    job = job_service.update(session, jobID, jobIn, user_id=user_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return job

@router.delete("/{jobID}", status_code=status.HTTP_204_NO_CONTENT)
def removeJob(jobID: int, session: Session =Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Delete job
    if not job_service.delete(session, jobID, user_id=user_id):
        raise HTTPException(status_code=404, detail="Job not found")
    
    return None