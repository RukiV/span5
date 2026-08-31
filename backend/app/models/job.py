<<<<<<< HEAD
from typing import Optional
from datetime import date, datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field, Relationship
from .base import Base
from .enums import JobStatus
from .validators import sanitize_text, validate_positive_int

from .image import ImageAsset, ImageAssetRead

class JobrecurringBase(SQLModel):
    """Base model for jobrecurring data."""
    job_recurringinterval: Optional[int] = None

    @field_validator('job_recurringinterval', mode='before')
    @classmethod
    def _positive_interval(cls, v, info):
        return validate_positive_int(v)


class Jobrecurring(JobrecurringBase, Base, table=True):
    """Model for jobrecurring data."""
    jobrecurr_id: Optional[int] = Field(default=None, primary_key=True)


class JobrecurringCreate(JobrecurringBase):
    """Input model for creating jobrecurring records."""
    pass


class JobrecurringRead(JobrecurringBase):
    """Output model for reading jobrecurring records."""
    jobrecurr_id: int


class JobrecurringUpdate(SQLModel):
    """Input model for updating jobrecurring records."""
    job_recurringinterval: Optional[int] = None


class JobcardBase(SQLModel):
    """Base model for jobcard data."""
    job_desc: str
    job_status: JobStatus = Field(default=JobStatus.WAIT)
    job_type: Optional[str] = Field(default=None, max_length=50)
    job_createddatetime: Optional[datetime] = None
    job_scheduled_datetime: Optional[datetime] = None
    job_scheduled_end_datetime: Optional[datetime] = None
    job_schedule_type: Optional[str] = Field(default="enkel", max_length=20)
    job_finisheddatetime: Optional[datetime] = None
    quote_ids: Optional[str] = None
    job_priority: Optional[str] = Field(default="Normal", max_length=20)
    nature: Optional[str] = Field(default=None, max_length=100)
    assigned_to: Optional[int] = Field(default=None, foreign_key="user.user_id")
    cc_users: Optional[str] = Field(default=None)
    job_notes: Optional[str] = Field(default=None, max_length=5000)

    @field_validator('job_desc', 'job_type', 'job_notes', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)

    @field_validator('job_scheduled_datetime', mode='before')
    @classmethod
    def _normalize_scheduled_date(cls, v):
        if v is None or v == "":
            return None
        if isinstance(v, datetime):
            return v
        if isinstance(v, date):
            return datetime.combine(v, datetime.min.time())
        return v


class Jobcard(JobcardBase, Base, table=True):
    """Model for jobcard data."""
    jobcard_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    contractor_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    asset_id: Optional[int] = Field(default=None, foreign_key="asset.asset_id")
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    building_id: Optional[int] = Field(default=None, foreign_key="building.building_id")
    location_id: Optional[int] = Field(default=None, foreign_key="location.location_id")
    fault_id: Optional[int] = Field(default=None, foreign_key="faultcard.fault_id")
    quote_id: Optional[int] = Field(default=None, foreign_key="quote.quote_id")
    jobrecurr_id: Optional[int] = Field(default=None, foreign_key="jobrecurring.jobrecurr_id")
    mappoint_id: Optional[int] = Field(default=None, foreign_key="mappoint.mappoint_id")
    duplicate_of: Optional[int] = Field(default=None, foreign_key="jobcard.jobcard_id")


class JobcardCreate(JobcardBase):
    """Input model for creating jobcard records."""
    contractor_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    fault_id: Optional[int] = None
    duplicate_of: Optional[int] = None
    mappoint_id: Optional[int] = None
    # Transiënte velde: word nie as kolomme gestoor nie — die diens skep/wysig
    # 'n Mappoint (lat/lng) en koppel mappoint_id aan die werksopdrag, sodat
    # die kontrakteur die fout se presiese ligging sien.
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class JobcardRead(JobcardBase):
    """Output model for reading jobcard records."""
    jobcard_id: int
    user_id: Optional[int] = None
    contractor_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    fault_id: Optional[int] = None
    quote_id: Optional[int] = None
    jobrecurr_id: Optional[int] = None
    mappoint_id: Optional[int] = None
    assigned_name: Optional[str] = None
    contractor_name: Optional[str] = None


