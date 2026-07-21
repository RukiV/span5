from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.contractor import ContractorRead, ContractorCreate, ContractorUpdate
from ....models.user import User
from ....services.contractor_service import contractor_service

router = APIRouter()

@router.get("", response_model=List[ContractorRead])
def readContractors(session: Session = Depends(getSession), _user: User = Depends(require_right("contractors.manage"))):
    #Fetch all contractors
    return contractor_service.getAll(session)

@router.get("/{contractorID}", response_model=ContractorRead)
def readContractor(contractorID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("contractors.manage"))):
    #Fetch single contractor by id
    contractor = contractor_service.getByID(session, contractorID)
    if not contractor:
        raise HTTPException(status_code=404, detail="Contractor not found")

    return contractor

@router.post("", response_model=ContractorRead, status_code=status.HTTP_201_CREATED)
def addContractor(ContractorIn: ContractorCreate, session: Session = Depends(getSession), user: User = Depends(require_right("contractors.manage"))):
    #Create new contractor
    return contractor_service.create(session, ContractorIn, user_id=user.user_id)

@router.patch("/{contractorID}", response_model=ContractorRead)
def patchContractor(contractorID: int, ContractorIn: ContractorUpdate, session: Session = Depends(getSession), user: User = Depends(require_right("contractors.manage"))):
    #Update existing contractor
    contractor = contractor_service.update(session, contractorID, ContractorIn, user_id=user.user_id)
    if not contractor:
        raise HTTPException(status_code=404, detail="Contractor not found")

    return contractor

@router.delete("/{contractorID}", status_code=status.HTTP_204_NO_CONTENT)
def removeContractor(contractorID: int, session: Session = Depends(getSession), user: User = Depends(require_right("contractors.manage"))):
    #Delete contractor
    if not contractor_service.delete(session, contractorID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Contractor not found")

    return None
