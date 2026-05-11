from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....db.database import getSession
from ....models.job import JobcardRead, JobcardCreate, JobcardUpdate
from ....services.job_service import job_service

router = APIRouter()

@router.get("/", response_model=List[JobcardRead])
def readJobs(session: Session = Depends(getSession)):
    #Fetch all jobs
    return job_service.getAll(Session)

@router.get("/{jobID}", response_model=JobcardRead)
def readJob(jobID: int, session: Session = Depends(getSession)):
    #Fetch single job by id
    job = job_service.getByID(session, jobID)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return job

@router.post("/", response_model=JobcardRead, status_code=status.HTTP_201_CREATED)
def addJob(jobIn: JobcardCreate, session: Session = Depends(getSession)):
    #Create new job
    return job_service.create(session, jobIn)

@router.patch("/{jobID}", response_model=JobcardRead)
def patchJob(jobID: int, jobIn: JobcardUpdate, session: Session = Depends(getSession)):
    #Update existing job
    job = job_service.update(session, jobID, jobIn)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return job

@router.delete("/{jobID}", status_code=status.HTTP_204_NO_CONTENT)
def removeJob(jobID: int, session: Session =Depends(getSession)):
    #Delete job
    if not job_service.delete(session, jobID):
        raise HTTPException(status_code=404, detail="Job not found")
    
    return None