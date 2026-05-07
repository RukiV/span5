from dataclasses import dataclass, field
from typing import Optional, List
from app.dto.facilityManagement_dto import FacilityManagementDTO
from app.dto.room_dto import RoomDTO

@dataclass
class LocationDTO(FacilityManagementDTO):
    type: str
    status: str
    description: str
    #adres how
    
    assets: Optional[List[RoomDTO]] = field(default_factory=list)