import logging
import threading
import time
from datetime import datetime, timedelta
from typing import Sequence

from sqlmodel import Session, func, select

from ..models.asset import Asset, Assettype
from ..models.fault import Faultcard
from ..models.job import Jobcard, JobStatus
from ..models.prediction import AssetPredictionRead
from . import survival_service
from .survival_features import FeatureContext, extract_asset_features

logger = logging.getLogger(__name__)

#: job_type is free-text in the DB ('MAINTENANCE', 'maintenance', 'Onderhoud');
#: the rules path must accept the same variants as the ML feature extraction.
_MAINTENANCE_JOB_TYPES = ("maintenance", "onderhoud")

# In-memory cache for predictions with TTL
_PREDICTIONS_CACHE = None
_PREDICTIONS_CACHE_TIME = 0
_PREDICTIONS_CACHE_TTL = 600  # 10 minutes in seconds

# Verhoed 'n "thundering herd": as die kas koud is, bou slegs een request die
# hele bondel terwyl die res wag en dieselfde resultaat herwin.
_PREDICTIONS_LOCK = threading.Lock()


def _add_months(source: datetime, months: int) -> datetime:
    month = source.month - 1 + months
    year = source.year + month // 12
    month = month % 12 + 1
    day = min(
        source.day,
        [
            31,
            29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28,
            31,
            30,
            31,
            30,
            31,
            31,
            30,
            31,
            30,
            31,
        ][month - 1],
    )
    return source.replace(year=year, month=month, day=day)


