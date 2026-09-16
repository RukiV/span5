"""AI job-draft endpoint tests.

The LLM is never called for real here: ``llm_service.extract`` /
``llm_service.disambiguate`` are monkeypatched (or made to raise) so we test the
pipeline, the degradation path, and the FK approval workflow deterministically.
"""

import json

from sqlmodel import Session, select

from app.models.asset import Asset, Assettype
from app.models.enums import BuildingType, Priority, RoomStatus, RoomType, Type
from app.models.job import Jobcard
from app.models.jobdraft import JobDraft
from app.models.location import Building, BuildingTypeLink, Location, Room
from app.services.llm_service import LlmUnavailable, llm_service

API = "/api/v1/ai"


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def _seed_entities(engine) -> dict:
    """Location -> building -> room -> assettype -> asset, mirroring seed_data."""
    with Session(engine) as session:
        loc = Location(
            location_name="Hoofkampus", location_type="campus",
            location_streetnum="1", location_streetname="Hoofweg",
        )
        session.add(loc)
        session.flush()
        bld = Building(building_name="Blok L", location_id=loc.location_id)
        session.add(bld)
        session.flush()
        session.add(BuildingTypeLink(building_id=bld.building_id, building_type=BuildingType.EDUCATIONAL))
        room = Room(room_name="Lesinglokaal A", room_code="LA-1",
                    room_type=RoomType.CLASSROOM, room_status=RoomStatus.OPERATIONAL,
                    building_id=bld.building_id)
        session.add(room)
        session.flush()
        at = Assettype(assettype_name="Projektor")
        session.add(at)
        session.flush()
        asset = Asset(asset_name="Projektor 4k", asset_brand="Epson",
                      asset_serial="PRJ-1", assettype_id=at.assettype_id,
                      room_id=room.room_id)
        session.add(asset)
        session.commit()
        return {"room": room.room_id, "building": bld.building_id, "asset": asset.asset_id}


def _drafts(engine):
    with Session(engine) as session:
        return session.exec(select(JobDraft)).all()


def _jobs(engine):
    with Session(engine) as session:
        return session.exec(select(Jobcard)).all()


# ---------------------------------------------------------------------------
# anonymous
# ---------------------------------------------------------------------------

def test_anonymous_is_401_everywhere(client):
    assert client.post(f"{API}", json={"description": "projektor flikker"}).status_code == 401
    assert client.get(f"{API}").status_code == 401
    assert client.get(f"{API}/1").status_code == 401
    assert client.post(f"{API}/1/approve", json={}).status_code == 401
    assert client.post(f"{API}/1/reject", json={"reason": "nie"}).status_code == 401


# ---------------------------------------------------------------------------
# draft creation
# ---------------------------------------------------------------------------

def test_fk_creates_draft_degraded_when_llm_down(client, engine, headers_for, monkeypatch):
    """Ollama unreachable -> draft still created, rules-only, flagged degraded."""
    def _boom(desc):
        raise LlmUnavailable("down")
    monkeypatch.setattr(llm_service, "extract", _boom)

    resp = client.post(f"{API}", json={"description": "Toilet oorloop"},
                       headers=headers_for("fk"))
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["ai_status"] == "degraded"
    assert data["status"] == "draft"
    assert data["suggested_type"] == "REPAIR"
    assert data["suggested_priority"] == "HIGH"   # oorloop -> HIGH
    assert data["cleaned_description"] == "Toilet oorloop"  # raw fallback
    assert data["source"] == "manual"
    drafts = _drafts(engine)
    assert len(drafts) == 1
    assert drafts[0].user_id == _user_id(engine, "fk")


def _user_id(engine, role):
    from app.models.user import User
    from app.auth.rights_catalog import ROLE_STUDENT, ROLE_FK, ROLE_ADMIN, ROLE_CONTRACTOR
    role_ids = {"student": ROLE_STUDENT, "fk": ROLE_FK, "admin": ROLE_ADMIN, "contractor": ROLE_CONTRACTOR}
    with Session(engine) as session:
        return session.exec(select(User).where(User.role_id == role_ids[role])).first().user_id