class JobcardUpdate(SQLModel):
    """Input model for updating jobcard records."""
    job_desc: Optional[str] = None
    job_status: Optional[JobStatus] = None
    job_type: Optional[str] = None
    job_priority: Optional[str] = None
    nature: Optional[str] = None
    job_createddatetime: Optional[datetime] = None
    job_scheduled_datetime: Optional[datetime] = None
    job_scheduled_end_datetime: Optional[datetime] = None
    job_schedule_type: Optional[str] = None
    job_finisheddatetime: Optional[datetime] = None
    quote_ids: Optional[str] = None
    job_notes: Optional[str] = None
    user_id: Optional[int] = None
    contractor_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    fault_id: Optional[int] = None
    assigned_to: Optional[int] = None
    cc_users: Optional[str] = None
    quote_id: Optional[int] = None
    jobrecurr_id: Optional[int] = None
    mappoint_id: Optional[int] = None
    # Transiënte velde vir die kaartligging (soos by JobcardCreate).
    latitude: Optional[float] = None
    longitude: Optional[float] = None
=======
from typing import Optional
from datetime import date, datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field, Relationship
from .base import Base
from .enums import JobStatus
from .validators import sanitize_text, validate_positive_int

from .image import ImageAsset, ImageAssetRead

class JobrecurringBase(SQLModel):
    """Base model for jobrecurring data."""
    job_recurringinterval: Optional[int] = None

    @field_validator('job_recurringinterval', mode='before')
    @classmethod
    def _positive_interval(cls, v, info):
        return validate_positive_int(v)


class Jobrecurring(JobrecurringBase, Base, table=True):
    """Model for jobrecurring data."""
    jobrecurr_id: Optional[int] = Field(default=None, primary_key=True)


class JobrecurringCreate(JobrecurringBase):
    """Input model for creating jobrecurring records."""
    pass


class JobrecurringRead(JobrecurringBase):
    """Output model for reading jobrecurring records."""
    jobrecurr_id: int


class JobrecurringUpdate(SQLModel):
    """Input model for updating jobrecurring records."""
    job_recurringinterval: Optional[int] = None


class JobcardBase(SQLModel):
    """Base model for jobcard data."""
    job_desc: str
    job_status: JobStatus = Field(default=JobStatus.WAIT)
    job_type: Optional[str] = Field(default=None, max_length=50)
    job_createddatetime: Optional[datetime] = None
    job_scheduled_datetime: Optional[datetime] = None
    job_schedule_type: Optional[str] = Field(default="enkel", max_length=20)
    job_finisheddatetime: Optional[datetime] = None
    quote_ids: Optional[str] = None

    @field_validator('job_desc', 'job_type', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)

    @field_validator('job_scheduled_datetime', mode='before')
    @classmethod
    def _normalize_scheduled_date(cls, v):
        if v is None or v == "":
            return None
        if isinstance(v, datetime):
            return v
        if isinstance(v, date):
            return datetime.combine(v, datetime.min.time())
        return v


class Jobcard(JobcardBase, Base, table=True):
    """Model for jobcard data."""
    jobcard_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    asset_id: Optional[int] = Field(default=None, foreign_key="asset.asset_id")
    room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    building_id: Optional[int] = Field(default=None, foreign_key="building.building_id")
    location_id: Optional[int] = Field(default=None, foreign_key="location.location_id")
    fault_id: Optional[int] = Field(default=None, foreign_key="faultcard.fault_id")
    quote_id: Optional[int] = Field(default=None, foreign_key="quote.quote_id")
    jobrecurr_id: Optional[int] = Field(default=None, foreign_key="jobrecurring.jobrecurr_id")
    mappoint_id: Optional[int] = Field(default=None, foreign_key="mappoint.mappoint_id")
            
    # Universal Foreign Key linking to the separate image module
    image_id: Optional[int] = Field(default=None, foreign_key="image.image_id")
    
    # Unidirectional relationship 
    image: Optional[ImageAsset] = Relationship()


class JobcardCreate(JobcardBase):
    """Input model for creating jobcard records."""
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    fault_id: Optional[int] = None
    image_id: Optional[int] = None


class JobcardRead(JobcardBase):
    """Output model for reading jobcard records."""
    jobcard_id: int
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    fault_id: Optional[int] = None
    quote_id: Optional[int] = None
    jobrecurr_id: Optional[int] = None
    mappoint_id: Optional[int] = None
    image_id: Optional[int] = None
    
    image: Optional[ImageAssetRead] = None


class JobcardUpdate(SQLModel):
    """Input model for updating jobcard records."""
    job_desc: Optional[str] = None
    job_status: Optional[JobStatus] = None
    job_type: Optional[str] = None
    job_createddatetime: Optional[datetime] = None
    job_scheduled_datetime: Optional[datetime] = None
    job_schedule_type: Optional[str] = None
    job_finisheddatetime: Optional[datetime] = None
    quote_ids: Optional[str] = None
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None
    location_id: Optional[int] = None
    fault_id: Optional[int] = None
    quote_id: Optional[int] = None
    jobrecurr_id: Optional[int] = None
    mappoint_id: Optional[int] = None
    image_id: Optional[int] = None
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
