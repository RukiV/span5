"""Tests vir die /ai/suggest veldvoorstel-enjin en die Ligging-name op konsepte."""

from sqlmodel import Session

from app.models.asset import Asset, Assettype
from app.models.enums import BuildingType, RoomStatus, RoomType
from app.models.location import Building, Location, Room
from app.models.jobdraft import JobDraft
from app.models.stock import Stock
from app.services import suggest_service


# ── Hulpwers (mirroor seed_data se vereistes) ───────────────────────────────


def _mk_location(session: Session, name="Toetskampus"):
    loc = Location(location_name=name, location_type="campus",
                   location_streetnum="1", location_streetname="Toetstraat")
    session.add(loc)
    session.commit()
    session.refresh(loc)
    return loc


def _mk_building(session: Session, location_id, name="T Blok"):
    b = Building(building_name=name, building_type=BuildingType.EDUCATIONAL,
                 location_id=location_id)
    session.add(b)
    session.commit()
    session.refresh(b)
    return b


def _mk_room(session: Session, building_id, name="K1"):
    r = Room(room_name=name, room_code=f"{name}-1", room_type=RoomType.CLASSROOM,
             room_status=RoomStatus.OPERATIONAL, building_id=building_id)
    session.add(r)
    session.commit()
    session.refresh(r)
    return r


def _mk_type(session: Session, name):
    t = Assettype(assettype_name=name)
    session.add(t)
    session.commit()
    session.refresh(t)
    return t


def _mk_asset(session: Session, name, type_id, room_id=None):
    a = Asset(asset_name=name, asset_brand="Generic", asset_serial=f"S-{abs(hash(name)) % 10000}",
              assettype_id=type_id, room_id=room_id)
    session.add(a)
    session.commit()
    session.refresh(a)
    return a


# ─~ Gate: minder as 3 ingevulde velde → leë antwoord ──────────────────────────


def test_gate_under_three_filled_fields(engine):
    assert suggest_service.suggest("asset", Session(engine), {"asset_name": "Stoel"}) == {}
    assert suggest_service.suggest("asset", Session(engine), {}) == {}
    assert suggest_service.suggest("onbekend", Session(engine), {"a": 1, "b": 2, "c": 3}) == {}


def test_empty_strings_do_not_count_as_filled(engine):
    fields = {"asset_name": "", "asset_brand": "  ", "asset_serial": None}
    assert suggest_service.suggest("asset", Session(engine), fields) == {}


# ─~ Asset: naam → assettype (meerderheid-stem) ───────────────────────────────


def test_asset_type_majority_vote_from_similar_names(engine):
    with Session(engine) as s:
        stoel = _mk_type(s, "Stoel")
        projektor = _mk_type(s, "Projektor")
        for i in range(3):
            _mk_asset(s, f"Kantoor stoel {i}", stoel.assettype_id)
        _mk_asset(s, "Lesinglokaal projektor", projektor.assettype_id)

        out = suggest_service.suggest("asset", s, {
            "asset_name": "Kantoor stoel 12",
            "asset_brand": "Generic",
            "asset_serial": "X1",
        })
    assert out["asset_type"]["value"] == "Stoel"
    assert out["asset_type"]["id"] == stoel.assettype_id
    # asset_brand is nie vulbaar nie — kom nooit in die antwoord voor nie.
    assert "asset_brand" not in out


def test_asset_does_not_suggest_already_filled_field(engine):
    with Session(engine) as s:
        stoel = _mk_type(s, "Stoel")
        for i in range(3):
            _mk_asset(s, f"Kantoor stoel {i}", stoel.assettype_id)

        out = suggest_service.suggest("asset", s, {
            "asset_name": "Kantoor stoel 12",
            "asset_brand": "Generic",
            "asset_serial": "X1",
            "asset_type": stoel.assettype_id,  # reeds gekies
        })
    assert "asset_type" not in out


def test_asset_no_similar_names_returns_empty(engine):
    with Session(engine) as s:
        t = _mk_type(s, "Stoel")
        _mk_asset(s, "Projektor eenheid A", t.assettype_id)
        out = suggest_service.suggest("asset", s, {
            "asset_name": "Heftruck", "asset_brand": "B", "asset_serial": "S",
        })
    assert out == {}


# ─~ Fault/Job: reëls-klassifiseerder ────────────────────────────────────────


def test_fault_suggests_type_and_priority(engine):
    out = suggest_service.suggest("fault", Session(engine), {
        "description": "Die kraan lek erg in die kombuis, water oral",
        "title": "Kraan lek",
        "room": 4,
    })
    assert out["fault_type"]["value"] in ("REPAIR", "MAINTENANCE")
    assert out["fault_priority"]["value"] in ("LOW", "MEDIUM", "HIGH")


def test_job_respects_existing_values(engine):
    out = suggest_service.suggest("job", Session(engine), {
        "job_desc": "Diens die lugreëling eenheid",
        "job_type": "MAINTENANCE",  # reeds gekies
        "x": 1,
    })
    assert "job_type" not in out


