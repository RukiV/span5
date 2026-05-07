from dataclasses import dataclass
from datetime import datetime
from app.dto.facilityManagement_dto import FacilityManagementDTO

@dataclass
class AssetDTO(FacilityManagementDTO):
    type: str
    status: str
    description: str
    isOutdoor: bool
    maintenanceDate: datetime