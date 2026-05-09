from sqlmodel import Field, Relationship
from typing import List, TYPE_CHECKING
from .facilityManagement_model import FacilityManagementBase
from .enums import RoomType

if TYPE_CHECKING:
    from .location_model import Location
    from .asset_model import Asset
    from .stock_model import Stock

class Room(FacilityManagementBase, table=True):
    type: RoomType = Field(default=RoomType.OTHER)
    status: str
    description: str
    capacity: int
    
    assets: List["Asset"] = Relationship(back_populates="room")
    stocks: List["Stock"] = Relationship(back_populates="room")

    location: "Location" = Relationship(back_populates="rooms")