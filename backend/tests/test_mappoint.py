"""Tests for kaartligging (Mappoint) ondersteuning op foutkaartjies.

Dek:
  - POST /fault met latitude/longitude skep 'n Mappoint en koppel mappoint_id.
  - PATCH /fault met nuwe lat/lng werk die bestaande Mappoint by.
  - POST /location stoor/persisteer kampus-lat/lng/radius.
"""

from app.models.mappoint import Mappoint
from sqlmodel import Session, select


API = "/api/v1"


def test_create_fault_with_mappoint_links_coordinates(client, headers_for, engine):
    resp = client.post(
        f"{API}/fault",
        json={
            "fault_description": "Gebreekte geyser by die kafeteria",
            "latitude": -25.8480,
            "longitude": 28.2366,
        },
        headers=headers_for("student"),
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["mappoint_id"] is not None, "fault should link a mappoint"

    with Session(engine) as session:
        point = session.get(Mappoint, body["mappoint_id"])
        assert point is not None
        assert point.latitude == -25.8480
        assert point.longitude == 28.2366

    # Die gekoppelde punt is weer leesbaar deur die mappoint-eindpunt.
    get_resp = client.get(f"{API}/mappoint/{body['mappoint_id']}", headers=headers_for("student"))
    assert get_resp.status_code == 200, get_resp.text
    assert get_resp.json()["latitude"] == -25.8480
    assert get_resp.json()["longitude"] == 28.2366


def test_fault_without_mappoint_keeps_mappoint_id_null(client, headers_for):
    resp = client.post(
        f"{API}/fault",
        json={"fault_description": "Skaars ligging"},
        headers=headers_for("student"),
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["mappoint_id"] is None


def test_patch_fault_updates_existing_mappoint(client, headers_for, engine):
    created = client.post(
        f"{API}/fault",
        json={
            "fault_description": "Lek in Blok L",
            "latitude": -25.8480,
            "longitude": 28.2366,
        },
        headers=headers_for("student"),
    ).json()
    mappoint_id = created["mappoint_id"]

    resp = client.patch(
        f"{API}/fault/{created['fault_id']}",
        json={"latitude": -25.8490, "longitude": 28.2380},
        headers=headers_for("admin"),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["mappoint_id"] == mappoint_id, "existing mappoint should be reused"

    with Session(engine) as session:
        point = session.get(Mappoint, mappoint_id)
        assert point.latitude == -25.8490
        assert point.longitude == 28.2380


def test_location_round_trips_lat_lng_radius(client, headers_for):
    resp = client.post(
        f"{API}/location",
        json={
            "location_name": "Toetskampus",
            "location_type": "Kampus",
            "location_streetnum": "1",
            "location_streetname": "Toetsstraat",
            "location_suburb": "Toetsvoorstad",
            "location_city": "Toetsstad",
            "location_province": "Gauteng",
            "location_country": "Suid Afrika",
            "location_latitude": -25.8480,
            "location_longitude": 28.2366,
            "location_radius": 150.0,
        },
        headers=headers_for("admin"),
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["location_latitude"] == -25.8480
    assert body["location_longitude"] == 28.2366
    assert body["location_radius"] == 150.0

    get_resp = client.get(f"{API}/location/{body['location_id']}", headers=headers_for("admin"))
    assert get_resp.status_code == 200, get_resp.text
    assert get_resp.json()["location_radius"] == 150.0
