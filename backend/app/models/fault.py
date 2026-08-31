<<<<<<< HEAD
from typing import Optional
from datetime import datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .enums import FaultStatus, Priority, Type
from .validators import sanitize_text

class FaultcardBase(SQLModel):
    """Base model for faultcard data."""
    fault_description: str
    fault_type: Optional[Type] = None
    fault_status: FaultStatus = Field(default=FaultStatus.WAIT)
    fault_priority: Priority = Field(default=Priority.MEDIUM)
    fault_reportdatetime: Optional[datetime] = None
    fault_updatedatetime: Optional[datetime] = None
    is_outdoor: bool = False

    @field_validator('fault_description', mode='before')
    @classmethod
    def _sanitize_desc(cls, v, info):
        return sanitize_text(v)


class Faultcard(FaultcardBase, Base, table=True):
    """Model for faultcard data."""
    fault_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    asset_id: Optional[int] = Field(default=None, foreign_key="asset.asset_id")
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    building_id: Optional[int] = Field(default=None, foreign_key="building.building_id")
    location_id: Optional[int] = Field(default=None, foreign_key="location.location_id")
    mappoint_id: Optional[int] = Field(default=None, foreign_key="mappoint.mappoint_id")
    duplicate_of: Optional[int] = Field(default=None, foreign_key="faultcard.fault_id")


class FaultcardCreate(FaultcardBase):
    """Input model for creating faultcard records."""
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    duplicate_of: Optional[int] = None
    # Transient velde: word nie as kolomme gestoor nie — die diens skep/wysig
    # 'n Mappoint (lat/lng) en koppel mappoint_id aan die foutkaartjie.
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class FaultcardRead(FaultcardBase):
    """Output model for reading faultcard records."""
    fault_id: int
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    mappoint_id: Optional[int] = None
    duplicate_of: Optional[int] = None


class FaultcardUpdate(SQLModel):
    """Input model for updating faultcard records."""
    fault_description: Optional[str] = None
    fault_type: Optional[Type] = None
    fault_status: Optional[FaultStatus] = None
    fault_priority: Optional[Priority] = None
    fault_reportdatetime: Optional[datetime] = None
    fault_updatedatetime: Optional[datetime] = None
    is_outdoor: Optional[bool] = None
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    mappoint_id: Optional[int] = None
    duplicate_of: Optional[int] = None
    # Transient velde vir die kaartligging (soos by FaultcardCreate).
    latitude: Optional[float] = None
    longitude: Optional[float] = None
=======
from typing import Optional
from datetime import datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .enums import FaultStatus, Priority, Type
from .validators import sanitize_text

class FaultcardBase(SQLModel):
    """Base model for faultcard data."""
    fault_description: str
    fault_type: Optional[Type] = None
    fault_status: FaultStatus = Field(default=FaultStatus.WAIT)
    fault_priority: Priority = Field(default=Priority.MEDIUM)
    fault_reportdatetime: Optional[datetime] = None
    fault_updatedatetime: Optional[datetime] = None

    @field_validator('fault_description', mode='before')
    @classmethod
    def _sanitize_desc(cls, v, info):
        return sanitize_text(v)


class Faultcard(FaultcardBase, Base, table=True):
    """Model for faultcard data."""
    fault_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    asset_id: Optional[int] = Field(default=None, foreign_key="asset.asset_id")
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    building_id: Optional[int] = Field(default=None, foreign_key="building.building_id")
    location_id: Optional[int] = Field(default=None, foreign_key="location.location_id")
    mappoint_id: Optional[int] = Field(default=None, foreign_key="mappoint.mappoint_id")
            
    # Universal Foreign Key linking to the separate image module
    image_id: Optional[int] = Field(default=None, foreign_key="image.image_id")
    image_id_2: Optional[int] = Field(default=None, foreign_key="image.image_id")
    image_id_3: Optional[int] = Field(default=None, foreign_key="image.image_id")
    
    # No SQLAlchemy relationship object declared here to avoid ambiguous foreign-key resolution


class FaultcardCreate(FaultcardBase):
    """Input model for creating faultcard records."""
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    image_id: Optional[int] = None
    image_id_2: Optional[int] = None
    image_id_3: Optional[int] = None


class FaultcardRead(FaultcardBase):
    """Output model for reading faultcard records."""
    fault_id: int
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    mappoint_id: Optional[int] = None
    image_id: Optional[int] = None
    image_id_2: Optional[int] = None
    image_id_3: Optional[int] = None


class FaultcardUpdate(SQLModel):
    """Input model for updating faultcard records."""
    fault_description: Optional[str] = None
    fault_type: Optional[Type] = None
    fault_status: Optional[FaultStatus] = None
    fault_priority: Optional[Priority] = None
    fault_reportdatetime: Optional[datetime] = None
    fault_updatedatetime: Optional[datetime] = None
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    mappoint_id: Optional[int] = None
    image_id: Optional[int] = None
    image_id_2: Optional[int] = None
    image_id_3: Optional[int] = None
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
