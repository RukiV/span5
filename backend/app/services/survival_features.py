"""Survival-analysis feature extraction (Phase 2c).

Pure, side-effect-free helpers that turn DB rows into the 8-dimension feature
vector consumed by the RandomSurvivalForest in ``survival_service``. The module
is deliberately model-free and database-bound so the lookahead-bias rule —
features are computed at ``t_ref = min(event_time, censor_time)`` — can be
unit-tested in isolation from the ML code.
"""

import logging
from datetime import datetime, timedelta
from typing import Any

import numpy as np
from sqlmodel import Session, select

from ..models.asset import Asset, Assettype
from ..models.enums import JobStatus, Priority
from ..models.fault import Faultcard
from ..models.job import Jobcard

logger = logging.getLogger(__name__)

#: Column order — never change: the forest is trained and scored on this layout.
FEATURE_NAMES = [
    "age_days",
    "lifespan_ratio",
    "service_interval_days",
    "maintenance_count_per_year",
    "days_since_last_maintenance",
    "fault_count_12mo",
    "fault_rate_per_year",
    "high_priority_fault_ratio_12mo",
]

DAYS_PER_MONTH = 30.44
DAYS_PER_YEAR = 365.25
ONE_YEAR = timedelta(days=365)


def _completed_maintenance_jobs(session: Session, asset_id: int) -> list[Jobcard]:
    """All COMPLETED maintenance jobcards for an asset (latest first)."""
    return session.exec(
        select(Jobcard)
        .where(Jobcard.asset_id == asset_id)
        .where(Jobcard.job_type == "maintenance")
        .where(Jobcard.job_status == JobStatus.COMPLETED)
        .order_by(Jobcard.job_finisheddatetime.desc(), Jobcard.job_createddatetime.desc())
    ).all()


def _maintenance_datetime(job: Jobcard) -> datetime | None:
    """Finished datetime, falling back to the created datetime exactly like
    ``prediction_service._last_maintenance`` does."""
    if job.job_finisheddatetime:
        return job.job_finisheddatetime
    return job.job_createddatetime


def _asset_faults(session: Session, asset_id: int) -> list[Faultcard]:
    """All faultcards referencing the asset, for timestamp windowing in Python.

    Per-asset scanning keeps the SQL trivial and the lookahead rule explicit;
    training runs once per ``SURVIVAL_RETRAIN_INTERVAL`` and prediction runs on
    a single asset, so the cost is acceptable.
    """
    return session.exec(
        select(Faultcard).where(Faultcard.asset_id == asset_id)
    ).all()


def extract_asset_features(session: Session, asset: Asset, t_ref: datetime) -> dict[str, float]:
    """Feature vector for one asset as observed from reference time ``t_ref``.

    Only data available at ``t_ref`` is used (completed maintenance dated
    ``<= t_ref``, faults inside/behind ``<= t_ref`` windows) so training rows
    carry no lookahead bias. Missing assettype fields impute to 0.
    """
    if asset.asset_created_datetime is None:
        age_days = 0.0
    else:
        age_days = float((t_ref - asset.asset_created_datetime).days)

    assettype = session.get(Assettype, asset.assettype_id)
    avg_lifespan = assettype.assettype_avg_lifespan if assettype else None
    service_interval = assettype.assettype_service_interval if assettype else None

    # 1. age_days
    # 2. lifespan_ratio — fraction of the expected lifespan already consumed.
    lifespan_ratio = (
        age_days / (avg_lifespan * DAYS_PER_MONTH) if avg_lifespan else 0.0
    )

    # 3. service_interval_days — the assettype's scheduled maintenance cadence.
    service_interval_days = service_interval * DAYS_PER_MONTH if service_interval else 0.0

    # Guard against a divide-by-zero on brand-new assets (or missing created_at).
    years_floor = max(age_days / DAYS_PER_YEAR, 0.1)

    # 4./5. maintenance history (only jobs finished/created at or before t_ref).
    maintenance_times = [
        dt
        for dt in (_maintenance_datetime(job) for job in _completed_maintenance_jobs(session, asset.asset_id))
        if dt is not None and dt <= t_ref
    ]
    maintenance_count_per_year = len(maintenance_times) / years_floor
    if maintenance_times:
        days_since_last_maintenance = float((t_ref - max(maintenance_times)).days)
    else:
        # No maintenance ever: the asset has gone its whole life unserviced.
        days_since_last_maintenance = age_days

    # 6./7./8. fault history.
    window_start = t_ref - ONE_YEAR
    fault_count_12mo = 0
    total_faults = 0
    high_count = 0
    priority_count = 0
    for fault in _asset_faults(session, asset.asset_id):
        if getattr(fault, "duplicate_of", None) is not None:
            continue
        reported = fault.fault_reportdatetime
        if reported is None:
            continue
        if reported <= t_ref:
            total_faults += 1
            if window_start <= reported:
                fault_count_12mo += 1
                priority = fault.fault_priority
                if priority is not None:
                    priority_count += 1
                    # Python 3.14 gotcha: ``Priority(value)`` resolves by VALUE
                    # (``"Hoog"``); comparing the enum NAME is unambiguous.
                    if priority.name == Priority.HIGH.name:
                        high_count += 1

    fault_rate_per_year = total_faults / years_floor
    high_priority_fault_ratio_12mo = high_count / priority_count if priority_count else 0.0

    return {
        "age_days": age_days,
        "lifespan_ratio": lifespan_ratio,
        "service_interval_days": service_interval_days,
        "maintenance_count_per_year": maintenance_count_per_year,
        "days_since_last_maintenance": days_since_last_maintenance,
        "fault_count_12mo": float(fault_count_12mo),
        "fault_rate_per_year": fault_rate_per_year,
        "high_priority_fault_ratio_12mo": high_priority_fault_ratio_12mo,
    }


