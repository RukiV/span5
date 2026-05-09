from dataclasses import dataclass, field
from typing import Optional, List
from .facilityManagement_dto import FacilityManagementDTO
from .asset_dto import AssetDTO
from .stock_dto import StockDTO
from models.enums import RoomType

@dataclass
class RoomDTO(FacilityManagementDTO):
    type: RoomType
    status: str
    description: str
    capacity: int
    
    assets: Optional[List[AssetDTO]] = field(default_factory=list)
    stocks: Optional[List[StockDTO]] = field(default_factory=list)