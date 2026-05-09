from dataclasses import dataclass
from datetime import datetime
from app.dto.facilityManagement_dto import FacilityManagementDTO
from app.models.enums import AssetStatus

@dataclass
class AssetDTO(FacilityManagementDTO):
    type: str
    status: AssetStatus
    description: str
    isOutdoor: bool
    maintenanceDate: datetime