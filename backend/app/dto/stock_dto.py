from dataclasses import dataclass
from app.dto import FacilityManagementDTO

@dataclass
class StockDTO(FacilityManagementDTO):
    brand: str
    quantity: int
    type: str
    description: str