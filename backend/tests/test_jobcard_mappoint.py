"""Tests vir werksopdrag (jobcard) kaartligging.

Dek:
  - 'n Werksopdrag wat uit 'n foutkaartjie geskep word erf die fout se Mappoint.
  - 'n Eksplisiete mappoint_id oorheers die erfing.
  - Transiënte lat/lng op POST /job skep 'n Mappoint.
  - PATCH /job met lat/lng werk die bestaande Mappoint by.
"""

from app.models.mappoint import Mappoint
from sqlmodel import Session


API = "/api/v1"


def _create_fault_with_mappoint(client, headers_for):
    resp = client.post(
        f"{API}/fault",
        json={
            "fault_description": "Lek by Blok C",
            "latitude": -25.8480,
            "longitude": 28.2366,
        },
        headers=headers_for("student"),
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_job_from_fault_inherits_mappoint(client, headers_for):
    fault = _create_fault_with_mappoint(client, headers_for)

    resp = client.post(
        f"{API}/job",
        json={"job_desc": "Herstel lek", "fault_id": fault["fault_id"]},
        headers=headers_for("admin"),
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["fault_id"] == fault["fault_id"]
    assert body["mappoint_id"] == fault["mappoint_id"], "job should inherit the fault's mappoint"


def test_job_with_explicit_mappoint_wins(client, headers_for):
    fault = _create_fault_with_mappoint(client, headers_for)

    point = client.post(
        f"{API}/mappoint",
        json={"latitude": -25.8500, "longitude": 28.2380},
        headers=headers_for("admin"),
    )
    assert point.status_code == 201, point.text
    explicit_mappoint_id = point.json()["mappoint_id"]

    resp = client.post(
        f"{API}/job",
        json={
            "job_desc": "Herstel lek",
            "fault_id": fault["fault_id"],
            "mappoint_id": explicit_mappoint_id,
        },
        headers=headers_for("admin"),
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["mappoint_id"] == explicit_mappoint_id


def test_job_with_transient_lat_lng_creates_mappoint(client, headers_for, engine):
    resp = client.post(
        f"{API}/job",
        json={"job_desc": "Staan-werksopdrag", "latitude": -25.8520, "longitude": 28.2400},
        headers=headers_for("admin"),
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["mappoint_id"] is not None, "job with lat/lng should link a mappoint"

    with Session(engine) as session:
        point = session.get(Mappoint, body["mappoint_id"])
        assert point is not None
        assert point.latitude == -25.8520
        assert point.longitude == 28.2400


def test_patch_job_updates_mappoint(client, headers_for, engine):
    created = client.post(
        f"{API}/job",
        json={"job_desc": "Werkopdrag", "latitude": -25.8480, "longitude": 28.2366},
        headers=headers_for("admin"),
    ).json()
    mappoint_id = created["mappoint_id"]
    assert mappoint_id is not None

    resp = client.patch(
        f"{API}/job/{created['jobcard_id']}",
        json={"latitude": -25.8490, "longitude": 28.2380},
        headers=headers_for("admin"),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["mappoint_id"] == mappoint_id, "existing mappoint should be reused"

    with Session(engine) as session:
        point = session.get(Mappoint, mappoint_id)
        assert point.latitude == -25.8490
        assert point.longitude == 28.2380


def test_job_without_mappoint_keeps_null(client, headers_for):
    resp = client.post(
        f"{API}/job",
        json={"job_desc": "Geen kaartligging"},
        headers=headers_for("admin"),
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["mappoint_id"] is None
