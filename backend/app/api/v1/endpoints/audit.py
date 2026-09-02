from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from typing import List

from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.audit import AuditlogRead, Auditlog
from ....models.user import User
from ....services.audit_service import audit_service

router = APIRouter()

# NOTE: This router is intentionally READ-ONLY.
# Audit rows must only ever be created internally by
# BaseService._create_audit_log as a side effect of real data changes. The old
# POST/PATCH/DELETE /audit routes let any client rewrite audit history via the
# API and have been removed. The duplicate second GET("") handler
# (readAudits, dead code shadowed by readAuditLogs) has also been removed.

@router.get("", response_model=List[AuditlogRead])
def readAuditLogs(session: Session = Depends(getSession), _user: User = Depends(require_right("audit.view"))):
    return session.exec(select(Auditlog).order_by(Auditlog.actiondatetime.desc())).all()

@router.get("/asset/{asset_id}", response_model=List[AuditlogRead])
def getRoomChangesForAsset(asset_id: int, session: Session = Depends(getSession), _user: User = Depends(require_right("audit.view"))):
    #Fetch history of room assignment
    return audit_service.getRoomChangesForAsset(session, asset_id)

@router.get("/{auditID}", response_model=AuditlogRead)
def readAudit(auditID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("audit.view"))):
    #Fetch single audit by id
    audit = audit_service.getByID(session, auditID)
    if not audit:
        raise HTTPException(status_code=404, detail="Audit not found")

    return audit
