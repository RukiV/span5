"""Survival model (Phase 2c) tests.

These run against the in-memory SQLite engine from conftest. The survival
module is pointed at a per-test tmp dir (never the real backend/data/) and its
module state is reset between tests, so no test depends on another's training.
``SURVIVAL_N_JOBS`` is pinned to 2 so the 300-tree forest trains in <2s on the
~110-row synthetic dataset.
"""

from datetime import datetime, timedelta

import pytest
from sqlmodel import Session, select

from app.models.asset import Asset, Assettype
from app.models.enums import FaultStatus, Priority
from app.models.fault import Faultcard
from app.models.prediction import AssetPredictionRead
from app.services import survival_service
from app.services.auto_draft_scheduler import _draft_signals
from app.services.prediction_service import prediction_service
from app.services.survival_features import (
    FEATURE_NAMES,
    build_training_set,
    extract_asset_features,
)


@pytest.fixture
def isolated_survival(tmp_path, monkeypatch):
    """Point the survival module at a temp dir and reset its module state.

    Without the reset, a model trained by one test would leak into the next
    (the module keeps ``_model`` in memory for the whole process). Without the
    tmp dir, ``maybe_train`` would write model/signature files into backend/data/.
    """
    monkeypatch.setenv("SURVIVAL_N_JOBS", "2")
    monkeypatch.setattr(survival_service, "MODEL_DIR", tmp_path)
    monkeypatch.setattr(survival_service, "MODEL_PATH", tmp_path / "survival_model.joblib")
    monkeypatch.setattr(survival_service, "SIGNATURE_PATH", tmp_path / "survival_signature.json")
    survival_service._model = None
    survival_service._model_available = False
    survival_service._model_events = 0
    survival_service._model_assets = 0
    survival_service._model_trained_at = None
    survival_service._trained_signature = None
    return survival_service


def _seed_basic_asset(engine) -> int:
    """One assettype + one recent asset, with no fault — the sparse case."""
    with Session(engine) as session:
        assettype = Assettype(
            assettype_name="ToetsTipe",
            assettype_avg_lifespan=12,
            assettype_service_interval=3,
            assettype_replacement_threshold=3,
        )
        session.add(assettype)
        session.flush()
        asset = Asset(
            asset_name="Toetsbate",
            asset_brand="Toets",
            asset_serial="TB-1",
            assettype_id=assettype.assettype_id,
            asset_created_datetime=datetime.utcnow() - timedelta(days=200),
        )
        session.add(asset)
        session.flush()
        session.commit()
        return asset.asset_id


def _seed_survival_dataset(engine, total: int = 110, events: int = 95):
    """Deterministic synthetic dataset: ``total`` assets across two assettypes
    (short vs long lifespan), the first ``events`` of them with a first fault at
    an assettype-dependent age, the rest censored (no fault)."""
    now = datetime.utcnow()
    with Session(engine) as session:
        type_short = Assettype(
            assettype_name="KortLewe", assettype_avg_lifespan=6, assettype_service_interval=1
        )
        type_long = Assettype(
            assettype_name="LangLewe", assettype_avg_lifespan=24, assettype_service_interval=3
        )
        session.add_all([type_short, type_long])
        session.flush()
        types = (type_short, type_long)

        for i in range(total):
            assettype = types[i % 2]
            created = now - timedelta(days=1100 - i * 8)  # ~3y .. ~8 months old
            asset = Asset(
                asset_name=f"ToetsBate-{i}",
                asset_brand="Toets",
                asset_serial=f"SRV-{i:04d}",
                assettype_id=assettype.assettype_id,
                asset_created_datetime=created,
            )
            session.add(asset)
            session.flush()
            if i < events:
                fault_age_days = 8 * 30 if assettype is type_short else 20 * 30
                fault_dt = created + timedelta(days=fault_age_days)
                if fault_dt > now:
                    fault_dt = now - timedelta(days=1)
                session.add(Faultcard(
                    fault_description=f"fout-{i}",
                    fault_status=FaultStatus.RESOLVED,
                    fault_priority=Priority.HIGH if i % 3 == 0 else Priority.MEDIUM,
                    fault_reportdatetime=fault_dt,
                    asset_id=asset.asset_id,
                ))
        session.commit()


