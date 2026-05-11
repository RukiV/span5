from typing import List, Optional
from sqlmodel import Session, select
from ..models.asset import Asset, AssetCreate, AssetRead, Assettype

def getAllAssets(session: Session) -> List[Asset]:
    return session.exec(select(Asset)).all()

def getAssetByID(session: Session, assetID: int) -> Optional[Asset]:
    return session.get(Asset, assetID)

def createAsset(session: Session, assetData: AssetCreate, roomID: Optional[int] = None) -> Asset:
    assettype = session.get(Assettype, assetData.assettype_id)
    if not assettype:
        raise ValueError(f"Asset type with ID {assetData.assettype_id} not found")
    
    asset = Asset(**assetData.dict(), roomID = roomID)

    session.add(asset)
    session.commit()
    session.refresh(asset)
    return asset

def updateAsset(session: Session, assetID: int, assetData: AssetRead) -> Optional[Asset]:
    asset = session.get(Asset, assetID)
    if not asset:
        return None
    
    updateData = assetData.model_dump(exclude_unset=True)
    asset.sqlmodel_update(updateData)

    session.add(asset)
    session.commit()
    session.refresh(asset)
    return asset

def deleteAsset(session: Session, assetID: int) -> bool:
    asset = session.get(Asset, assetID)
    if not asset:
        return False
    
    session.delete(asset)
    session.commit()
    return True
