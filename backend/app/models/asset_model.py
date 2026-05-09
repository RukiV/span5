from sqlmodel import Field, Relationship
from typing import TYPE_CHECKING
from datetime import datetime
from .facilityManagement_model import FacilityManagementBase
from .enums import AssetStatus

if TYPE_CHECKING:
    from room_model import Room

class Asset(FacilityManagementBase, table=True):
    type: str
    status: AssetStatus = Field(default=AssetStatus.ACTIVE)
    description: str
    isOutdoor: bool = Field(default=False)
    maintenanceDate: datetime

    room: "Room" = Relationship(back_populates="assets")