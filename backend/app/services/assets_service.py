from sqlalchemy import func

from ..models.asset import Asset, AssetCreate, AssetUpdate
from .base_service import BaseService
from sqlmodel import Session, select

class AssetService(BaseService[Asset, AssetCreate, AssetUpdate]):
    def __init__(self):
        super().__init__(Asset)
    
    def getBySerial(self, session: Session, serial: str) -> Asset | None:
        return session.exec(select(Asset).where(Asset.asset_serial == serial)).first()

    def getStatusSummary(self, session: Session) -> list[dict]:
        statement = (
            select(Asset.asset_status, func.count(Asset.asset_id))
            .group_by(Asset.asset_status)
        )
        results = session.exec(statement).all()

        return [
            {
                "status": status.value if hasattr(status, "value") else str(status),
                "count": count,
            }
            for status, count in results
        ]

assets_service = AssetService()