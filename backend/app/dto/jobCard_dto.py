from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional
from app.models.enums import JobStatus, Priority, Type
from app.dto.faultCard_dto import FaultCardDTO
from app.dto.location_dto import LocationDTO
from app.dto.mapPoint_dto import MapPointDTO
from app.dto.quote_dto import QuoteDTO
from app.dto.asset_dto import AssetDTO
from app.dto.room_dto import RoomDTO

@dataclass
class JobCardDTO:
    id: int
    title: str
    description: str
    status: JobStatus
    priority: Priority
    type: Type
    createdDate: datetime
    faultCard: FaultCardDTO
    isRecurring: bool
    isEmergency: bool
    location: LocationDTO
    recurringInterval: Optional[int] = None  # in days, weeks, ect
    scheduledDate: Optional[datetime] = None
    completedDate: Optional[datetime] = None
    quotes: Optional[List[QuoteDTO]] = field(default_factory=list)  
    asset: Optional[AssetDTO]
    room: Optional[RoomDTO]
    mapPoint: Optional[MapPointDTO]