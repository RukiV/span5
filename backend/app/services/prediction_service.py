import logging
import time
from datetime import datetime, timedelta
from typing import Sequence
from sqlmodel import Session, select, func

from ..models.asset import Asset, Assettype
from ..models.job import Jobcard, JobStatus
from ..models.fault import Faultcard
from ..models.prediction import AssetPredictionRead
from . import survival_service
from .survival_features import extract_asset_features

logger = logging.getLogger(__name__)

# In-memory cache for predictions with TTL
_PREDICTIONS_CACHE = None
_PREDICTIONS_CACHE_TIME = 0
_PREDICTIONS_CACHE_TTL = 600  # 10 minutes in seconds


def _add_months(source: datetime, months: int) -> datetime:
    month = source.month - 1 + months
    year = source.year + month // 12
    month = month % 12 + 1
    day = min(source.day, [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28,
                           31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1])
    return source.replace(year=year, month=month, day=day)


class PredictionService:

    def getPredictions(self, session: Session) -> Sequence[AssetPredictionRead]:
        global _PREDICTIONS_CACHE, _PREDICTIONS_CACHE_TIME
        now = time.time()
        
        # Quick check: if asset count changed, invalidate cache
        asset_count = session.exec(select(func.count(Asset.asset_id))).one()
        
        # Return cached predictions if still valid and asset count matches
        if (_PREDICTIONS_CACHE is not None and 
            (now - _PREDICTIONS_CACHE_TIME) < _PREDICTIONS_CACHE_TTL and
            len(_PREDICTIONS_CACHE) == asset_count):
            logger.debug("Returning cached predictions (age: %.1fs, count: %d)", 
                         now - _PREDICTIONS_CACHE_TIME, asset_count)
            return _PREDICTIONS_CACHE
        
        # Compute fresh predictions
        logger.info("Computing fresh predictions for all assets (count: %d)...", asset_count)
        assets = session.exec(select(Asset)).all()
        predictions = [self._predict(session, asset) for asset in assets]
        
        # Update cache
        _PREDICTIONS_CACHE = predictions
        _PREDICTIONS_CACHE_TIME = now
        logger.info("Cached %d predictions", len(predictions))
        
        return predictions

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
        return self._predict(session, asset)

    def _predict(self, session: Session, asset: Asset) -> AssetPredictionRead:
        assettype = session.get(Assettype, asset.assettype_id)

        assettype_name = assettype.assettype_name if assettype else None
        avg_lifespan_months = assettype.assettype_avg_lifespan if (assettype and assettype.assettype_avg_lifespan is not None) else None
        service_interval_months = assettype.assettype_service_interval if (assettype and assettype.assettype_service_interval is not None) else None
        replacement_threshold = assettype.assettype_replacement_threshold if (assettype and assettype.assettype_replacement_threshold is not None) else 3

        now = datetime.utcnow()

        last_maintenance_date = self._last_maintenance(session, asset.asset_id)
        next_maintenance_date = None
        maintenance_overdue = False
        if last_maintenance_date and service_interval_months:
            next_maintenance_date = _add_months(last_maintenance_date, service_interval_months)
            maintenance_overdue = next_maintenance_date < now
        elif service_interval_months and asset.asset_created_datetime:
            next_maintenance_date = _add_months(asset.asset_created_datetime, service_interval_months)
            maintenance_overdue = next_maintenance_date < now

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
        fault_count = session.exec(
            select(func.count(Faultcard.fault_id))
            .where(Faultcard.asset_id == asset.asset_id)
            .where(Faultcard.fault_reportdatetime >= twelve_months_ago)
        ).one() or 0

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
        # _model_available False and every survival field at its default, so the
        # rules-only pipeline above is unaffected. Feature extraction only runs
        # when a model is actually loaded (avoids per-asset queries otherwise).
        survival_fields = {}
        try:
            if survival_service.is_available():
                features = extract_asset_features(session, asset, datetime.utcnow())
                survival = survival_service.predict_for_asset(features)
                if survival:
                    survival_fields = survival
                    # predict_for_asset omits this flag; surface it explicitly.
                    survival_fields["survival_model_available"] = True
        except Exception:
            logger.exception(
                "Survival-voorspelling misluk vir bate %s — reëls-only.", asset.asset_id
            )

        if survival_fields.get("survival_high_risk") and survival_fields.get(
            "survival_failure_prob_12mo"
        ) is not None:
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

    def _last_maintenance(self, session: Session, asset_id: int) -> datetime | None:
        job = session.exec(
            select(Jobcard)
            .where(Jobcard.asset_id == asset_id)
            .where(Jobcard.job_type == "maintenance")
            .where(Jobcard.job_status == JobStatus.COMPLETED)
            .order_by(Jobcard.job_finisheddatetime.desc())
        ).first()
        if job and job.job_finisheddatetime:
            return job.job_finisheddatetime
        if job and job.job_createddatetime:
            return job.job_createddatetime
        return None


prediction_service = PredictionService()
