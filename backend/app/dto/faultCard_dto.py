from dataclasses import dataclass
from datetime import datetime
from typing import Optional
from backend.app.models.enums import Priority, Type, FaultStatus
from app.dto.location_dto import LocationDTO
from app.dto.user_dto import UserDTO
from app.dto.asset_dto import AssetDTO
from app.dto.room_dto import RoomDTO
from app.dto.mapPoint_dto import MapPointDTO

@dataclass
class FaultCardDTO:
    id: int
    title: str
    description: str
    status: FaultStatus
    priority: Priority
    type: Type
    reportDate: datetime
    reporter: UserDTO
    location: LocationDTO
    asset: Optional[AssetDTO]
    room: Optional[RoomDTO]
    mapPoint: Optional[MapPointDTO]