class PredictionService:
    def getPredictions(self, session: Session) -> Sequence[AssetPredictionRead]:
        global _PREDICTIONS_CACHE, _PREDICTIONS_CACHE_TIME
        now = time.time()

        # Quick check: if asset count changed, invalidate cache
        asset_count = session.exec(select(func.count(Asset.asset_id))).one()

        # Return cached predictions if still valid and asset count matches
        if (
            _PREDICTIONS_CACHE is not None
            and (now - _PREDICTIONS_CACHE_TIME) < _PREDICTIONS_CACHE_TTL
            and len(_PREDICTIONS_CACHE) == asset_count
        ):
            logger.debug(
                "Returning cached predictions (age: %.1fs, count: %d)",
                now - _PREDICTIONS_CACHE_TIME,
                asset_count,
            )
            return _PREDICTIONS_CACHE

        # Compute fresh predictions under a lock: one request builds the bulk,
        # the rest wait and reuse (no duplicate recomputes on a cold cache).
        with _PREDICTIONS_LOCK:
            now = time.time()
            if (
                _PREDICTIONS_CACHE is not None
                and (now - _PREDICTIONS_CACHE_TIME) < _PREDICTIONS_CACHE_TTL
                and len(_PREDICTIONS_CACHE) == asset_count
            ):
                return _PREDICTIONS_CACHE

            logger.info("Computing fresh predictions for all assets (count: %d)...", asset_count)
            # Load all supporting rows once (assettypes, voltooide onderhoud,
            # foute) — die voorspellingsgang gebruik dan geen per-bate-navrae nie.
            data = _load_prediction_data(session)
            assets = session.exec(select(Asset)).all()
            predictions = [self._predict(session, asset, data) for asset in assets]

            # Update cache
            _PREDICTIONS_CACHE = predictions
            _PREDICTIONS_CACHE_TIME = time.time()
            logger.info("Cached %d predictions", len(predictions))

        return _PREDICTIONS_CACHE

    def invalidateCache(self):
        """Manually invalidate the predictions cache (e.g., after maintenance/fault changes)"""
        global _PREDICTIONS_CACHE, _PREDICTIONS_CACHE_TIME
        _PREDICTIONS_CACHE = None
        _PREDICTIONS_CACHE_TIME = 0
        logger.info("Predictions cache invalidated")

    def getAssetPrediction(self, session: Session, asset_id: int) -> AssetPredictionRead | None:
        asset = session.get(Asset, asset_id)
        if not asset:
            return None
        # Bou 'n bondel-konteks vir net hierdie een bate en gebruik dieselfde
        # gekoste (query-minimaliseer) rekenpad as die volle gang.
        data = _load_prediction_data(session, asset_ids=[asset_id])
        return self._predict(session, asset, data)

    def _predict(
        self, session: Session, asset: Asset, data: FeatureContext | None = None
    ) -> AssetPredictionRead:
        if data is None:
            # Enkele-bate terugval: laai die bondel-konteks vir net hierdie bate.
            data = _load_prediction_data(session, asset_ids=[asset.asset_id])
        assettype = data.assettypes.get(asset.assettype_id)

        assettype_name = assettype.assettype_name if assettype else None
        avg_lifespan_months = (
            assettype.assettype_avg_lifespan
            if (assettype and assettype.assettype_avg_lifespan is not None)
            else None
        )
        service_interval_months = (
            assettype.assettype_service_interval
            if (assettype and assettype.assettype_service_interval is not None)
            else None
        )
        replacement_threshold = (
            assettype.assettype_replacement_threshold
            if (assettype and assettype.assettype_replacement_threshold is not None)
            else 3
        )

        now = datetime.utcnow()

        last_maintenance_date = self._last_maintenance_from(
            data.maintenance_jobs.get(asset.asset_id, [])
        )
        next_maintenance_date = None
        maintenance_overdue = False
        if last_maintenance_date and service_interval_months:
            next_maintenance_date = _add_months(last_maintenance_date, service_interval_months)
            maintenance_overdue = next_maintenance_date < now
        elif service_interval_months and asset.asset_created_datetime:
            # No completed maintenance record yet: be forgiving and only mark an
            # asset overdue once it passes 2x its interval, so older but healthy
            # assets do not immediately show as red due to missing job history.
            next_maintenance_date = _add_months(asset.asset_created_datetime, service_interval_months)
            maintenance_overdue = _add_months(asset.asset_created_datetime, service_interval_months * 2) < now

        creation_date = asset.asset_created_datetime
        lifespan_end_date = None
        lifespan_pct_used = None
        lifespan_exceeded = False
        if creation_date and avg_lifespan_months:
            lifespan_end_date = _add_months(creation_date, avg_lifespan_months)
            total_days = (lifespan_end_date - creation_date).days
            if total_days > 0:
                elapsed_days = (now - creation_date).days
                lifespan_pct_used = round((elapsed_days / total_days) * 100, 1)
            lifespan_exceeded = lifespan_end_date < now

        twelve_months_ago = now - timedelta(days=365)
        fault_count = sum(
            1
            for f in data.faults.get(asset.asset_id, [])
            if f.fault_reportdatetime is not None and f.fault_reportdatetime >= twelve_months_ago
        )
        replacement_suggested = False
        replacement_reason = None
        reasons = []
        if lifespan_exceeded:
            reasons.append(f"Lewensduur oorskry (gemiddeld {avg_lifespan_months} maande)")
        if fault_count >= replacement_threshold:
            reasons.append(f"{fault_count} foute in laaste 12 maande (drempel: {replacement_threshold})")
        if maintenance_overdue and next_maintenance_date:
            days_overdue = (now - next_maintenance_date).days
            if days_overdue > 180:
                reasons.append(f"Onderhoud {days_overdue} dae agterstallig")

        # --- ML survival layer (Phase 2c) ---
        # The survival model is optional: sparse data or a missing sksurv leaves
        # the model unavailable and the rules-only pipeline continues unaffected.
        survival_fields = {}
        try:
            if survival_service.is_available():
                features = extract_asset_features(session, asset, now, ctx=data)
                survival = survival_service.predict_for_asset(features)
                if survival:
                    survival_fields = survival
                    survival_fields["survival_model_available"] = True
        except Exception:
            logger.exception(
                "Survival-voorspelling misluk vir bate %s — reëls-only.",
                asset.asset_id,
            )

        if (
            survival_fields.get("survival_high_risk")
            and survival_fields.get("survival_failure_prob_12mo") is not None
        ):
            ml_reason = (
                f"ML: {survival_fields['survival_failure_prob_12mo'] * 100:.0f}% "
                f"faalkans binne 12 maande"
            )
            if ml_reason not in reasons:
                reasons.append(ml_reason)

        if reasons:
            replacement_suggested = True
            replacement_reason = "; ".join(reasons)

        return AssetPredictionRead(
            asset_id=asset.asset_id,
            asset_name=asset.asset_name,
            asset_serial=asset.asset_serial,
            assettype_name=assettype_name,
            last_maintenance_date=last_maintenance_date,
            next_maintenance_date=next_maintenance_date,
            maintenance_interval_months=service_interval_months,
            maintenance_overdue=maintenance_overdue,
            creation_date=creation_date,
            avg_lifespan_months=avg_lifespan_months,
            lifespan_end_date=lifespan_end_date,
            lifespan_pct_used=lifespan_pct_used,
            lifespan_exceeded=lifespan_exceeded,
            fault_count_12months=fault_count,
            replacement_threshold=replacement_threshold,
            replacement_suggested=replacement_suggested,
            replacement_reason=replacement_reason,
            **survival_fields,
        )

    @staticmethod
    def _last_maintenance_from(jobs: Sequence[Jobcard]) -> datetime | None:
        """Laaste onderhoudsdatum sonder DB-aanloop.

        Ekvivalent aan die ou ``_last_maintenance``-navraag (bestel op
        ``job_finisheddatetime`` DESC met NULL laaste, dan terugval op
        ``job_createddatetime`` van daardie werk).
        """
        finished = [j for j in jobs if j.job_finisheddatetime]
        if finished:
            job = max(finished, key=lambda j: j.job_finisheddatetime)
            return job.job_finisheddatetime
        created = [j.job_createddatetime for j in jobs if j.job_createddatetime]
        return max(created) if created else None

    def _last_maintenance(self, session: Session, asset_id: int) -> datetime | None:
        job = session.exec(
            select(Jobcard)
            .where(Jobcard.asset_id == asset_id)
            .where(func.lower(Jobcard.job_type).in_(_MAINTENANCE_JOB_TYPES))
            .where(Jobcard.job_status == JobStatus.COMPLETED)
            .order_by(Jobcard.job_finisheddatetime.desc())
        ).first()
        if job and job.job_finisheddatetime:
            return job.job_finisheddatetime
        if job and job.job_createddatetime:
            return job.job_createddatetime
        return None


