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
            "response": '{"digest": ["Punt een", "Punt twee"]}'
        },
    )

    with Session(engine) as session:
        resp = generate_insights("dashboard", session)

    assert isinstance(resp, AnalyticsResponse)
    assert resp.digest == ["Punt een", "Punt twee"]
    # summary stays rule-based (not replaced by digest); seeded: 1 WAIT-fout + 1 WAIT-werksopdrag
    assert resp.summary == "Oorsig van 0 bates, 1 onopgeloste foute, 1 aktiewe werksopdragte."
    # metrics now include the four new KPIs alongside the originals
    metric_labels = [m.label for m in resp.metrics]
    for label in ("Totale Bates", "Onopgeloste Foute", "Aktiewe Werksopdragte", "Voorraaditems",
                   "Oop Foutkaartjies", "Hoë-prioriteit Foute", "Hoë-prioriteit Werksopdragte", "Gemma Auto-konsepte"):
        assert label in metric_labels, f"metric {label!r} missing"
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


# ---------------------------------------------------------------------------
# helpers: two-campus seed (reused by KPI + FK scoping tests)
# ---------------------------------------------------------------------------

from app.models.enums import FaultStatus, Priority, JobStatus, RoomStatus, RoomType
from app.models.fault import Faultcard
from app.models.job import Jobcard
from app.models.location import Building, Location, Room
from app.models.stock import Stock
from app.services.analytics_service import get_dashboard_summary


def _seed_two_campus(engine):
    """Create two campuses (A / B), each with a building, room, asset, stock.

    Returns a dict of integer IDs and names keyed for easy reference.
    """
    with Session(engine) as session:
        # Campus A ---------------------------------------------------------
        loc_a = Location(location_name="Kampus Noorde", location_type="campus",
                         location_streetnum="1", location_streetname="Noordweg")
        session.add(loc_a)
        session.flush()
        bldg_a = Building(building_name="Bloei A", location_id=loc_a.location_id)
        session.add(bldg_a)
        session.flush()
        room_a = Room(room_name="Kantooreenheid", room_code="KO-1",
                      room_type=RoomType.OFFICE, room_status=RoomStatus.OPERATIONAL,
                      building_id=bldg_a.building_id)
        session.add(room_a)
        session.flush()
        at = Assettype(assettype_name="ToetsTipe")
        session.add(at)
        session.flush()
        asset_a = Asset(asset_name="Projektor A", asset_brand="Epson",
                        asset_serial="PA-1", assettype_id=at.assettype_id,
                        room_id=room_a.room_id)
        session.add(asset_a)
        session.flush()
        stock_a = Stock(stock_name="Toner", stock_amount=3, stock_minimum=10,
                        stock_type="Verbruik", room_id=room_a.room_id)
        session.add(stock_a)

        # Campus B ---------------------------------------------------------
        loc_b = Location(location_name="Kampus Suide", location_type="campus",
                         location_streetnum="2", location_streetname="Suidpad")
        session.add(loc_b)
        session.flush()
        bldg_b = Building(building_name="Bloei B", location_id=loc_b.location_id)
        session.add(bldg_b)
        session.flush()
        room_b = Room(room_name="Leslokaal", room_code="LL-1",
                      room_type=RoomType.CLASSROOM, room_status=RoomStatus.OPERATIONAL,
                      building_id=bldg_b.building_id)
        session.add(room_b)
        session.flush()
        asset_b = Asset(asset_name="Beamer B", asset_brand="Dell",
                        asset_serial="BB-1", assettype_id=at.assettype_id,
                        room_id=room_b.room_id)
        session.add(asset_b)
        session.flush()
        stock_b = Stock(stock_name="Papier", stock_amount=20, stock_minimum=5,
                        stock_type="Verbruik", room_id=room_b.room_id)
        session.add(stock_b)

        session.commit()
        # Return detached-safe IDs (not ORM objects) to avoid DetachedInstanceError.
        return {
            "loc_a_id": loc_a.location_id, "loc_a_name": loc_a.location_name,
            "bldg_a_id": bldg_a.building_id,
            "room_a_id": room_a.room_id, "asset_a_id": asset_a.asset_id,
            "loc_b_id": loc_b.location_id, "loc_b_name": loc_b.location_name,
            "bldg_b_id": bldg_b.building_id,
            "room_b_id": room_b.room_id, "asset_b_id": asset_b.asset_id,
            "user_id_admin": session.exec(select(User).where(
                User.role_id == 3)).first().user_id,
            "user_id_fk": session.exec(select(User).where(
                User.role_id == 2)).first().user_id,
        }