def test_fk_creates_draft_with_llm_and_resolution(client, engine, headers_for, monkeypatch):
    """LLM available -> mentions resolved to backend candidates, disambiguation applied."""
    _seed_entities(engine)
    canned = {
        "cleaned_description": "Die projektorlens is gekraak.",
        "title": "Projektorlens gekraak",
        "asset_mention": "Projektor",
        "room_mention": "",
        "failure_category": "it",
        "work_instruction": "Vervang die lens.",
        "language": "af",
    }
    monkeypatch.setattr(llm_service, "extract", lambda desc: canned)
    monkeypatch.setattr(llm_service, "disambiguate",
                        lambda **kw: {"asset_id": kw["asset_candidates"][0]["id"],
                                      "room_id": None, "duplicate_of": None})

    resp = client.post(f"{API}", json={"description": "Projektor lens is gekraak"},
                       headers=headers_for("fk"))
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["ai_status"] == "ok"
    assert data["title"] == "Projektorlens gekraak"
    assert data["failure_category"] == "it"
    assert data["resolved_asset_id"] is not None
    # rules still own the taxonomy
    assert data["suggested_type"] == "REPAIR"
    assert data["suggested_priority"] == "MEDIUM"


def test_degraded_fallback_resolves_from_raw_text(client, engine, headers_for, monkeypatch):
    """LLM down, but the description names an asset -> rules keyword extraction
    still produces candidate ids for the FK queue."""
    _seed_entities(engine)
    monkeypatch.setattr(llm_service, "extract", lambda desc: (_ for _ in ()).throw(LlmUnavailable("down")))

    resp = client.post(f"{API}", json={"description": "Projektor flikker in Lesinglokaal A"},
                       headers=headers_for("fk"))
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["ai_status"] == "degraded"
    asset_ids = json.loads(data["asset_ids"])
    room_ids = json.loads(data["room_ids"])
    assert len(asset_ids) == 1          # the seeded Projektor
    assert len(room_ids) == 1           # Lesinglokaal A
    assert data["suggested_type"] == "REPAIR"


def test_student_cannot_create_draft(client, headers_for):
    """The AI pipeline is FK/Admin-only: students report faults directly via
    POST /fault (immediately created) and never see the draft queue."""
    assert client.post(f"{API}", json={"description": "projektor flikker"},
                       headers=headers_for("student")).status_code == 403


def test_contractor_cannot_create_draft(client, headers_for):
    resp = client.post(f"{API}", json={"description": "projektor flikker"},
                       headers=headers_for("contractor"))
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# approval queue
# ---------------------------------------------------------------------------

def _make_draft(client, engine, headers_for, monkeypatch, description="Projektor flikker"):
    monkeypatch.setattr(llm_service, "extract", lambda desc: (_ for _ in ()).throw(LlmUnavailable("down")))
    resp = client.post(f"{API}", json={"description": description}, headers=headers_for("fk"))
    assert resp.status_code == 201
    return resp.json()


def test_list_drafts_is_fk_admin_only(client, engine, headers_for, monkeypatch):
    _make_draft(client, engine, headers_for, monkeypatch)
    assert client.get(f"{API}", headers=headers_for("student")).status_code == 403
    assert client.get(f"{API}", headers=headers_for("contractor")).status_code == 403
    for role in ("fk", "admin"):
        resp = client.get(f"{API}", headers=headers_for(role))
        assert resp.status_code == 200
        assert len(resp.json()) == 1


def test_fk_approve_creates_jobcard(client, engine, headers_for, monkeypatch):
    draft = _make_draft(client, engine, headers_for, monkeypatch, "Toilet oorloop")
    fk = headers_for("fk")

    resp = client.post(f"{API}/{draft['draft_id']}/approve",
                       json={"fault_type": "REPAIR", "fault_priority": "HIGH"}, headers=fk)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["status"] == "approved"
    assert data["reviewer_id"] == _user_id(engine, "fk")

    jobs = _jobs(engine)
    assert len(jobs) == 2  # seeded job + approved one
    created = [j for j in jobs if j.job_desc == "Toilet oorloop"]
    assert len(created) == 1
    # The FK who ran the AI pipeline keeps ownership of the jobcard; their
    # approval action also lands in the audit trail.
    assert created[0].user_id == _user_id(engine, "fk")


