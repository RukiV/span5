from typing import List

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from ....db.database import getSession
from ....models.audit import Auditlog, AuditlogRead

router = APIRouter()


@router.get("", response_model=List[AuditlogRead])
def readAuditLogs(session: Session = Depends(getSession)):
    return session.exec(select(Auditlog).order_by(Auditlog.actiondatetime.desc())).all()
