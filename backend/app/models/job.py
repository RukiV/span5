from typing import Optional
from datetime import datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .enums import JobStatus
from .validators import sanitize_text, validate_positive_int

class JobrecurringBase(SQLModel):
    job_recurringinterval: Optional[int] = None

    @field_validator('job_recurringinterval', mode='before')
    @classmethod
    def _positive_interval(cls, v, info):
        return validate_positive_int(v)


class Jobrecurring(JobrecurringBase, Base, table=True):
    jobrecurr_id: Optional[int] = Field(default=None, primary_key=True)


class JobrecurringCreate(JobrecurringBase):
    pass


class JobrecurringRead(JobrecurringBase):
    jobrecurr_id: int


class JobrecurringUpdate(SQLModel):
    job_recurringinterval: Optional[int] = None


class JobcardBase(SQLModel):
    job_desc: str
    job_status: JobStatus = Field(default=JobStatus.WAIT)
    job_type: Optional[str] = Field(default=None, max_length=50)
    job_createddatetime: Optional[datetime] = None
    job_finisheddatetime: Optional[datetime] = None

    @field_validator('job_desc', 'job_type', mode='before')
    @classmethod
    def _sanitize_strings(cls, v, info):
        return sanitize_text(v)


class Jobcard(JobcardBase, Base, table=True):
    jobcard_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    asset_id: Optional[int] = Field(default=None, foreign_key="asset.asset_id")
    fault_id: Optional[int] = Field(default=None, foreign_key="faultcard.fault_id")
    quote_id: Optional[int] = Field(default=None, foreign_key="quote.quote_id")
    jobrecurr_id: Optional[int] = Field(default=None, foreign_key="jobrecurring.jobrecurr_id")
    mappoint_id: Optional[int] = Field(default=None, foreign_key="mappoint.mappoint_id")


class JobcardCreate(JobcardBase):
    asset_id: Optional[int] = None


class JobcardRead(JobcardBase):
    jobcard_id: int
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    fault_id: Optional[int] = None
    quote_id: Optional[int] = None
    jobrecurr_id: Optional[int] = None
    mappoint_id: Optional[int] = None


class JobcardUpdate(SQLModel):
    job_desc: Optional[str] = None
    job_status: Optional[JobStatus] = None
    job_type: Optional[str] = None
    job_createddatetime: Optional[datetime] = None
    job_finisheddatetime: Optional[datetime] = None
    user_id: Optional[int] = None
    asset_id: Optional[int] = None
    fault_id: Optional[int] = None
    quote_id: Optional[int] = None
    jobrecurr_id: Optional[int] = None
    mappoint_id: Optional[int] = None