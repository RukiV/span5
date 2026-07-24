from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.report import ReportsRead, ReportsCreate, ReportsUpdate
from ....services.report_service import report_service

router = APIRouter()

@router.get("", response_model=List[ReportsRead])
def readReports(session: Session = Depends(getSession)):
    #Fetch all reports
    return report_service.getAll(session)

@router.get("/{reportID}", response_model=ReportsRead)
def readReport(reportID: int, session: Session = Depends(getSession)):
    #Fetch single report by id
    report = report_service.getByID(session, reportID)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    
    return report

@router.post("", response_model=ReportsRead, status_code=status.HTTP_201_CREATED)
def addReport(reportIn: ReportsCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Create new report
    return report_service.create(session, reportIn, user_id=user_id)

@router.patch("/{reportID}", response_model=ReportsRead)
def patchReport(reportID: int, reportIn: ReportsUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Update existing report
    report = report_service.update(session, reportID, reportIn, user_id=user_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    
    return report

@router.delete("/{reportID}", status_code=status.HTTP_204_NO_CONTENT)
def removeReport(reportID: int, session: Session =Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Delete report
    if not report_service.delete(session, reportID, user_id=user_id):
        raise HTTPException(status_code=404, detail="Report not found")
    
    return None