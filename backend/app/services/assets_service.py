from ..models.asset import Asset, AssetCreate, AssetUpdate
from .base_service import BaseService

assets_service = BaseService[Asset, AssetCreate, AssetUpdate](Asset)