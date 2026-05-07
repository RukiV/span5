from dataclasses import dataclass, field
from typing import Optional, List
from app.dto.facilityManagement_dto import FacilityManagementDTO
from app.dto.asset_dto import AssetDTO
from app.dto.stock_dto import StockDTO

@dataclass
class RoomDTO(FacilityManagementDTO):
    type: str
    status: str
    description: str
    capacity: int
    
    assets: Optional[List[AssetDTO]] = field(default_factory=list)
    stocks: Optional[List[StockDTO]] = field(default_factory=list)