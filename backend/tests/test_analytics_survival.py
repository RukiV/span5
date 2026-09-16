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
from app.services.llm_service import llm_service, LlmUnavailable


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


# ---------------------------------------------------------------------------
# weekly ops digest (AI_PLAN #2) — prose layer inside generate_insights
# ---------------------------------------------------------------------------


def test_weekly_ops_digest_llm_active(engine, seeded, monkeypatch):
    """When the LLM is available, digest is in its own field; summary stays rule-based."""
    monkeypatch.setattr(llm_service, "_enabled", lambda: True)
    monkeypatch.setattr(
        llm_service,
        "_generate",
        lambda system, prompt, schema, options=None: {
            "response": '{"digest": "Langtermyn-opsomming: alles loop glad nie."}'
        },
    )

    with Session(engine) as session:
        resp = generate_insights("dashboard", session)

    assert isinstance(resp, AnalyticsResponse)
    assert resp.digest == "Langtermyn-opsomming: alles loop glad nie."
    # summary stays rule-based (not replaced by digest); seeded: 1 WAIT-fout + 1 WAIT-werksopdrag
    assert resp.summary == "Oorsig van 0 bates, 1 onopgeloste foute, 1 aktiewe werksopdragte."
    # metrics/insights unchanged from rule-based computation
    assert [m.label for m in resp.metrics] == ["Totale Bates", "Onopgeloste Foute", "Aktiewe Werksopdragte", "Voorraaditems"]
    assert len(resp.insights) >= 1


def test_weekly_ops_digest_fallback_when_llm_down(engine, seeded, monkeypatch):
    """When the LLM is unavailable, digest is None and summary stays rule-based."""
    monkeypatch.setattr(
        llm_service,
        "_generate",
        lambda system, prompt, schema, options=None: (_ for _ in ()).throw(
            LlmUnavailable("ollama down")
        ),
    )

    with Session(engine) as session:
        resp = generate_insights("dashboard", session)

    assert isinstance(resp, AnalyticsResponse)
    assert resp.digest is None
    assert resp.summary  # non-empty rule summary
    assert any(m.label == "Totale Bates" for m in resp.metrics)
    assert "Oorsig van" in resp.summary or "bates" in resp.summary


def test_weekly_ops_digest_disabled_when_ai_off(engine, seeded, monkeypatch):
    """AI_ENABLED=false → digest is None, rule summary used."""
    monkeypatch.setattr(llm_service, "_enabled", lambda: False)

    with Session(engine) as session:
        resp = generate_insights("dashboard", session)

    assert isinstance(resp, AnalyticsResponse)
    assert resp.digest is None
    assert resp.summary  # non-empty rule summary
    assert "Oorsig van" in resp.summary or "bates" in resp.summary


def test_weekly_ops_digest_excludes_closed_and_completed(engine, seeded, monkeypatch):
    """"Onopgelos/Aktief" = alles behalwe Gesluit-foute en Voltooid/Gekanselleer-werksopdragte."""
    monkeypatch.setattr(llm_service, "_enabled", lambda: False)

    from app.models.enums import FaultStatus, JobStatus
    from app.models.fault import Faultcard
    from app.models.job import Jobcard

    with Session(engine) as session:
        # Nie-getel: Gesluit + Voltooid + Gekanselleer.
        session.add(Faultcard(
            fault_description="geslote fout",
            fault_status=FaultStatus.CLOSED,
            user_id=seeded["ids"]["student"],
        ))
        session.add(Jobcard(
            job_desc="voltooide werksopdrag",
            job_status=JobStatus.COMPLETED,
            contractor_id=seeded["ids"]["contractor"],
        ))
        session.add(Jobcard(
            job_desc="gekanselleerde werksopdrag",
            job_status=JobStatus.CANCELLED,
            contractor_id=seeded["ids"]["contractor"],
        ))
        session.commit()
        # Seeded bly 1 WAIT-fout + 1 WAIT-werksopdrag getel; bogenoemde is uitgesluit.
        resp = generate_insights("dashboard", session)

    assert resp.summary == "Oorsig van 0 bates, 1 onopgeloste foute, 1 aktiewe werksopdragte."
    # Status-afbreking in insigte sluit Gesluit/Voltooid/Gekanselleer uit.
    fault_insight = next(i for i in resp.insights if i.startswith("Onopgeloste foute per status"))
    assert "Gesluit" not in fault_insight
    job_insight = next(i for i in resp.insights if i.startswith("Aktiewe werksopdragte per status"))
    assert "Voltooid" not in job_insight and "Gekanselleer" not in job_insight
