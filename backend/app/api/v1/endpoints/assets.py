from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....db.database import getSession
from ....models.asset import AssetRead, AssetCreate, AssetUpdate
from ....services.assets_service import assets_service

router = APIRouter()

@router.get("/", response_model=List[AssetRead])
def readAssets(session: Session = Depends(getSession)):
    #Fetch all assets
    return assets_service.getAll(session)

@router.get("/{assetID}", response_model=AssetRead)
def readAsset(assetID: int, session: Session = Depends(getSession)):
    #Fetch single asset
    asset = assets_service.getByID(session, assetID)
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    
    return asset

@router.post("/", response_model=AssetRead, status_code=status.HTTP_201_CREATED)
def addAsset(assetIn: AssetCreate, session: Session = Depends(getSession)):
    #Create new asset
    return assets_service.create(session, assetIn)
    
@router.patch("/{assetID}", response_model=AssetRead)
def patchAsset(assetID: int, assetIn: AssetUpdate, session: Session = Depends(getSession)):
    #Update existing asset
    asset = assets_service.update(session, assetID, assetIn)
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    
    return asset

@router.delete("/{assetID}", status_code=status.HTTP_204_NO_CONTENT)
def removeAsset(assetID: int, session: Session = Depends(getSession)):
    #Delete asset
    if not assets_service.delete(session, assetID):
        raise HTTPException(status_code=404, detail="Asset not found")
    
    return None