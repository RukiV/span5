from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....db.database import getSession
from ....models.fault import FaultcardRead, FaultcardCreate, FaultcardUpdate
from ....services.fault_service import fault_service

router = APIRouter()

@router.get("/", response_model=List[FaultcardRead])
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

@router.post("/", response_model=FaultcardRead, status_code=status.HTTP_201_CREATED)
def addFault(faultIn: FaultcardCreate, session: Session = Depends(getSession)):
    #Create new fault
    return fault_service.create(session, faultIn)
    
@router.patch("/{faultD}", response_model=FaultcardRead)
def patchFault(faultID: int, faultIn: FaultcardUpdate, session: Session = Depends(getSession)):
    #Update existing fault
    fault = fault_service.update(session, faultID, faultIn)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    
    return fault

@router.delete("/{faultID}", status_code=status.HTTP_204_NO_CONTENT)
def removeFault(faultID: int, session: Session = Depends(getSession)):
    #Delete fault
    if not fault_service.delete(session, faultID):
        raise HTTPException(status_code=404, detail="Fault not found")
    
    return None