def _seed_short_horizon_dataset(engine, total: int = 110, events: int = 95):
    """Synthetic dataset where EVERY first-fault time is well under 365 days.

    Same shape as ``_seed_survival_dataset`` (two assettypes, first ``events``
    assets fault, the rest censored) but the fault ages are 80..240 days. With
    the whole event domain below one year, ``surv(365)`` used to blow up the
    StepFunction domain check and silently null out every prediction — this
    dataset is what guards the horizon-clamping fix. The oldest censored assets
    (created ~364 days ago) sit past the ~240-day model horizon.
    """
    now = datetime.utcnow()
    with Session(engine) as session:
        type_short = Assettype(
            assettype_name="KortHorison", assettype_avg_lifespan=6, assettype_service_interval=1
        )
        type_long = Assettype(
            assettype_name="LangHorison", assettype_avg_lifespan=24, assettype_service_interval=3
        )
        session.add_all([type_short, type_long])
        session.flush()
        types = (type_short, type_long)

        for i in range(total):
            assettype = types[i % 2]
            created = now - timedelta(days=800 - i * 4)  # ~800d .. ~364d old
            asset = Asset(
                asset_name=f"ToetsKort-{i}",
                asset_brand="Toets",
                asset_serial=f"KRT-{i:04d}",
                assettype_id=assettype.assettype_id,
                asset_created_datetime=created,
            )
            session.add(asset)
            session.flush()
            if i < events:
                fault_age_days = 80 + (i % 5) * 40  # 80..240 days, always < 300
                session.add(Faultcard(
                    fault_description=f"kort-fout-{i}",
                    fault_status=FaultStatus.RESOLVED,
                    fault_priority=Priority.HIGH if i % 3 == 0 else Priority.MEDIUM,
                    fault_reportdatetime=created + timedelta(days=fault_age_days),
                    asset_id=asset.asset_id,
                ))
        session.commit()


# ---------------------------------------------------------------------------
# 1. sparse data keeps the layer disabled (rules-only)
# ---------------------------------------------------------------------------

def test_sparse_data_disables_model(engine, seeded, isolated_survival):
    asset_id = _seed_basic_asset(engine)

    survival_service.maybe_train(engine)
    assert survival_service.is_available() is False

    with Session(engine) as session:
        asset = session.get(Asset, asset_id)
        pred = prediction_service._predict(session, asset)

    # Existing prediction logic is fully intact...
    assert isinstance(pred, AssetPredictionRead)
    assert pred.asset_id == asset_id
    assert pred.asset_name == "Toetsbate"
    # ...and every survival field is at its default.
    assert pred.survival_model_available is False
    assert pred.survival_risk is None
    assert pred.survival_failure_prob_12mo is None
    assert pred.survival_median_days is None
    assert pred.survival_high_risk is False
    assert pred.survival_events_count is None
    assert pred.survival_trained_at is None
    assert pred.replacement_reason is None  # no ML clause sneaks in


# ---------------------------------------------------------------------------
# 2. enough synthetic data trains a usable model
# ---------------------------------------------------------------------------

def test_synthetic_training_enables_model(engine, seeded, isolated_survival):
    _seed_survival_dataset(engine, total=110, events=95)
    survival_service.maybe_train(engine)

    assert survival_service.is_available() is True
    status = survival_service.get_status()
    assert status["events"] >= 80
    assert status["assets"] >= 50
    assert status["trained_at"] is not None

    with Session(engine) as session:
        asset = session.exec(select(Asset).order_by(Asset.asset_id)).first()
        features = extract_asset_features(session, asset, datetime.utcnow())
        pred = prediction_service._predict(session, asset)

    result = survival_service.predict_for_asset(features)
    assert result is not None
    for key in (
        "survival_risk",
        "survival_failure_prob_12mo",
        "survival_median_days",
        "survival_high_risk",
        "survival_events_count",
        "survival_trained_at",
    ):
        assert key in result
    assert isinstance(result["survival_high_risk"], bool)
    assert isinstance(result["survival_failure_prob_12mo"], float)

    # The prediction endpoint path also carries the survival output.
    assert pred.survival_model_available is True
    assert pred.survival_failure_prob_12mo is not None
    assert pred.survival_risk is not None
    assert pred.survival_events_count == status["events"]


# ---------------------------------------------------------------------------
# 3. the signature gate prevents retraining on unchanged data
# ---------------------------------------------------------------------------

def test_signature_prevents_retrain(engine, seeded, isolated_survival):
    _seed_survival_dataset(engine, total=110, events=95)
    survival_service.maybe_train(engine)
    assert survival_service.is_available() is True
    first_trained_at = survival_service._model_trained_at

    # Second pass over identical data must no-op (signature matches).
    survival_service.maybe_train(engine)
    assert survival_service.is_available() is True
    assert survival_service._model_trained_at == first_trained_at


# ---------------------------------------------------------------------------
# 4. the ML signal feeds the auto-draft scheduler (pure unit test)
# ---------------------------------------------------------------------------

def test_survival_signal_in_draft_signals():
    risky = AssetPredictionRead(
        asset_id=1,
        asset_name="Bate",
        asset_serial="S-1",
        survival_high_risk=True,
        survival_failure_prob_12mo=0.72,
    )
    signals = _draft_signals(risky)
    assert "ML-risiko: 72% faalkans binne 12 maande" in signals

    calm = AssetPredictionRead(
        asset_id=2,
        asset_name="Bate2",
        asset_serial="S-2",
        survival_high_risk=False,
        survival_failure_prob_12mo=0.72,
    )
    assert not any("ML-risiko" in s for s in _draft_signals(calm))


