from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.asset import AssetRead, AssetCreate, AssetUpdate
from ....services.assets_service import assets_service

router = APIRouter()

@router.get("", response_model=List[AssetRead])
def readAssets(session: Session = Depends(getSession)):
    #Fetch all assets
    return assets_service.getAll(session)

@router.get("/status-summary")
def readAssetStatusSummary(session: Session = Depends(getSession)):
    return assets_service.getStatusSummary(session)

@router.get("/{assetID}", response_model=AssetRead)
def readAsset(assetID: int, session: Session = Depends(getSession)):
    #Fetch single asset by id
    asset = assets_service.getByID(session, assetID)
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    
    return asset

@router.get("/serial/{serial}", response_model=AssetRead)
def readAssetBySerial(serial: str, session: Session = Depends(getSession)):
    #Fetch asset by serial code
    asset = assets_service.getBySerial(session, serial)
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    
    return asset

@router.post("", response_model=AssetRead, status_code=status.HTTP_201_CREATED)
def addAsset(assetIn: AssetCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Create new asset
    return assets_service.create(session, assetIn, user_id=user_id)
    
@router.patch("/{assetID}", response_model=AssetRead)
def patchAsset(assetID: int, assetIn: AssetUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Update existing asset
    asset = assets_service.update(session, assetID, assetIn, user_id=user_id)
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    
    return asset

@router.delete("/{assetID}", status_code=status.HTTP_204_NO_CONTENT)
def removeAsset(assetID: int, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Delete asset
    if not assets_service.delete(session, assetID, user_id=user_id):
        raise HTTPException(status_code=404, detail="Asset not found")
    
    return None