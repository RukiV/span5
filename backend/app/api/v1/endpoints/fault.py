from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List

from ....auth.permissions import get_current_user, require_right, user_has_right
from ....db.database import getSession
from ....models.fault import Faultcard, FaultcardRead, FaultcardCreate, FaultcardUpdate
from ....models.user import User
from ....services.fault_service import fault_service

router = APIRouter()

# Authorization is driven entirely by the rights system now (see
# auth/permissions.py), not by raw role_id comparisons:
#   - faults.manage_all : Admin/FK — see/edit/delete every fault card. Supersedes
#                         the own-only rights below.
#   - faults.create_own : Admin/FK/Student — create a fault card.
#   - faults.view_own   : Admin/FK/Student — see only fault cards you created.
# The own-fault-card ownership scoping (fault.user_id == user.user_id) is
# preserved exactly as before; only its trigger condition changed.


@router.get("", response_model=List[FaultcardRead])
def readFaults(session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Fetch faults. faults.manage_all sees all; faults.view_own sees only own."""
    if user_has_right(session, user.role_id, "faults.manage_all"):
        return fault_service.getAll(session)
    if user_has_right(session, user.role_id, "faults.view_own"):
        return session.exec(
            select(Faultcard).where(Faultcard.user_id == user.user_id)
        ).all()
    raise HTTPException(status_code=403, detail="Insufficient permissions")


@router.get("/{faultID}", response_model=FaultcardRead)
def readFault(faultID: int, session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Fetch single fault. Without manage_all, only own fault cards are visible."""
    manage_all = user_has_right(session, user.role_id, "faults.manage_all")
    if not (manage_all or user_has_right(session, user.role_id, "faults.view_own")):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    fault = fault_service.getByID(session, faultID)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    if not manage_all and fault.user_id != user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")
    return fault


@router.post("", response_model=FaultcardRead, status_code=status.HTTP_201_CREATED)
def addFault(faultIn: FaultcardCreate, session: Session = Depends(getSession), user: User = Depends(require_right("faults.create_own"))):
    """Create a new fault report. Requires faults.create_own (Admin/FK/Student)."""
    return fault_service.create(session, faultIn, user_id=user.user_id)


@router.patch("/{faultID}", response_model=FaultcardRead)
def patchFault(faultID: int, faultIn: FaultcardUpdate, session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Update existing fault. Without manage_all, only own fault cards are editable."""
    manage_all = user_has_right(session, user.role_id, "faults.manage_all")
    if not manage_all:
        if not (
            user_has_right(session, user.role_id, "faults.create_own")
            or user_has_right(session, user.role_id, "faults.view_own")
        ):
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        existing = fault_service.getByID(session, faultID)
        if not existing or existing.user_id != user.user_id:
            raise HTTPException(status_code=403, detail="Access denied")
    fault = fault_service.update(session, faultID, faultIn, user_id=user.user_id)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    return fault


@router.delete("/{faultID}", status_code=status.HTTP_204_NO_CONTENT)
def removeFault(faultID: int, session: Session = Depends(getSession), user: User = Depends(require_right("faults.manage_all"))):
    """Delete fault. Requires faults.manage_all (Admin/FK)."""
    if not fault_service.delete(session, faultID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Fault not found")
    return None
