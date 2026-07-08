from typing import Optional
from datetime import datetime
from sqlmodel import SQLModel


class AssetPredictionRead(SQLModel):
    asset_id: int
    asset_name: str
    asset_serial: str
    assettype_name: Optional[str] = None

    last_maintenance_date: Optional[datetime] = None
    next_maintenance_date: Optional[datetime] = None
    maintenance_interval_months: Optional[int] = None
    maintenance_overdue: bool = False

    creation_date: Optional[datetime] = None
    avg_lifespan_months: Optional[int] = None
    lifespan_end_date: Optional[datetime] = None
    lifespan_pct_used: Optional[float] = None
    lifespan_exceeded: bool = False

    fault_count_12months: int = 0
    replacement_suggested: bool = False
    replacement_reason: Optional[str] = None
