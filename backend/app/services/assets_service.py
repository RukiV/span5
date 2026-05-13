from ..models.asset import Asset, AssetCreate, AssetUpdate
from .base_service import BaseService
from sqlmodel import Session, select

class AssetService(BaseService[Asset, AssetCreate, AssetUpdate]):
    def __init__(self):
        super().__init__(Asset)
    
    def getBySerial(self, session: Session, serial: str) -> Asset | None:
        return session.exec(select(Asset).where(Asset.asset_serial == serial)).first()

assets_service = AssetService()