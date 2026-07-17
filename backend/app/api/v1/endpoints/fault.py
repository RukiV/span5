from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List

from ....auth.dependencies import get_current_user
from ....db.database import getSession
from ....models.fault import Faultcard, FaultcardRead, FaultcardCreate, FaultcardUpdate
from ....models.user import User
from ....services.fault_service import fault_service

router = APIRouter()

# Role IDs matching backend/app/db/seed.py
ROLE_STUDENT = 1
ROLE_FK = 2
ROLE_ADMIN = 3


@router.get("", response_model=List[FaultcardRead])
def readFaults(session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Fetch faults. Students only see their own; Admin/FK see all."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    if user.role_id == ROLE_STUDENT:
        return session.exec(
            select(Faultcard).where(Faultcard.user_id == user.user_id)
        ).all()
    return fault_service.getAll(session)


@router.get("/{faultID}", response_model=FaultcardRead)
def readFault(faultID: int, session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Fetch single fault. Students can only view their own."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    fault = fault_service.getByID(session, faultID)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    if user.role_id == ROLE_STUDENT and fault.user_id != user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")
    return fault


@router.post("", response_model=FaultcardRead, status_code=status.HTTP_201_CREATED)
def addFault(faultIn: FaultcardCreate, session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Create a new fault report. Requires authentication."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return fault_service.create(session, faultIn, user_id=user.user_id)
    

@router.patch("/{faultID}", response_model=FaultcardRead)
def patchFault(faultID: int, faultIn: FaultcardUpdate, session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Update existing fault. Students can only update their own."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    if user.role_id == ROLE_STUDENT:
        existing = fault_service.getByID(session, faultID)
        if not existing or existing.user_id != user.user_id:
            raise HTTPException(status_code=403, detail="Access denied")
    fault = fault_service.update(session, faultID, faultIn, user_id=user.user_id)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    return fault


@router.delete("/{faultID}", status_code=status.HTTP_204_NO_CONTENT)
def removeFault(faultID: int, session: Session = Depends(getSession), user: User | None = Depends(get_current_user)):
    """Delete fault. Requires admin/FK privileges."""
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    if user.role_id == ROLE_STUDENT:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    if not fault_service.delete(session, faultID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Fault not found")
    return None