def build_training_set(
    session: Session, t_ref_cutoff: datetime
) -> tuple[np.ndarray, np.ndarray, list[int], list[tuple[Any, datetime | None]]]:
    """Build the (X, y, asset_ids, rows) training set for the survival model.

    Event definition: time-to-first-fault. ``event_time`` is the earliest
    faultcard datetime for the asset (duplicates excluded); assets with no
    fault before ``t_ref_cutoff`` are right-censored at the cutoff. Features
    are computed at ``t_ref = min(event_time, cutoff)`` — the lookahead-bias
    rule. Assets without a created_datetime are skipped (no age baseline).

    Returns:
        X:      (n_assets, 8) float64 array, columns in ``FEATURE_NAMES`` order.
        y:      structured array ``[("event", bool), ("time", float)]`` where
                ``time`` is time-to-first-fault in days (right-censored for
                assets that never faulted before the cutoff).
        ids:    asset ids, ascending by asset_id (deterministic row order).
        rows:   ``(asset, event_time_or_None)`` tuples for tracing/debugging.
    """
    assets = session.exec(select(Asset).order_by(Asset.asset_id)).all()

    x_rows: list[list[float]] = []
    times: list[float] = []
    events: list[bool] = []
    ids: list[int] = []
    rows: list[tuple[Any, datetime | None]] = []

    for asset in assets:
        created = asset.asset_created_datetime
        if created is None:
            continue

        event_times = [
            fault.fault_reportdatetime
            for fault in _asset_faults(session, asset.asset_id)
            if fault.fault_reportdatetime is not None
            and getattr(fault, "duplicate_of", None) is None
        ]
        first_fault = min(event_times) if event_times else None

        if first_fault is not None and first_fault <= t_ref_cutoff:
            event = True
            t_ref = first_fault - timedelta(microseconds=1)  # no lookahead: exclude the triggering fault itself
            feature_time = first_fault
        else:
            event = False
            t_ref = t_ref_cutoff
            feature_time = t_ref_cutoff
        time_days = float((feature_time - created).days)

        features = extract_asset_features(session, asset, t_ref)
        x_rows.append([features[name] for name in FEATURE_NAMES])
        times.append(max(time_days, 0.0))
        events.append(event)
        ids.append(asset.asset_id)
        rows.append((asset, first_fault))

    X = (
        np.array(x_rows, dtype=float)
        if x_rows
        else np.empty((0, len(FEATURE_NAMES)), dtype=float)
    )
    y = np.zeros(len(ids), dtype=[("event", bool), ("time", float)])
    y["event"] = np.array(events, dtype=bool)
    y["time"] = np.array(times, dtype=float)
    return X, y, ids, rows
