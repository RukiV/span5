"""Survival-analysis service for asset-failure prediction (Phase 2c).

Trains a RandomSurvivalForest on time-to-first-fault data and serves per-asset
risk / 12-month failure-probability predictions. The module degrades
gracefully: if scikit-survival is unavailable — or the data is too sparse — the
app keeps serving the rules-only predictions from ``prediction_service`` and
every survival field stays at its None/False default.

The fitted forest is read-only after ``fit``, so concurrent ``predict`` calls
are thread-safe — which is what the background retrain loop relies on when it
runs training via ``asyncio.to_thread`` while request handlers predict at the
same time.
"""

import asyncio
import json
import logging
import os
from datetime import datetime
from pathlib import Path

import joblib
import numpy as np
from sqlmodel import Session, func, select

from ..models.asset import Asset
from ..models.fault import Faultcard
from ..models.job import Jobcard
from .survival_features import FEATURE_NAMES, build_training_set

logger = logging.getLogger(__name__)

# scikit-survival is optional: without it the app boots and serves rules-only.
# Any import failure (missing wheel, native-lib clash) must not crash startup.
try:
    from sksurv.ensemble import RandomSurvivalForest

    _SK_SURV_OK = True
except Exception:  # pragma: no cover — only exercised when sksurv is absent
    RandomSurvivalForest = None
    _SK_SURV_OK = False

# ---------------------------------------------------------------------------
# Module state & paths
# ---------------------------------------------------------------------------

#: backend/data/ — model + companion signature persist across restarts.
MODEL_DIR = Path(__file__).resolve().parent.parent.parent / "data"
MODEL_PATH = MODEL_DIR / "survival_model.joblib"
SIGNATURE_PATH = MODEL_DIR / "survival_signature.json"

try:
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
except Exception:
    logger.exception("Survival-modelgids kan nie geskep word nie: %s", MODEL_DIR)

#: Master switch: set AI_SURVIVAL_ENABLED=false|0|no to run rules-only.
_enabled = os.getenv("AI_SURVIVAL_ENABLED", "true").lower() not in ("false", "0", "no")
_retrain_interval = int(os.getenv("SURVIVAL_RETRAIN_INTERVAL", "900"))

_model = None
_model_available = False
_model_events = 0
_model_assets = 0
_model_trained_at: datetime | None = None
_trained_signature: dict | None = None

#: Minimums before the model may be trained (guards against noise fits).
#: Env-overridable so dev can lower them to demo on small datasets.
_min_assets = int(os.getenv("AI_SURVIVAL_MIN_ASSETS", "50"))
_min_events = int(os.getenv("AI_SURVIVAL_MIN_EVENTS", str(10 * len(FEATURE_NAMES))))  # 8 features -> 80 events
#: 12-maand-faalkans waarbo 'n bate as hoë risiko gemerk word. 0.5 was te
#: gul op 'n event-ryke opleidingsstel — konfigureerbaar gemaak.
_high_risk_threshold = float(os.getenv("AI_SURVIVAL_HIGH_RISK", "0.65"))


# ---------------------------------------------------------------------------
# Public status helpers
# ---------------------------------------------------------------------------

def is_enabled() -> bool:
    """Whether the survival layer is switched on at all."""
    return _enabled


def set_enabled(value: bool) -> None:
    """Runtime toggle (admin-knoppie). Oorheers die AI_SURVIVAL_ENABLED-env
    vir hierdie proses; nuwe prosesse lees weer die env."""
    global _enabled
    _enabled = bool(value)


def is_available() -> bool:
    """Whether a trained model is loaded and predictions can be served."""
    return bool(_model_available and _model is not None)


def get_status() -> dict:
    """Diagnostic status for the survival layer."""
    return {
        "available": is_available(),
        "enabled": _enabled,
        "model_available": _model_available,
        "events": _model_events,
        "assets": _model_assets,
        "trained_at": _model_trained_at.isoformat() if _model_trained_at else None,
        "min_assets": _min_assets,
        "min_events": _min_events,
    }


# ---------------------------------------------------------------------------
# Training
# ---------------------------------------------------------------------------