def test_fk_approve_with_inline_edits_overrides_ai(client, engine, headers_for, monkeypatch):
    draft = _make_draft(client, engine, headers_for, monkeypatch, "Projektor skakel nie aan nie")
    resp = client.post(
        f"{API}/{draft['draft_id']}/approve",
        json={"fault_type": "MAINTENANCE", "fault_priority": "LOW",
              "cleaned_description": "FK het dit reggemaak"},
        headers=headers_for("fk"),
    )
    assert resp.status_code == 200
    created = [j for j in _jobs(engine) if j.job_desc == "FK het dit reggemaak"]
    assert len(created) == 1
    assert created[0].job_type == "MAINTENANCE"  # inline edit won
    assert created[0].job_priority == "LOW"


def test_approve_requires_ai_approve_right(client, engine, headers_for, monkeypatch):
    draft = _make_draft(client, engine, headers_for, monkeypatch)
    assert client.post(f"{API}/{draft['draft_id']}/approve",
                       json={}, headers=headers_for("student")).status_code == 403
    assert client.post(f"{API}/{draft['draft_id']}/approve",
                       json={}, headers=headers_for("contractor")).status_code == 403


def test_fk_reject_with_reason(client, engine, headers_for, monkeypatch):
    draft = _make_draft(client, engine, headers_for, monkeypatch)
    resp = client.post(f"{API}/{draft['draft_id']}/reject",
                       json={"reason": "Reeds deur die skooladministrasie hanteer"},
                       headers=headers_for("admin"))
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "rejected"
    assert data["review_note"] == "Reeds deur die skooladministrasie hanteer"
    assert data["reviewer_id"] == _user_id(engine, "admin")
    assert len(_jobs(engine)) == 1  # no jobcard created on reject


def test_review_twice_is_conflict(client, engine, headers_for, monkeypatch):
    draft = _make_draft(client, engine, headers_for, monkeypatch)
    h = headers_for("fk")
    assert client.post(f"{API}/{draft['draft_id']}/approve",
                       json={"fault_type": "REPAIR", "fault_priority": "MEDIUM"}, headers=h).status_code == 200
    assert client.post(f"{API}/{draft['draft_id']}/approve",
                       json={"fault_type": "REPAIR", "fault_priority": "MEDIUM"}, headers=h).status_code == 409
    assert client.post(f"{API}/{draft['draft_id']}/reject",
                       json={"reason": "laat"}, headers=h).status_code == 409


def test_draft_detail_exposes_candidates(client, engine, headers_for, monkeypatch):
    _seed_entities(engine)
    draft = _make_draft(client, engine, headers_for, monkeypatch, "Projektor flikker in Lesinglokaal A")
    resp = client.get(f"{API}/{draft['draft_id']}", headers=headers_for("fk"))
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["asset_candidates"]) == 1
    assert data["asset_candidates"][0]["name"] == "Projektor 4k"
    assert len(data["room_candidates"]) == 1
    assert data["room_candidates"][0]["name"] == "Lesinglokaal A"


# ---------------------------------------------------------------------------
# security properties (weaver review follow-ups)
# ---------------------------------------------------------------------------

def test_llm_cannot_inject_foreign_ids(client, engine, headers_for, monkeypatch):
    """Even if the LLM returns ids outside the candidate lists the backend
    handed it, they are dropped at the endpoint (defense in depth)."""
    _seed_entities(engine)
    canned = {
        "cleaned_description": "Projektor flikker.",
        "title": "Projektor",
        "asset_mention": "Projektor",
        "room_mention": "Lesinglokaal A",
        "failure_category": "it",
        "work_instruction": "",
        "language": "af",
    }
    monkeypatch.setattr(llm_service, "extract", lambda desc: canned)
    monkeypatch.setattr(llm_service, "disambiguate",
                        lambda **kw: {"asset_id": 9999, "room_id": 9999, "duplicate_of": 9999})

    resp = client.post(f"{API}", json={"description": "Projektor flikker in Lesinglokaal A"},
                       headers=headers_for("fk"))
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["ai_status"] == "ok"
    assert data["resolved_asset_id"] is None
    assert data["resolved_room_id"] is None
    assert data["duplicate_of"] is None


