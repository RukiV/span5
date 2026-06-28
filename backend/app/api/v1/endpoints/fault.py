from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.fault import FaultcardRead, FaultcardCreate, FaultcardUpdate
from ....services.fault_service import fault_service

router = APIRouter()

@router.get("", response_model=List[FaultcardRead])
def readFaults(session: Session = Depends(getSession)):
    #Fetch all faults
    return fault_service.getAll(session)

@router.get("/{faultID}", response_model=FaultcardRead)
def readFault(faultID: int, session: Session = Depends(getSession)):
    #Fetch single fault
    fault = fault_service.getByID(session, faultID)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    
    return fault

@router.post("", response_model=FaultcardRead, status_code=status.HTTP_201_CREATED)
def addFault(faultIn: FaultcardCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    """Create a new fault report using a standard JSON body."""
    return fault_service.create(session, faultIn, user_id=user_id)
    
@router.patch("/{faultID}", response_model=FaultcardRead)
def patchFault(faultID: int, faultIn: FaultcardUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Update existing fault
    fault = fault_service.update(session, faultID, faultIn, user_id=user_id)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    
    return fault

@router.delete("/{faultID}", status_code=status.HTTP_204_NO_CONTENT)
def removeFault(faultID: int, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Delete fault
    if not fault_service.delete(session, faultID, user_id=user_id):
        raise HTTPException(status_code=404, detail="Fault not found")
    
    return None