def force_retrain(engine) -> dict:
    """Forceer 'n her-opleiding, selfs as die data-handtekening onveranderd is
    (bv. ná 'n kenmerk-logika-regstelling). Gee die nuwe status terug."""
    global _trained_signature, _model_available
    _trained_signature = None
    _clear_model_state()
    maybe_train(engine)
    return get_status()


def _compute_data_signature(engine) -> dict:
    """Coarse fingerprint of the training data: asset count + latest fault/job.

    Two aggregate values plus the row count are enough to detect "data changed
    since the last fit"; MAX timestamps catch new faults/jobs while COUNT
    catches new assets. Stored as a JSON next to the model.
    """
    with Session(engine) as session:
        assets = session.exec(select(func.count(Asset.asset_id))).one()
        fault_max = session.exec(
            select(func.coalesce(func.max(Faultcard.fault_reportdatetime), datetime.min))
        ).one()
        job_max = session.exec(
            select(func.coalesce(func.max(Jobcard.job_finisheddatetime), datetime.min))
        ).one()
    return {
        "assets": int(assets),
        "fault_max": str(fault_max),
        "job_max": str(job_max),
    }


def _write_signature(signature: dict) -> None:
    """Persist the signature so a restart can tell the model is stale/fresh."""
    try:
        SIGNATURE_PATH.write_text(json.dumps(signature), encoding="utf-8")
    except Exception:
        logger.exception("Survival-handtekening kan nie geskryf word nie.")


def _clear_model_state() -> None:
    """Drop the in-memory model; prediction degrades to rules-only."""
    global _model, _model_available, _model_events, _model_assets, _model_trained_at
    _model = None
    _model_available = False
    _model_events = 0
    _model_assets = 0
    _model_trained_at = None


def load_model(engine=None) -> bool:
    """Load a previously trained model from disk if it is still fresh.

    A model file is only usable when its companion signature matches the
    current DB signature (data unchanged since training); a stale file is
    ignored and the module stays rules-only until ``maybe_train`` refits.
    Returns True when a usable model is now in memory (or was already).
    """
    global _model, _model_available, _model_events, _model_assets, _model_trained_at, _trained_signature

    if _model_available and _model is not None:
        if engine is None:
            from ..db.database import engine as database_engine

            engine = database_engine
        if _trained_signature == _compute_data_signature(engine):
            return True
        # stale in-memory model: report False so maybe_train refits
        return False
    if not _SK_SURV_OK:
        return False
    try:
        if not MODEL_PATH.exists() or not SIGNATURE_PATH.exists():
            return False
        if engine is None:
            from ..db.database import engine as database_engine

            engine = database_engine
        saved = json.loads(SIGNATURE_PATH.read_text(encoding="utf-8"))
        if saved != _compute_data_signature(engine):
            return False  # stale: the DB moved on since the last fit
        model = joblib.load(MODEL_PATH)
        _model = model
        _model_available = True
        _model_events = int(getattr(model, "_fbs_events", 0))
        _model_assets = int(getattr(model, "_fbs_assets", 0))
        _model_trained_at = getattr(model, "_fbs_trained_at", None)
        _trained_signature = saved
        logger.info("Survival-model gelaai vanaf %s.", MODEL_PATH)
        return True
    except Exception:
        logger.exception("Survival-model laai misluk — reëls-only.")
        return False