# ---------------------------------------------------------------------------
# new dashboard KPIs correctness (admin = unscoped)
# ---------------------------------------------------------------------------


def test_new_dashboard_kpis_correctness(engine, seeded, monkeypatch):
    """The four new KPIs (open_faults, high_priority_faults, high_priority_jobs,
    auto_drafts) return correct counts for an admin (unscoped) view."""
    from app.models.jobdraft import JobDraft
    from app.services.analytics_service import get_dashboard_summary

    locs = _seed_two_campus(engine)

    with Session(engine) as session:
        # --- Faults -------------------------------------------------------
        # Seeded fixture already has 1 WAIT/MEDIUM fault (user=student).
        # Add: 2 open + high, 1 open + normal, 1 closed + high.
        session.add(Faultcard(
            fault_description="oop hoog A",
            fault_status=FaultStatus.OPEN,
            fault_priority=Priority.HIGH,
            location_id=locs["loc_a_id"],
            building_id=locs["bldg_a_id"],
            room_id=locs["room_a_id"],
            user_id=locs["user_id_admin"],
        ))
        session.add(Faultcard(
            fault_description="oop hoog B",
            fault_status=FaultStatus.OPEN,
            fault_priority=Priority.HIGH,
            location_id=locs["loc_b_id"],
            building_id=locs["bldg_b_id"],
            room_id=locs["room_b_id"],
            user_id=locs["user_id_admin"],
        ))
        session.add(Faultcard(
            fault_description="oop normaal",
            fault_status=FaultStatus.OPEN,
            fault_priority=Priority.MEDIUM,
            user_id=locs["user_id_admin"],
        ))
        session.add(Faultcard(
            fault_description="gesluit hoog",
            fault_status=FaultStatus.CLOSED,
            fault_priority=Priority.HIGH,
            user_id=locs["user_id_admin"],
        ))

        # --- Jobs ---------------------------------------------------------
        # Seeded: 1 WAIT/Normal job (contractor). Add: 2 high-priority active, 1 completed + high.
        session.add(Jobcard(
            job_desc="werk dringend A",
            job_status=JobStatus.WAIT,
            job_priority="Dringend",
            room_id=locs["room_a_id"],
            building_id=locs["bldg_a_id"],
            contractor_id=locs["user_id_admin"],
        ))
        session.add(Jobcard(
            job_desc="werk hoog B",
            job_status=JobStatus.OPEN,
            job_priority="Hoog",
            room_id=locs["room_b_id"],
            building_id=locs["bldg_b_id"],
            contractor_id=locs["user_id_admin"],
        ))
        session.add(Jobcard(
            job_desc="werk voltooid",
            job_status=JobStatus.COMPLETED,
            job_priority="Hoog",
            contractor_id=locs["user_id_admin"],
        ))

        # --- Drafts -------------------------------------------------------
        session.add(JobDraft(
            description="auto konsep A",
            user_id=locs["user_id_fk"],
            status="draft",
            source="auto",
            resolved_asset_id=locs["asset_a_id"],
            resolved_room_id=locs["room_a_id"],
        ))
        session.add(JobDraft(
            description="auto konsep B",
            user_id=locs["user_id_fk"],
            status="draft",
            source="auto",
            resolved_asset_id=locs["asset_b_id"],
            resolved_room_id=locs["room_b_id"],
        ))
        session.add(JobDraft(
            description="manual konsep",
            user_id=locs["user_id_fk"],
            status="draft",
            source="manual",
        ))
        session.commit()

    with Session(engine) as session:
        # Admin (no user → unscoped)
        result = get_dashboard_summary(session)

    kpis = result["kpis"]

    # open_faults: 1 seeded WAIT + 3 OPEN = 4  (CLOSED excluded)
    assert kpis["open_faults"] == 4
    # high_priority_faults: 2 OPEN + HIGH  (CLOSED excluded)
    assert kpis["high_priority_faults"] == 2
    # high_priority_jobs: seeded WAIT/Normal + dringend + hoog = 2 (completed excluded)
    assert kpis["high_priority_jobs"] == 2
    # auto_drafts: 2 auto, unscoped
    assert kpis["auto_drafts"] == 2


