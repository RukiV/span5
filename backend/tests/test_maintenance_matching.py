"""Regressie: onderhoud-passing moet hoofletter-on sensitief wees.

Die oorspronklike fout: ``job_type == "maintenance"`` (kleinletters) teen 'n
DB wat 'MAINTENANCE'/'Onderhoud' stoor — geen diensbeurt is ooit gevind nie,
en PREDIKSIE het toe elke ou bate as agterstallig/vervang gemerk.
"""

from datetime import datetime, timedelta

from sqlmodel import Session

from app.models.asset import Asset, Assettype
from app.models.enums import BuildingType, JobStatus, RoomStatus, RoomType
from app.models.job import Jobcard
from app.models.location import Building, Location, Room
from app.services.prediction_service import prediction_service
from app.services.survival_features import _completed_maintenance_jobs


def _mk_asset_with_job(session: Session, job_type_value: str) -> Asset:
    loc = Location(location_name=f"TL-{job_type_value}", location_type="campus",
                   location_streetnum="1", location_streetname="Toetstraat")
    session.add(loc)
    session.commit()
    bld = Building(building_name="TBlok", building_type=BuildingType.EDUCATIONAL,
                   location_id=loc.location_id)
    session.add(bld)
    session.commit()
    room = Room(room_name="Kamer", room_code="TK1", room_type=RoomType.CLASSROOM,
                room_status=RoomStatus.OPERATIONAL, building_id=bld.building_id)
    session.add(room)
    session.commit()
    atype = Assettype(assettype_name=f"Tipe-{job_type_value}",
                      assettype_avg_lifespan=60, assettype_service_interval=12,
                      assettype_replacement_threshold=3)
    session.add(atype)
    session.commit()
    created = datetime.utcnow() - timedelta(days=100)
    a = Asset(asset_name="Toets Bate", asset_brand="Merk", asset_serial=f"S-{job_type_value}",
              assettype_id=atype.assettype_id, room_id=room.room_id,
              asset_created_datetime=created)
    session.add(a)
    session.commit()
    session.add(Jobcard(
        job_desc=f"Diens {job_type_value}",
        job_status=JobStatus.COMPLETED,
        job_type=job_type_value,          # bv. 'MAINTENANCE' — HOOFLETTERS
        job_createddatetime=datetime.utcnow() - timedelta(days=30),
        job_finisheddatetime=datetime.utcnow() - timedelta(days=28),
        asset_id=a.asset_id,
        room_id=room.room_id,
    ))
    session.commit()
    session.refresh(a)
    return a


def test_uppercase_maintenance_job_is_found(engine):
    with Session(engine) as s:
        asset = _mk_asset_with_job(s, "MAINTENANCE")
        jobs = _completed_maintenance_jobs(s, asset.asset_id)
        assert len(jobs) == 1  # was 0 vóór die kasings-fiks


def test_afrikaans_onderhoud_job_is_found(engine):
    with Session(engine) as s:
        asset = _mk_asset_with_job(s, "Onderhoud")
        jobs = _completed_maintenance_jobs(s, asset.asset_id)
        assert len(jobs) == 1


def test_recent_uppercase_maintenance_prevents_overdue_flag(client, engine):
    """'n Onlangse MAINTENANCE-werk mag NIE die bate as vervang merk nie."""
    with Session(engine) as s:
        asset = _mk_asset_with_job(s, "MAINTENANCE")
        asset_id = asset.asset_id
    pred = prediction_service.getAssetPrediction(Session(engine), asset_id)
    assert pred.maintenance_overdue is False
    assert pred.replacement_suggested is False