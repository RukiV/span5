"""Analytics page-handler tests (predictions / ai-drafts) + survival thresholds.

``generate_insights`` is called directly with the in-memory SQLite session from
conftest — no HTTP needed. The survival module state is reset so the
predictions test deterministically exercises the rules-only (model
unavailable) path regardless of what earlier tests left in memory.
"""

import importlib

from sqlmodel import Session, select

from app.auth.rights_catalog import ROLE_FK
from app.models.analytics import AnalyticsResponse
from app.models.asset import Asset, Assettype
from app.models.jobdraft import JobDraft
from app.models.user import User
from app.services import survival_service
from app.services.analytics_service import generate_insights


def _seed_assets(engine, total: int = 2) -> None:
    """Assettype + ``total`` assets so predictions have something to chew on."""
    with Session(engine) as session:
        assettype = Assettype(
            assettype_name="ToetsTipe",
            assettype_avg_lifespan=12,
            assettype_service_interval=3,
            assettype_replacement_threshold=3,
        )
        session.add(assettype)
        session.flush()
        for i in range(total):
            session.add(Asset(
                asset_name=f"Toetsbate-{i}",
                asset_brand="Toets",
                asset_serial=f"TB-{i}",
                assettype_id=assettype.assettype_id,
            ))
        session.commit()


# ---------------------------------------------------------------------------
# predictions page
# ---------------------------------------------------------------------------

def test_predictions_page_insights(engine, seeded, monkeypatch):
    # The survival model is never trained here; force the unavailable path so
    # the rules-only fallback is deterministic.
    monkeypatch.setattr(survival_service, "_model", None)
    monkeypatch.setattr(survival_service, "_model_available", False)
    _seed_assets(engine, total=2)

    with Session(engine) as session:
        resp = generate_insights("predictions", session)

    assert isinstance(resp, AnalyticsResponse)
    assert resp.summary  # non-empty
    assert "Totale Bates" in [m.label for m in resp.metrics]
    assert resp.chart is None
    # rules-only: the ML metric is hidden, insights mention the fallback.
    ml_metric = next(m for m in resp.metrics if m.label == "ML Hoë Risiko")
    assert ml_metric.value == "—"
    assert any("ML-survival-model verg" in i for i in resp.insights)


# ---------------------------------------------------------------------------
# ai-drafts page
# ---------------------------------------------------------------------------

def test_ai_drafts_page_insights(engine, seeded):
    with Session(engine) as session:
        fk_id = session.exec(select(User).where(User.role_id == ROLE_FK)).first().user_id
        session.add(JobDraft(description="Projektor flikker", user_id=fk_id, status="draft", source="auto"))
        session.add(JobDraft(description="Toilet oorloop", user_id=fk_id, status="approved", source="manual"))
        session.add(JobDraft(description="Deur vas", user_id=fk_id, status="rejected", source="manual"))
        session.commit()

    with Session(engine) as session:
        resp = generate_insights("ai-drafts", session)

    assert isinstance(resp, AnalyticsResponse)
    metrics = {m.label: m.value for m in resp.metrics}
    assert metrics["Wag op goedkeuring"] == "1"
    assert metrics["Goedgekeur"] == "1"
    assert metrics["Verwerp"] == "1"
    assert metrics["Outo-geskep"] == "1"
    assert "3 totaal" in resp.summary
    assert resp.chart is None
    assert any("wag vir FK/Admin-goedkeuring" in i for i in resp.insights)


# ---------------------------------------------------------------------------
# survival thresholds
# ---------------------------------------------------------------------------

def test_survival_min_env_override(monkeypatch):
    from app.services.survival_features import FEATURE_NAMES

    monkeypatch.setenv("AI_SURVIVAL_MIN_ASSETS", "5")
    monkeypatch.setenv("AI_SURVIVAL_MIN_EVENTS", "5")
    importlib.reload(survival_service)
    assert survival_service._min_assets == 5
    assert survival_service._min_events == 5

    monkeypatch.delenv("AI_SURVIVAL_MIN_ASSETS")
    monkeypatch.delenv("AI_SURVIVAL_MIN_EVENTS")
    importlib.reload(survival_service)
    assert survival_service._min_assets == 50
    assert survival_service._min_events == 10 * len(FEATURE_NAMES)
