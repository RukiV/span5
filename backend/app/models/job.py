from typing import Optional
from datetime import datetime
from sqlmodel import Field
from .base import Base
from .enums import JobStatus

class Jobrecurring(Base, table=True):
    jobrecurr_id: Optional[int] = Field(default=None, primary_key=True)
    job_recurringinterval: Optional[int] = None


class Jobcard(Base, table=True):
    jobcard_id: Optional[int] = Field(default=None, primary_key=True)

    user_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    asset_id: Optional[int] = Field(default=None, foreign_key="asset.asset_id")
    fault_id: Optional[int] = Field(default=None, foreign_key="faultcard.fault_id")
    quote_id: Optional[int] = Field(default=None, foreign_key="quote.quote_id")
    jobrecurr_id: Optional[int] = Field(default=None, foreign_key="jobrecurring.jobrecurr_id")
    mappoint_id: Optional[int] = Field(default=None, foreign_key="mappoint.mappoint_id")

    job_desc: Optional[str] = None
    job_status: JobStatus = Field(default=JobStatus.WAIT)
    job_type: Optional[str] = Field(default=None, max_length=50)

    job_createddatetime: Optional[datetime] = None
    job_finisheddatetime: Optional[datetime] = None