# ---------------------------------------------------------------------------
# FK scoping: campus-A user sees only campus-A counts
# ---------------------------------------------------------------------------


def test_dashboard_kpis_fk_scoping(engine, seeded, monkeypatch):
    """FK user scoped to campus A sees only campus-A records; admin sees all."""
    from app.models.jobdraft import JobDraft
    from app.services.analytics_service import get_dashboard_summary

    locs = _seed_two_campus(engine)

    # Set FK user's location_id to campus A.
    with Session(engine) as session:
        fk_user = session.get(User, locs["user_id_fk"])
        fk_user.location_id = locs["loc_a_id"]
        session.add(fk_user)
        session.commit()

    with Session(engine) as session:
        # Faults: 1 in A (open+high), 1 in B (open+high), 1 no-location (open+normal).
        session.add(Faultcard(
            fault_description="oop hoog A",
            fault_status=FaultStatus.OPEN,
            fault_priority=Priority.HIGH,
            location_id=locs["loc_a_id"],
            building_id=locs["bldg_a_id"],
            room_id=locs["room_a_id"],
            user_id=locs["user_id_admin"],
        ))
        session.add(Faultcard(
            fault_description="oop hoog B",
            fault_status=FaultStatus.OPEN,
            fault_priority=Priority.HIGH,
            location_id=locs["loc_b_id"],
            building_id=locs["bldg_b_id"],
            room_id=locs["room_b_id"],
            user_id=locs["user_id_admin"],
        ))
        session.add(Faultcard(
            fault_description="oop normaal",
            fault_status=FaultStatus.OPEN,
            fault_priority=Priority.MEDIUM,
            user_id=locs["user_id_admin"],
        ))

        # Jobs: 1 in A (high), 1 in B (high).
        session.add(Jobcard(
            job_desc="werk dringend A",
            job_status=JobStatus.WAIT,
            job_priority="Dringend",
            room_id=locs["room_a_id"],
            building_id=locs["bldg_a_id"],
            contractor_id=locs["user_id_admin"],
        ))
        session.add(Jobcard(
            job_desc="werk hoog B",
            job_status=JobStatus.WAIT,
            job_priority="Hoog",
            room_id=locs["room_b_id"],
            building_id=locs["bldg_b_id"],
            contractor_id=locs["user_id_admin"],
        ))

        # Drafts: 1 auto in A, 1 auto in B.
        session.add(JobDraft(
            description="auto konsep A",
            user_id=locs["user_id_fk"],
            status="draft",
            source="auto",
            resolved_asset_id=locs["asset_a_id"],
            resolved_room_id=locs["room_a_id"],
        ))
        session.add(JobDraft(
            description="auto konsep B",
            user_id=locs["user_id_fk"],
            status="draft",
            source="auto",
            resolved_asset_id=locs["asset_b_id"],
            resolved_room_id=locs["room_b_id"],
        ))
        session.commit()

    with Session(engine) as session:
        fk_user = session.get(User, locs["user_id_fk"])
        # --- FK user on campus A ---
        fk_result = get_dashboard_summary(session, user=fk_user)
        fk_kpis = fk_result["kpis"]

        # seeded WAIT fault has no location → not in FK scope; only fA is open.
        assert fk_kpis["open_faults"] == 1, f"FK open_faults expected 1, got {fk_kpis['open_faults']}"
        assert fk_kpis["high_priority_faults"] == 1
        assert fk_kpis["high_priority_jobs"] == 1
        assert fk_kpis["auto_drafts"] == 1
        assert fk_result["location_name"] == "Kampus Noorde"

        # --- Admin (unscoped) ---
        admin_result = get_dashboard_summary(session)
        admin_kpis = admin_result["kpis"]

        # seeded WAIT + fA + fB + fC = 4 open faults
        assert admin_kpis["open_faults"] == 4
        assert admin_kpis["high_priority_faults"] == 2
        # seeded WAIT job (Normal) + jA + jB = 2 high (jA Dringend + jB Hoog)
        assert admin_kpis["high_priority_jobs"] == 2
        assert admin_kpis["auto_drafts"] == 2
        assert admin_result["location_name"] is None


# ---------------------------------------------------------------------------
# generate_insights user-threading: dashboard context + FK scoping
# ---------------------------------------------------------------------------