# ---------------------------------------------------------------------------
# 5. predictions stay healthy when the model is disabled
# ---------------------------------------------------------------------------

def test_prediction_graceful_when_disabled(engine, seeded, isolated_survival):
    _seed_basic_asset(engine)
    with Session(engine) as session:
        preds = prediction_service.getPredictions(session)
        assert len(preds) >= 1
        for pred in preds:
            assert isinstance(pred, AssetPredictionRead)
            assert pred.survival_model_available is False
            assert pred.survival_risk is None


# ---------------------------------------------------------------------------
# 6. changed data triggers a refit (guards the load_model freshness check)
# ---------------------------------------------------------------------------

def test_changed_data_triggers_refit(engine, seeded, isolated_survival):
    _seed_survival_dataset(engine, total=110, events=95)
    survival_service.maybe_train(engine)
    assert survival_service.is_available() is True
    first_events = survival_service._model_events

    # Bump the data signature: a brand-new asset + a fresh fault. The in-memory
    # model is now stale, so maybe_train must notice and refit instead of
    # short-circuiting on the already-loaded model.
    with Session(engine) as session:
        assettype = session.exec(select(Assettype)).first()
        asset = Asset(
            asset_name="NuweBate",
            asset_brand="Toets",
            asset_serial="SRV-NUWE",
            assettype_id=assettype.assettype_id,
            asset_created_datetime=datetime.utcnow() - timedelta(days=30),
        )
        session.add(asset)
        session.flush()
        session.add(Faultcard(
            fault_description="nuwe fout",
            fault_status=FaultStatus.RESOLVED,
            fault_priority=Priority.MEDIUM,
            fault_reportdatetime=datetime.utcnow(),
            asset_id=asset.asset_id,
        ))
        session.commit()

    survival_service.maybe_train(engine)
    assert survival_service.is_available() is True
    assert survival_service._model_events > first_events
    assert (
        survival_service._trained_signature
        == survival_service._compute_data_signature(engine)
    )


# ---------------------------------------------------------------------------
# 7. a short-horizon model still predicts (guards horizon clamping)
# ---------------------------------------------------------------------------

def test_short_horizon_model_still_predicts(engine, seeded, isolated_survival):
    _seed_short_horizon_dataset(engine, total=110, events=95)
    survival_service.maybe_train(engine)
    assert survival_service.is_available() is True

    with Session(engine) as session:
        asset = session.exec(select(Asset).order_by(Asset.asset_id)).first()
        features = extract_asset_features(session, asset, datetime.utcnow())

    # Every observed event sits under 365 days, so the model domain max is well
    # below one year. Predicting must still work (no silent None) and the
    # clamped conditional probability must stay in [0, 1].
    result = survival_service.predict_for_asset(features)
    assert result is not None
    assert 0.0 <= result["survival_failure_prob_12mo"] <= 1.0


# ---------------------------------------------------------------------------
# 8. event-row features have no lookahead (guards the triggering-fault leak)
# ---------------------------------------------------------------------------

def test_no_lookahead_on_event_rows(engine, seeded, isolated_survival):
    _seed_survival_dataset(engine, total=110, events=95)

    with Session(engine) as session:
        X, y, ids, rows = build_training_set(session, datetime.utcnow())
        own_faults = session.exec(
            select(Faultcard).where(Faultcard.asset_id == ids[0])
        ).all()

    # ids[0] is the first seeded asset, which carries exactly one fault — the
    # very fault that triggers its event row. The event-row features are
    # computed one microsecond before that fault, so it must not leak in.
    assert len(own_faults) == 1
    assert bool(y["event"][0]) is True
    fault_col = FEATURE_NAMES.index("fault_count_12mo")
    assert float(X[0][fault_col]) == 0.0


# ---------------------------------------------------------------------------
# 9. an asset past the model horizon gets conservative (flat) risk
# ---------------------------------------------------------------------------

def test_old_survivor_gets_conservative_risk(engine, seeded, isolated_survival):
    _seed_short_horizon_dataset(engine, total=110, events=95)
    survival_service.maybe_train(engine)
    assert survival_service.is_available() is True

    # The newest seeded asset is censored (never faulted) and was created
    # ~364 days ago — far past the ~240-day model horizon. Its conditional
    # 12-month probability must stay within [0, 1] and, being already past
    # every observed failure, must not be flagged high-risk.
    with Session(engine) as session:
        asset = session.exec(select(Asset).order_by(Asset.asset_id.desc())).first()
        features = extract_asset_features(session, asset, datetime.utcnow())

    result = survival_service.predict_for_asset(features)
    assert result is not None
    assert 0.0 <= result["survival_failure_prob_12mo"] <= 1.0
    assert result["survival_high_risk"] is False
