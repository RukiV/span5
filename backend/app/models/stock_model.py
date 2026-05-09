from sqlmodel import Field, Relationship
from typing import TYPE_CHECKING
from .facilityManagement_model import FacilityManagementBase

if TYPE_CHECKING:
    from .room_model import Room

class Stock(FacilityManagementBase, table=True):
    brand: str
    quantity: int
    type: str
    description: str
    
    room: "Room" = Relationship(back_populates="stocks")