def test_dashboard_insights_fk_scoping(engine, seeded, monkeypatch):
    """generate_insights('dashboard') returns FK-scoped context + location_name
    when called with an FK user; admin context is unscoped."""
    from app.models.jobdraft import JobDraft
    from app.services.analytics_service import _gather_context

    locs = _seed_two_campus(engine)

    # Set FK user's location_id to campus A.
    with Session(engine) as session:
        fk_user = session.get(User, locs["user_id_fk"])
        fk_user.location_id = locs["loc_a_id"]
        session.add(fk_user)
        session.commit()

    with Session(engine) as session:
        # Faults: 1 in A (open), 1 in B (open).
        session.add(Faultcard(
            fault_description="foute A",
            fault_status=FaultStatus.OPEN,
            fault_priority=Priority.HIGH,
            location_id=locs["loc_a_id"],
            room_id=locs["room_a_id"],
            user_id=locs["user_id_admin"],
        ))
        session.add(Faultcard(
            fault_description="foute B",
            fault_status=FaultStatus.OPEN,
            fault_priority=Priority.HIGH,
            location_id=locs["loc_b_id"],
            room_id=locs["room_b_id"],
            user_id=locs["user_id_admin"],
        ))

        # Jobs: 1 high in A, 1 in B.
        session.add(Jobcard(
            job_desc="werk A",
            job_status=JobStatus.WAIT,
            job_priority="Dringend",
            room_id=locs["room_a_id"],
            contractor_id=locs["user_id_admin"],
        ))
        session.add(Jobcard(
            job_desc="werk B",
            job_status=JobStatus.WAIT,
            job_priority="Normal",
            room_id=locs["room_b_id"],
            contractor_id=locs["user_id_admin"],
        ))

        # Drafts: 1 auto in A, 1 auto in B.
        session.add(JobDraft(description="auto A", user_id=locs["user_id_fk"],
                             status="draft", source="auto",
                             resolved_asset_id=locs["asset_a_id"],
                             resolved_room_id=locs["room_a_id"]))
        session.add(JobDraft(description="auto B", user_id=locs["user_id_fk"],
                             status="draft", source="auto",
                             resolved_asset_id=locs["asset_b_id"],
                             resolved_room_id=locs["room_b_id"]))
        session.commit()

    with Session(engine) as session:
        fk_user = session.get(User, locs["user_id_fk"])

        # --- FK user: campus-A scoped ---
        ctx_fk = _gather_context("dashboard", session, user=fk_user)
        assert ctx_fk["is_fk_scoped"] is True
        assert ctx_fk["location_name"] == "Kampus Noorde"
        assert ctx_fk["open_faults"] == 1
        assert ctx_fk["high_priority_faults"] == 1
        assert ctx_fk["high_priority_jobs"] == 1
        assert ctx_fk["auto_drafts"] == 1

        # --- Admin: unscoped ---
        ctx_admin = _gather_context("dashboard", session)
        assert ctx_admin["is_fk_scoped"] is False
        assert ctx_admin["location_name"] == ""
        # open_faults: seeded WAIT + fA + fB = 3
        assert ctx_admin["open_faults"] == 3
        assert ctx_admin["high_priority_faults"] == 2
        # high_priority_jobs: seeded WAIT/Normal + jA(Dringend) = 1
        assert ctx_admin["high_priority_jobs"] == 1
        assert ctx_admin["auto_drafts"] == 2


def test_dashboard_insights_fk_summary_includes_kampus_name(engine, seeded, monkeypatch):
    """When the summary is generated for an FK user, the location name
    appears in the summary prefix (e.g. 'Oorsig vir Kampus Noorde: ...')."""
    locs = _seed_two_campus(engine)

    with Session(engine) as session:
        fk_user = session.get(User, locs["user_id_fk"])
        fk_user.location_id = locs["loc_a_id"]
        session.add(fk_user)
        session.commit()

    with Session(engine) as session:
        fk_user = session.get(User, locs["user_id_fk"])
        resp = generate_insights("dashboard", session, user=fk_user)
        assert "Kampus Noorde" in resp.summary
        assert "Oorsig vir" in resp.summary

        # Admin summary has no location prefix.
        resp_admin = generate_insights("dashboard", session)
        assert "Kampus Noorde" not in resp_admin.summary
        assert "Oorsig van" in resp_admin.summary


