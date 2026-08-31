<<<<<<< HEAD
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from typing import List

from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.audit import AuditlogRead, Auditlog
from ....models.user import User
=======
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.audit import AuditlogRead, AuditlogCreate, AuditlogUpdate, Auditlog
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
from ....services.audit_service import audit_service

router = APIRouter()

<<<<<<< HEAD
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
=======
@router.get("", response_model=List[AuditlogRead])
def readAuditLogs(session: Session = Depends(getSession)):
    return session.exec(select(Auditlog).order_by(Auditlog.actiondatetime.desc())).all()

@router.get("", response_model=List[AuditlogRead])
def readAudits(session: Session = Depends(getSession)):
    #Fetch all audits
    return audit_service.getAll(session)

@router.get("/asset/{asset_id}", response_model=List[AuditlogRead])
def getRoomChangesForAsset(asset_id: int, session: Session = Depends(getSession)):
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
    #Fetch history of room assignment
    return audit_service.getRoomChangesForAsset(session, asset_id)

@router.get("/{auditID}", response_model=AuditlogRead)
<<<<<<< HEAD
def readAudit(auditID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("audit.view"))):
=======
def readAudit(auditID: int, session: Session = Depends(getSession)):
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
    #Fetch single audit by id
    audit = audit_service.getByID(session, auditID)
    if not audit:
        raise HTTPException(status_code=404, detail="Audit not found")
<<<<<<< HEAD

    return audit
=======
    
    return audit

@router.post("", response_model=AuditlogRead, status_code=status.HTTP_201_CREATED)
def addAudit(auditIn: AuditlogCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Create new audit
    return audit_service.create(session, auditIn, user_id=user_id)

@router.patch("/{auditID}", response_model=AuditlogRead)
def patchAudit(auditID: int, auditIn: AuditlogUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Update existing audit
    audit = audit_service.update(session, auditID, auditIn, user_id=user_id)
    if not audit:
        raise HTTPException(status_code=404, detail="Audit not found")
    
    return audit

@router.delete("/{auditID}", status_code=status.HTTP_204_NO_CONTENT)
def removeAudit(auditID: int, session: Session =Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Delete audit
    if not audit_service.delete(session, auditID, user_id=user_id):
        raise HTTPException(status_code=404, detail="Audit not found")
    
    return None
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
