from dataclasses import dataclass
from app.dto.facilityManagement_dto import FacilityManagementDTO

@dataclass
class StockDTO(FacilityManagementDTO):
    brand: str
    quantity: int
    type: str
    description: str