# ---------------------------------------------------------------------------
# ops dashboard context: overdue jobs / critical stock / maintenance overdue
# ---------------------------------------------------------------------------


def test_dashboard_context_includes_overdue_critical_maintenance(engine, seeded, monkeypatch):
    """_gather_context('dashboard') exposes overdue_jobs, critical_stock and
    maintenance_overdue for the weekly ops digest — admin (unscoped) view."""
    import types
    from datetime import datetime, timedelta

    from app.models.enums import FaultStatus, JobStatus, RoomStatus, RoomType
    from app.models.fault import Faultcard
    from app.models.job import Jobcard
    from app.models.location import Building, Location, Room
    from app.models.stock import Stock
    from app.services.analytics_service import _gather_context
    from app.services.prediction_service import PredictionService

    now = datetime.now()

    with Session(engine) as session:
        admin = session.exec(select(User).where(User.role_id == 3)).first()

        # Enkele terrein/gebou/kamer/bate (bate vir die maintenance-voorspelling).
        loc = Location(location_name="Kampus Toets", location_type="campus",
                       location_streetnum="1", location_streetname="Testweg")
        session.add(loc)
        session.flush()
        bldg = Building(building_name="Gebou T", location_id=loc.location_id)
        session.add(bldg)
        session.flush()
        room = Room(room_name="Lokaal T", room_code="LT-1",
                    room_type=RoomType.OFFICE, room_status=RoomStatus.OPERATIONAL,
                    building_id=bldg.building_id)
        session.add(room)
        session.flush()
        at = Assettype(assettype_name="ToetsTipe")
        session.add(at)
        session.flush()
        asset = Asset(asset_name="Bate T", asset_brand="Toets",
                      asset_serial="BT-1", assettype_id=at.assettype_id,
                      room_id=room.room_id)
        session.add(asset)
        session.flush()

        # 2 foute: 1 oop, 1 gesluit.
        session.add(Faultcard(
            fault_description="oop fout",
            fault_status=FaultStatus.OPEN,
            user_id=admin.user_id,
        ))
        session.add(Faultcard(
            fault_description="geslote fout",
            fault_status=FaultStatus.CLOSED,
            user_id=admin.user_id,
        ))

        # 3 werksopdragte: 1 oortydig (verby + Besig), 1 op skedule (toekoms),
        # 1 voltooid (uitgesluit al is die einddatum verby).
        session.add(Jobcard(
            job_desc="oortydige werk",
            job_status=JobStatus.IN_PROGRESS,
            job_scheduled_end_datetime=now - timedelta(days=2),
            room_id=room.room_id,
            contractor_id=admin.user_id,
        ))
        session.add(Jobcard(
            job_desc="op skedule werk",
            job_status=JobStatus.SCHEDULED,
            job_scheduled_end_datetime=now + timedelta(days=2),
            room_id=room.room_id,
            contractor_id=admin.user_id,
        ))
        session.add(Jobcard(
            job_desc="voltooide werk",
            job_status=JobStatus.COMPLETED,
            job_scheduled_end_datetime=now - timedelta(days=2),
            room_id=room.room_id,
            contractor_id=admin.user_id,
        ))

        # 2 voorraaditems: 1 onder minimum, 1 bo.
        session.add(Stock(
            stock_name="Krities Laag",
            stock_amount=2,
            stock_minimum=10,
            stock_type="Verbruik",
            room_id=room.room_id,
        ))
        session.add(Stock(
            stock_name="Genoeg Voorraad",
            stock_amount=20,
            stock_minimum=5,
            stock_type="Verbruik",
            room_id=room.room_id,
        ))
        session.commit()
        asset_id = asset.asset_id

    # Mock voorspellings: een in-scope bate agterstallig, een onbekende bate
    # (nie in asset_map nie → uitgesluit).
    def _fake_predictions(self, session_):
        return [
            types.SimpleNamespace(asset_id=asset_id, maintenance_overdue=True),
            types.SimpleNamespace(asset_id=999999, maintenance_overdue=True),
        ]

    monkeypatch.setattr(PredictionService, "getPredictions", _fake_predictions)

    with Session(engine) as session:
        ctx = _gather_context("dashboard", session)

    assert ctx["overdue_jobs"] == 1
    assert ctx["critical_stock_count"] == 1
    assert ctx["maintenance_overdue"] == 1