def test_approve_rejects_nonexistent_or_mismatched_ids(client, engine, headers_for, monkeypatch):
    _seed_entities(engine)
    draft = _make_draft(client, engine, headers_for, monkeypatch)
    fk = headers_for("fk")
    # nonexistent asset
    assert client.post(f"{API}/{draft['draft_id']}/approve",
                       json={"asset_id": 99999}, headers=fk).status_code == 422
    # nonexistent room
    assert client.post(f"{API}/{draft['draft_id']}/approve",
                       json={"room_id": 99999}, headers=fk).status_code == 422
    # room whose building does not match the given building
    with Session(engine) as session:
        b = Building(building_name="Blok X", location_id=1)
        session.add(b)
        session.commit()
        from app.models.location import Room as _Room
        room = session.exec(select(_Room)).first()
        assert client.post(f"{API}/{draft['draft_id']}/approve",
                           json={"room_id": room.room_id, "building_id": b.building_id},
                           headers=fk).status_code == 422


def test_approve_propagates_duplicate_of(client, engine, headers_for, monkeypatch):
    """The duplicate-detection signal lands on the created jobcard."""
    _seed_entities(engine)
    seeded_job_id = _jobs(engine)[0].jobcard_id  # conftest seeds one job
    canned = {
        "cleaned_description": "Projektor flikker weer.",
        "title": "Projektor flikker",
        "asset_mention": "Projektor",
        "room_mention": "",
        "failure_category": "it",
        "work_instruction": "",
        "language": "af",
    }
    monkeypatch.setattr(llm_service, "extract", lambda desc: canned)
    monkeypatch.setattr(llm_service, "disambiguate",
                        lambda **kw: {"asset_id": kw["asset_candidates"][0]["id"],
                                      "room_id": None,
                                      "duplicate_of": seeded_job_id})

    resp = client.post(f"{API}", json={"description": "Projektor flikker weer"},
                       headers=headers_for("fk"))
    assert resp.status_code == 201, resp.text
    draft = resp.json()
    assert draft["duplicate_of"] == seeded_job_id

    appr = client.post(f"{API}/{draft['draft_id']}/approve",
                       json={"fault_type": "REPAIR", "fault_priority": "MEDIUM"},
                       headers=headers_for("fk"))
    assert appr.status_code == 200, appr.text
    created = [j for j in _jobs(engine) if j.jobcard_id != seeded_job_id]
    assert len(created) == 1
    assert created[0].duplicate_of == seeded_job_id


def test_long_llm_output_is_clamped_not_500(client, engine, headers_for, monkeypatch):
    """A 5000-char LLM rewrite must degrade to a 2000-char clamp, not 500."""
    long_text = "x" * 5000
    monkeypatch.setattr(llm_service, "extract",
                        lambda desc: {"cleaned_description": long_text,
                                      "title": long_text[:255],
                                      "work_instruction": long_text,
                                      "failure_category": "it",
                                      "language": "af",
                                      "asset_mention": "", "room_mention": ""})
    resp = client.post(f"{API}", json={"description": "kort beskrywing"},
                       headers=headers_for("fk"))
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert len(data["cleaned_description"]) <= 2000
    assert len(data["work_instruction"]) <= 2000


# ---------------------------------------------------------------------------
# AI status endpoint
# ---------------------------------------------------------------------------


def test_ai_status_anonymous_401(client):
    assert client.get(f"{API}/status").status_code == 401


def test_ai_status_fk_returns_enabled(client, engine, headers_for, monkeypatch):
    monkeypatch.setenv("AI_ENABLED", "true")
    resp = client.get(f"{API}/status", headers=headers_for("fk"))
    assert resp.status_code == 200, resp.text
    assert resp.json() == {"ai_enabled": True}


def test_ai_status_fk_returns_disabled(client, engine, headers_for, monkeypatch):
    monkeypatch.setenv("AI_ENABLED", "false")
    resp = client.get(f"{API}/status", headers=headers_for("fk"))
    assert resp.status_code == 200, resp.text
    assert resp.json() == {"ai_enabled": False}


def test_ai_status_contractor_no_access(client, engine, headers_for):
    resp = client.get(f"{API}/status", headers=headers_for("contractor"))
    assert resp.status_code == 403
