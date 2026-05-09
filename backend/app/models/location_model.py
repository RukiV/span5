from sqlmodel import Relationship
from typing import List, TYPE_CHECKING
from .facilityManagement_model import FacilityManagementBase

if TYPE_CHECKING:
    from .room_model import Room

class Location(FacilityManagementBase, table=True):
    type: str
    status: str
    description: str
    #adres how
    
    rooms: List["Room"] = Relationship(back_populates="location")