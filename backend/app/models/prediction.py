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
    # The assettype's replacement threshold (default 3) — the scheduler uses
    # this, not a hardcoded 3, so predictions and auto-drafts stay consistent.
    replacement_threshold: int = 3
    replacement_suggested: bool = False
    replacement_reason: Optional[str] = None

    # --- ML survival layer (Phase 2c) ---
    # All optional/backward-compatible: when the survival model is unavailable
    # (sparse data, missing scikit-survival, or disabled) every field keeps its
    # default and the rules-only pipeline is unchanged.
    survival_model_available: bool = False
    survival_risk: Optional[float] = None
    survival_failure_prob_12mo: Optional[float] = None
    survival_median_days: Optional[float] = None
    survival_high_risk: bool = False
    survival_events_count: Optional[int] = None
    survival_trained_at: Optional[datetime] = None