# ─~ Stock: naam → stock_type ────────────────────────────────────────────────


def test_stock_suggests_type_by_similarity(engine):
    with Session(engine) as s:
        for i in range(2):
            s.add(Stock(stock_name=f"Skroef M8 pak {i}", stock_brand="Bolt",
                        stock_type="Verbruiksgoed"))
        s.add(Stock(stock_name="Skoonmaakmiddel", stock_brand="Clorox",
                    stock_type="Chemies"))
        s.commit()

        out = suggest_service.suggest("stock", s, {
            "stock_name": "Skroef M10 pak nuut", "stock_brand": "Bolt", "stock_amount": 5,
        })
    assert out["stock_type"]["value"] == "Verbruiksgoed"


# ─~ Draft: titel/tipe/prioriteit uit beskywing ───────────────────────────────


def test_draft_suggestions(engine):
    out = suggest_service.suggest("draft", Session(engine), {
        "description": "Projektor flikker in lesinglokaal B. Dit gebeur heeltyd.",
        "language": "af",
        "failure_category": "it",
    })
    assert out["title"]["value"].startswith("Projektor flikker")


# ─~ GET /ai lys bevat onttassel name ────────────────────────────────────────


def test_list_and_detail_include_location_names(client, engine, headers_for):
    fk = headers_for("fk")
    with Session(engine) as s:
        loc = _mk_location(s)
        b = _mk_building(s, loc.location_id)
        r = _mk_room(s, b.building_id, "Lesinglokaal A")
        t = _mk_type(s, "Projektor")
        a = _mk_asset(s, "Projektor PLA-1", t.assettype_id, r.room_id)

        d = JobDraft(
            description="Projektor lens gekraak", cleaned_description="Lens gekraak",
            title="Lens", suggested_type="REPAIR", suggested_priority="HIGH",
            failure_category="it", language="af", ai_status="ok", source="manual",
            status="draft", user_id=2,
            resolved_asset_id=a.asset_id, resolved_room_id=r.room_id,
            asset_ids="[]", room_ids="[]",
        )
        s.add(d)
        s.commit()
        draft_id = d.draft_id

    resp = client.get("/api/v1/ai?status_filter=draft", headers=fk)
    assert resp.status_code == 200, resp.text
    rows = resp.json()
    row = next(x for x in rows if x["draft_id"] == draft_id)
    assert row["resolved_room_name"] == "Lesinglokaal A"
    assert row["building_name"] == "T Blok"
    assert row["resolved_asset_name"] == "Projektor PLA-1"

    resp = client.get(f"/api/v1/ai/{draft_id}", headers=fk)
    assert resp.status_code == 200
    detail = resp.json()
    assert detail["resolved_room_name"] == "Lesinglokaal A"
    assert "asset_candidates" in detail


# ─~ POST /ai/suggest endpoint ───────────────────────────────────────────────


def test_suggest_endpoint_gating_and_payload(client, engine, headers_for):
    headers = headers_for("fk")

    # Sonder enige velde → leë voorstelle (MIN_FILLED=1).
    resp = client.post("/api/v1/ai/suggest", headers=headers,
                       json={"context": "fault", "fields": {}})
    assert resp.status_code == 200
    assert resp.json() == {"suggestions": {}}

    # Met 1 gevulde veld → voorstelle (gate verlaag na 1 vir vroeë spookteks).
    resp = client.post("/api/v1/ai/suggest", headers=headers,
                       json={"context": "fault", "fields": {"description": "Die kraan lek erg"}})
    assert resp.status_code == 200
    assert "fault_type" in resp.json()["suggestions"]

    # Bo 1 veld → voorstelle ook.
    resp = client.post("/api/v1/ai/suggest", headers=headers,
                       json={"context": "fault", "fields": {
                            "description": "Die kraan lek erg",
                            "title": "Lek", "room": 9}})
    assert resp.status_code == 200
    sug = resp.json()["suggestions"]
    assert "fault_type" in sug


def test_list_falls_back_to_first_candidate_when_unresolved(client, engine, headers_for):
    """Ligging-kolom: soner opgeloste id's wys die eerste kandidaat tog."""
    fk = headers_for("fk")
    with Session(engine) as s:
        loc = _mk_location(s)
        b = _mk_building(s, loc.location_id)
        r = _mk_room(s, b.building_id, "Kombuis B")
        d = JobDraft(
            description="Pyp lek", cleaned_description="Pyp lek",
            title="Lek", suggested_type="REPAIR", suggested_priority="HIGH",
            failure_category="plumbing", language="af", ai_status="ok", source="manual",
            status="draft", user_id=2,
            resolved_room_id=None, room_ids=f"[{r.room_id}]",
            asset_ids="[]",
        )
        s.add(d)
        s.commit()
        draft_id = d.draft_id

    resp = client.get("/api/v1/ai?status_filter=draft", headers=fk)
    row = next(x for x in resp.json() if x["draft_id"] == draft_id)
    assert row["resolved_room_name"] == "Kombuis B"
    assert row["building_name"] == "T Blok"
