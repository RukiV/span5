"""Auto-draft scheduler (Phase 2a) tests.

The scan runs against the in-memory engine directly via
``scan_and_create_auto_drafts(engine=engine)`` — no HTTP is needed for most
tests. ``llm_service.extract`` is monkeypatched to raise so the degraded path is
deterministic (the LLM is never available in the test environment).
"""

from datetime import datetime, timedelta

from sqlmodel import Session, select

from app.models.asset import Asset, Assettype
from app.models.enums import FaultStatus
from app.models.fault import Faultcard
from app.models.faultdraft import FaultDraft
from app.models.user import User
from app.services.auto_draft_scheduler import scan_and_create_auto_drafts
from app.services.llm_service import LlmUnavailable, llm_service

API = "/api/v1/ai"


def _llm_down(monkeypatch):
    """Force the degraded path: LLM always unavailable."""
    monkeypatch.setattr(llm_service, "extract",
                        lambda desc: (_ for _ in ()).throw(LlmUnavailable("down")))


def _seed_signal_asset(engine) -> int:
    """Assettype (6-month lifespan) + a 2-year-old asset + 3 resolved faults in
    the last 12 months — both the lifespan-exceeded and fault-count signals fire.
    Returns the asset id.
    """
    with Session(engine) as session:
        at = Assettype(assettype_name="Lugversorger", assettype_avg_lifespan=6)
        session.add(at)
        session.flush()
        asset = Asset(
            asset_name="Waaler",
            asset_brand="Test",
            asset_serial="W-1",
            assettype_id=at.assettype_id,
            asset_created_datetime=datetime.utcnow() - timedelta(days=730),
        )
        session.add(asset)
        session.flush()
        for i, desc in enumerate(("vibreer", "geraas", "lek"), start=1):
            session.add(Faultcard(
                fault_description=desc,
                fault_status=FaultStatus.RESOLVED,
                fault_reportdatetime=datetime.utcnow() - timedelta(days=i * 30),
                asset_id=asset.asset_id,
            ))
        session.commit()
        return asset.asset_id


def _fk_user_id(engine) -> int:
    from app.auth.rights_catalog import ROLE_FK
    with Session(engine) as session:
        return session.exec(select(User).where(User.role_id == ROLE_FK)).first().user_id


def _drafts(engine) -> list:
    with Session(engine) as session:
        return session.exec(select(FaultDraft)).all()


# ---------------------------------------------------------------------------
# scanning
# ---------------------------------------------------------------------------

def test_scan_creates_auto_draft(engine, seeded, monkeypatch):
    _llm_down(monkeypatch)
    asset_id = _seed_signal_asset(engine)

    created = scan_and_create_auto_drafts(engine=engine)
    assert len(created) == 1

    with Session(engine) as session:
        draft = session.get(FaultDraft, created[0])
        assert draft is not None
        assert draft.source == "auto"
        assert draft.status == "draft"
        assert draft.resolved_asset_id == asset_id
        assert draft.suggested_type in {"REPAIR", "MAINTENANCE", "INSPECTION", "INSTALLATION"}
        assert draft.suggested_priority in {"LOW", "MEDIUM", "HIGH"}
        assert draft.ai_status == "degraded"          # LLM monkeypatched to raise
        assert draft.failure_category == "predictive"
        assert draft.language == "af"
        assert draft.user_id == _fk_user_id(engine)    # operator = FK user
        assert "Waaler" in draft.description


def test_scan_is_idempotent(engine, seeded, monkeypatch):
    _llm_down(monkeypatch)
    _seed_signal_asset(engine)

    first = scan_and_create_auto_drafts(engine=engine)
    second = scan_and_create_auto_drafts(engine=engine)

    assert len(first) == 1
    assert len(second) == 0          # second pass dedups via the existing draft
    assert len(_drafts(engine)) == 1


def test_scan_skips_asset_with_open_fault(engine, seeded, monkeypatch):
    _llm_down(monkeypatch)
    asset_id = _seed_signal_asset(engine)
    with Session(engine) as session:
        session.add(Faultcard(
            fault_description="oop fout",
            fault_status=FaultStatus.OPEN,
            fault_reportdatetime=datetime.utcnow(),
            asset_id=asset_id,
        ))
        session.commit()

    created = scan_and_create_auto_drafts(engine=engine)
    assert created == []
    assert len(_drafts(engine)) == 0


def test_scan_skips_asset_with_existing_draft(engine, seeded, monkeypatch):
    _llm_down(monkeypatch)
    asset_a = _seed_signal_asset(engine)
    first = scan_and_create_auto_drafts(engine=engine)
    assert len(first) == 1

    # A second signal asset still gets drafted, but the first asset is not
    # drafted a second time.
    asset_b = _seed_signal_asset(engine)
    second = scan_and_create_auto_drafts(engine=engine)
    assert len(second) == 1

    drafts = _drafts(engine)
    assert len(drafts) == 2
    assert len([d for d in drafts if d.resolved_asset_id == asset_a]) == 1
    assert len([d for d in drafts if d.resolved_asset_id == asset_b]) == 1


def test_scan_without_operator_user_is_noop(engine, monkeypatch):
    """A bare engine (no seeded roles/users) must not crash — it scans nothing."""
    _llm_down(monkeypatch)
    _seed_signal_asset(engine)      # signal asset exists, but no operator user

    created = scan_and_create_auto_drafts(engine=engine)
    assert created == []
    assert len(_drafts(engine)) == 0


# ---------------------------------------------------------------------------
# queue integration
# ---------------------------------------------------------------------------

def test_auto_drafts_visible_in_queue(client, engine, seeded, headers_for, monkeypatch):
    _llm_down(monkeypatch)
    asset_id = _seed_signal_asset(engine)
    created = scan_and_create_auto_drafts(engine=engine)
    assert len(created) == 1

    resp = client.get(API, headers=headers_for("fk"))
    assert resp.status_code == 200
    drafts = resp.json()
    assert len(drafts) == 1
    assert drafts[0]["draft_id"] == created[0]
    assert drafts[0]["source"] == "auto"
    assert drafts[0]["resolved_asset_id"] == asset_id
