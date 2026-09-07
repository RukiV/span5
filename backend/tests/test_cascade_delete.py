"""Milestone 2 — backend cascade delete for the location hierarchy.

Covers Issues 4 (room), 5 (building) and 6 (location): deleting a node cleans
up its checklist history, unlinks (without deleting) dependent assets/stock/
faults/jobs, and removes children all-or-nothing.
"""

import pytest
from sqlmodel import Session, select

from app.models.location import Location, Building, Room
from app.models.asset import Asset, Assettype
from app.models.stock import Stock
from app.models.fault import Faultcard
from app.models.job import Jobcard
from app.models.room_check import RoomCheck
from app.models.room_check_session import RoomCheckSession


@pytest.fixture(name="hierarchy")
def hierarchy_fixture(engine, seeded):
    """Build a campus -> building -> room with every kind of dependent row,
    plus faults/jobs attached directly at the building and campus level."""
    admin_id = seeded["ids"]["admin"]
    with Session(engine) as session:
        assettype = Assettype(assettype_name="Test")
        session.add(assettype)
        session.commit()
        session.refresh(assettype)

        location = Location(
            location_name="Kampus", location_type="campus",
            location_streetnum="1", location_streetname="Straat",
        )
        session.add(location)
        session.commit()
        session.refresh(location)

        building = Building(building_name="Gebou", location_id=location.location_id)
        session.add(building)
        session.commit()
        session.refresh(building)

        room = Room(room_name="Lokaal", room_code="RL1", building_id=building.building_id)
        session.add(room)
        session.commit()
        session.refresh(room)

        asset = Asset(asset_name="Bates", asset_brand="B", asset_serial="S1", assettype_id=assettype.assettype_id, room_id=room.room_id)
        stock = Stock(stock_brand="B", stock_type="T", room_id=room.room_id)
        room_fault = Faultcard(fault_description="room fault", room_id=room.room_id,
                               building_id=building.building_id, location_id=location.location_id)
        room_job = Jobcard(job_desc="room job", room_id=room.room_id,
                           building_id=building.building_id, location_id=location.location_id)
        bld_fault = Faultcard(fault_description="building fault", building_id=building.building_id,
                              location_id=location.location_id)
        loc_fault = Faultcard(fault_description="location fault", location_id=location.location_id)
        rc = RoomCheck(room_id=room.room_id, summary="check", user_id=admin_id)
        rcs = RoomCheckSession(room_id=room.room_id, assigned_user_id=admin_id)

        for obj in (asset, stock, room_fault, room_job, bld_fault, loc_fault, rc, rcs):
            session.add(obj)
        session.commit()

        ids = {
            "location_id": location.location_id,
            "building_id": building.building_id,
            "room_id": room.room_id,
            "asset_id": asset.asset_id,
            "stock_id": stock.stock_id,
            "room_fault_id": room_fault.fault_id,
            "room_job_id": room_job.jobcard_id,
            "bld_fault_id": bld_fault.fault_id,
            "loc_fault_id": loc_fault.fault_id,
            "rc_id": rc.room_check_id,
            "rcs_id": rcs.session_id,
        }
    return ids


def _get(session, model, id_field, id_value):
    return session.exec(select(model).where(getattr(model, id_field) == id_value)).first()


def test_location_cascade_deletes_hierarchy_and_unlinks_dependents(engine, client, headers_for, hierarchy):
    admin = headers_for("admin")
    resp = client.delete(f"/api/v1/location/{hierarchy['location_id']}", headers=admin)
    assert resp.status_code == 204

    with Session(engine) as session:
        # Hierarchy removed.
        assert _get(session, Location, "location_id", hierarchy["location_id"]) is None
        assert _get(session, Building, "building_id", hierarchy["building_id"]) is None
        assert _get(session, Room, "room_id", hierarchy["room_id"]) is None
        # Checklist history removed entirely.
        assert _get(session, RoomCheck, "room_check_id", hierarchy["rc_id"]) is None
        assert _get(session, RoomCheckSession, "session_id", hierarchy["rcs_id"]) is None
        # Dependents still exist but unlinked (no FK points at the removed nodes).
        asset = _get(session, Asset, "asset_id", hierarchy["asset_id"])
        assert asset is not None and asset.room_id is None
        stock = _get(session, Stock, "stock_id", hierarchy["stock_id"])
        assert stock is not None and stock.room_id is None
        room_fault = _get(session, Faultcard, "fault_id", hierarchy["room_fault_id"])
        assert room_fault is not None and room_fault.room_id is None \
            and room_fault.building_id is None and room_fault.location_id is None
        room_job = _get(session, Jobcard, "jobcard_id", hierarchy["room_job_id"])
        assert room_job is not None and room_job.room_id is None \
            and room_job.building_id is None and room_job.location_id is None
        # Building- and location-level dependents are unlinked, not deleted.
        bld_fault = _get(session, Faultcard, "fault_id", hierarchy["bld_fault_id"])
        assert bld_fault is not None and bld_fault.building_id is None
        loc_fault = _get(session, Faultcard, "fault_id", hierarchy["loc_fault_id"])
        assert loc_fault is not None and loc_fault.location_id is None


def test_missing_location_delete_returns_404(client, headers_for):
    resp = client.delete("/api/v1/location/999999", headers=headers_for("admin"))
    assert resp.status_code == 404


def test_building_cascade_deletes_rooms_and_unlinks(engine, client, headers_for, hierarchy):
    admin = headers_for("admin")
    resp = client.delete(f"/api/v1/building/{hierarchy['building_id']}", headers=admin)
    assert resp.status_code == 204

    with Session(engine) as session:
        # Building + its room + checklist history gone.
        assert _get(session, Building, "building_id", hierarchy["building_id"]) is None
        assert _get(session, Room, "room_id", hierarchy["room_id"]) is None
        assert _get(session, RoomCheck, "room_check_id", hierarchy["rc_id"]) is None
        # Room-level dependents unlinked; building-level fault unlinked.
        asset = _get(session, Asset, "asset_id", hierarchy["asset_id"])
        assert asset is not None and asset.room_id is None
        bld_fault = _get(session, Faultcard, "fault_id", hierarchy["bld_fault_id"])
        assert bld_fault is not None and bld_fault.building_id is None
        # The campus itself is untouched.
        assert _get(session, Location, "location_id", hierarchy["location_id"]) is not None
        loc_fault = _get(session, Faultcard, "fault_id", hierarchy["loc_fault_id"])
        assert loc_fault is not None and loc_fault.location_id == hierarchy["location_id"]


def test_room_cascade_cleans_checklist_and_unlinks(engine, client, headers_for, hierarchy):
    admin = headers_for("admin")
    resp = client.delete(f"/api/v1/rooms/{hierarchy['room_id']}", headers=admin)
    assert resp.status_code == 204

    with Session(engine) as session:
        assert _get(session, Room, "room_id", hierarchy["room_id"]) is None
        assert _get(session, RoomCheck, "room_check_id", hierarchy["rc_id"]) is None
        asset = _get(session, Asset, "asset_id", hierarchy["asset_id"])
        assert asset is not None and asset.room_id is None
        # Sibling building/campus remain.
        assert _get(session, Building, "building_id", hierarchy["building_id"]) is not None