def _load_prediction_data(
    session: Session, asset_ids: list[int] | None = None
) -> FeatureContext:
    """Laai al die ondersteunende rye vir die voorspellingsgang in een bondel.

    Drie navrae (assettypes, voltooide onderhoud, foute) in plaas van ~6 per
    bate. Wanneer ``asset_ids`` gegee word, word slegs daardie bates gelaai
    (gebruik deur ``getAssetPrediction``).
    """
    assettypes = {
        at.assettype_id: at for at in session.exec(select(Assettype)).all()
    }

    maintenance_stmt = (
        select(Jobcard)
        .where(func.lower(Jobcard.job_type).in_(_MAINTENANCE_JOB_TYPES))
        .where(Jobcard.job_status == JobStatus.COMPLETED)
    )
    if asset_ids is not None:
        maintenance_stmt = maintenance_stmt.where(Jobcard.asset_id.in_(asset_ids))
    maintenance_jobs: dict[int, list[Jobcard]] = {}
    for job in session.exec(maintenance_stmt).all():
        if job.asset_id is not None:
            maintenance_jobs.setdefault(job.asset_id, []).append(job)

    fault_stmt = select(Faultcard)
    if asset_ids is not None:
        fault_stmt = fault_stmt.where(Faultcard.asset_id.in_(asset_ids))
    faults: dict[int, list[Faultcard]] = {}
    for fault in session.exec(fault_stmt).all():
        if fault.asset_id is not None:
            faults.setdefault(fault.asset_id, []).append(fault)

    return FeatureContext(assettypes, maintenance_jobs, faults)


prediction_service = PredictionService()

