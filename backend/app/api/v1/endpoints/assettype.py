from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.asset import AssettypeRead, AssettypeCreate, AssettypeUpdate
from ....services.assettype_service import assettype_service

router = APIRouter()

@router.get("", response_model=List[AssettypeRead])
def readAssettypes(session: Session = Depends(getSession)):
    return assettype_service.getAll(session)

@router.get("/{assettypeID}", response_model=AssettypeRead)
def readAssettype(assettypeID: int, session: Session = Depends(getSession)):
    assettype = assettype_service.getByID(session, assettypeID)
    if not assettype:
        raise HTTPException(status_code=404, detail="Asset type not found")
    return assettype

@router.post("", response_model=AssettypeRead, status_code=status.HTTP_201_CREATED)
def addAssettype(assettypeIn: AssettypeCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    return assettype_service.create(session, assettypeIn, user_id=user_id)

@router.patch("/{assettypeID}", response_model=AssettypeRead)
def patchAssettype(assettypeID: int, assettypeIn: AssettypeUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    assettype = assettype_service.update(session, assettypeID, assettypeIn, user_id=user_id)
    if not assettype:
        raise HTTPException(status_code=404, detail="Asset type not found")
    return assettype

@router.delete("/{assettypeID}", status_code=status.HTTP_204_NO_CONTENT)
def removeAssettype(assettypeID: int, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    if not assettype_service.delete(session, assettypeID, user_id=user_id):
        raise HTTPException(status_code=404, detail="Asset type not found")
    return None
