from typing import List, Optional
from sqlmodel import Session, select
from ..db.database import engine
from ..models.asset import Asset, AssetCreate, AssetRead, Assettype
from ..dto.asset_dto import AssetDTO


class AssetService:
    """Service class for Asset operations"""
    
    @staticmethod
    def get_all_assets() -> List[AssetRead]:
        """Retrieve all assets from the database"""
        with Session(engine) as session:
            assets = session.exec(select(Asset)).all()
            return [AssetRead(**asset.dict()) for asset in assets]
    
    @staticmethod
    def get_asset_by_id(asset_id: int) -> Optional[AssetRead]:
        """Retrieve a specific asset by ID"""
        with Session(engine) as session:
            asset = session.get(Asset, asset_id)
            if not asset:
                return None
            return AssetRead(**asset.dict())
    
    @staticmethod
    def get_assets_by_type(assettype_id: int) -> List[AssetRead]:
        """Retrieve all assets of a specific type"""
        with Session(engine) as session:
            assets = session.exec(
                select(Asset).where(Asset.assettype_id == assettype_id)
            ).all()
            return [AssetRead(**asset.dict()) for asset in assets]
    
    @staticmethod
    def create_asset(asset_data: AssetCreate, room_id: Optional[int] = None) -> AssetRead:
        """Create a new asset"""
        with Session(engine) as session:
            # Verify the asset type exists
            assettype = session.get(Assettype, asset_data.assettype_id)
            if not assettype:
                raise ValueError(f"Asset type with ID {asset_data.assettype_id} not found")
            
            # Create the asset
            asset = Asset(
                **asset_data.dict(),
                room_id=room_id
            )
            session.add(asset)
            session.commit()
            session.refresh(asset)
            return AssetRead(**asset.dict())
    
    @staticmethod
    def update_asset(asset_id: int, asset_data: AssetRead) -> Optional[AssetRead]:
        """Update an existing asset"""
        with Session(engine) as session:
            asset = session.get(Asset, asset_id)
            if not asset:
                return None
            
            # Update only provided fields
            update_data = asset_data.dict(exclude_unset=True)
            for key, value in update_data.items():
                if hasattr(asset, key):
                    setattr(asset, key, value)
            
            session.add(asset)
            session.commit()
            session.refresh(asset)
            return AssetRead(**asset.dict())
    
    @staticmethod
    def delete_asset(asset_id: int) -> bool:
        """Delete an asset"""
        with Session(engine) as session:
            asset = session.get(Asset, asset_id)
            if not asset:
                return False
            
            session.delete(asset)
            session.commit()
            return True
    
    @staticmethod
    def get_asset_count() -> int:
        """Get total count of assets"""
        with Session(engine) as session:
            count = len(session.exec(select(Asset)).all())
            return count