def maybe_train(engine) -> None:
    """(Re)train the survival model when the data changed and is sufficient.

    Signature-gated: when the DB fingerprint is unchanged since the last
    evaluation (whether that ended in a fit or a sparse-data disable) we no-op,
    so a quiet database does not rebuild the training set every interval.
    Sparse data (fewer than ``_min_assets`` assets or ``_min_events`` events)
    clears the model and records the signature anyway — the layer stays
    rules-only, but the next pass after real data arrives is cheap.
    """
    global _model, _model_available, _model_events, _model_assets, _model_trained_at, _trained_signature

    if not _enabled:
        return

    try:
        signature = _compute_data_signature(engine)
        if signature == _trained_signature:
            # Nothing changed since the last evaluation — whether the model is
            # loaded (fresh) or disabled (too sparse). Skip the rebuild.
            return

        if load_model(engine):
            return  # a fresh model already exists on disk for this exact DB state

        with Session(engine) as session:
            X, y, _asset_ids, _rows = build_training_set(session, datetime.utcnow())

        assets = signature["assets"]
        events = int(y["event"].sum())

        if not _SK_SURV_OK or assets < _min_assets or events < _min_events:
            _clear_model_state()
            _trained_signature = signature
            _write_signature(signature)
            logger.info(
                "Survival-model: onvoldoende data (%s bates, %s gebeurtenisse; minimum %s/%s) — reëls-only.",
                assets,
                events,
                _min_assets,
                _min_events,
            )
            return

        n_jobs = int(os.getenv("SURVIVAL_N_JOBS", "-1"))
        rsf = RandomSurvivalForest(
            n_estimators=300,
            min_samples_split=10,
            min_samples_leaf=15,
            max_features="sqrt",
            n_jobs=n_jobs,
            random_state=42,
        )
        rsf.fit(X, y)

        # Metadata survives joblib.dump so load_model can restore the status.
        rsf._fbs_events = events
        rsf._fbs_assets = assets
        rsf._fbs_trained_at = datetime.utcnow()

        _model = rsf
        _model_available = True
        _model_events = events
        _model_assets = assets
        _model_trained_at = rsf._fbs_trained_at
        _trained_signature = signature

        try:
            joblib.dump(rsf, MODEL_PATH)
        except Exception:
            logger.exception(
                "Survival-model kan nie na skyf gestoor word nie — in-memory steeds aktief."
            )
        _write_signature(signature)
        logger.info(
            "Survival-model opgelei: %s bates, %s gebeurtenisse -> %s",
            assets,
            events,
            MODEL_PATH,
        )
    except Exception:
        logger.exception("Survival-model opleiding misluk — reëls-only.")


# ---------------------------------------------------------------------------
# Prediction
# ---------------------------------------------------------------------------

def predict_for_asset(features: dict) -> dict | None:
    """Survival predictions for one asset given its extracted feature dict.

    Returns None when the model is unavailable or disabled. Otherwise returns
    the keys consumed by ``AssetPredictionRead``:
    survival_risk, survival_failure_prob_12mo, survival_median_days,
    survival_high_risk, survival_events_count, survival_trained_at.
    """
    if not _enabled or not _model_available or _model is None:
        return None
    try:
        X_new = np.array([[features[name] for name in FEATURE_NAMES]], dtype=float)
        risk = float(_model.predict(X_new)[0])
        surv = _model.predict_survival_function(X_new, return_array=False)[0]
        age = float(features.get("age_days", 0.0))
        horizon = float(surv.domain[1])  # model's max observed time
        s0 = float(surv(min(age, horizon)))
        if s0 <= 1e-9:
            # Buite die model se waargenome tydvenster: geen betroubare skatting
            # nie — rapporteer 0 i.p.v. deling-deur-nul-artefakte.
            failure_prob_12mo = 0.0
        else:
            s1 = float(surv(min(age + 365.0, horizon)))
            failure_prob_12mo = min(1.0, max(0.0, (s0 - s1) / s0))
        median_idx = np.flatnonzero(surv.y <= 0.5)
        median = float(surv.x[median_idx[0]]) if median_idx.size else None
        return {
            "survival_risk": risk,
            "survival_failure_prob_12mo": failure_prob_12mo,
            "survival_median_days": median,
            "survival_high_risk": bool(failure_prob_12mo >= _high_risk_threshold),
            "survival_events_count": _model_events,
            "survival_trained_at": _model_trained_at,
        }
    except Exception:
        logger.exception("Survival-voorspelling misluk — reëls-only.")
        return None


# ---------------------------------------------------------------------------
# Background retrain loop (mirrors reminder_scheduler / auto_draft_scheduler)
# ---------------------------------------------------------------------------

async def maybe_retrain_loop():
    """Retrain the survival model every ``SURVIVAL_RETRAIN_INTERVAL`` seconds.

    Training is synchronous and potentially slow, so it runs in a worker thread
    via ``asyncio.to_thread`` to keep the event loop responsive. The engine is
    imported lazily to avoid an import cycle at module load. A bad pass is
    logged and swallowed — the loop never kills the app.
    """
    while True:
        try:
            from ..db.database import engine as database_engine

            await asyncio.to_thread(maybe_train, database_engine)
        except Exception as e:
            logger.error(f"Survival-herleer-loop fout: {e}")
        await asyncio.sleep(_retrain_interval)
