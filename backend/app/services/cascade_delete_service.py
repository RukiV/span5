from datetime import datetime
from typing import Optional

from sqlmodel import Session, select
from sqlalchemy import delete, update

from ..models.location import Room, Building, Location
from ..models.room_check import RoomCheck
from ..models.room_check_session import RoomCheckSession
from ..models.asset import Asset
from ..models.stock import Stock
from ..models.fault import Faultcard
from ..models.job import Jobcard
from ..models.audit import Auditlog


def _audit_delete(session: Session, table: str, obj_id: Optional[int], user_id: Optional[int]) -> None:
    """Log a 'delete' audit entry for a single top-level entity, mirroring
    BaseService._create_audit_log so the existing audit trail is preserved."""
    session.add(
        Auditlog(
            action="delete",
            affectedtable=table,
            affectedcolumn=None,
            affectedid=obj_id,
            previous_value=None,
            new_value=None,
            json_data=None,
            actiondatetime=datetime.utcnow(),
            user_id=user_id,
        )
    )


def _clean_room_dependents(session: Session, room_id: int) -> None:
    """Remove a room's checklist history entirely and unlink (without deleting)
    any assets, stock items, faults or jobs that pointed at the room."""
    # RoomCheckSession references RoomCheck, so delete the sessions first.
    session.exec(delete(RoomCheckSession).where(RoomCheckSession.room_id == room_id))
    session.exec(delete(RoomCheck).where(RoomCheck.room_id == room_id))

    session.exec(update(Asset).where(Asset.room_id == room_id).values(room_id=None))
    session.exec(update(Stock).where(Stock.room_id == room_id).values(room_id=None))
    session.exec(update(Faultcard).where(Faultcard.room_id == room_id).values(room_id=None))
    session.exec(update(Jobcard).where(Jobcard.room_id == room_id).values(room_id=None))


def delete_room_cascade(session: Session, room_id: int, user_id: Optional[int] = None) -> bool:
    """Issue 4 — delete a room safely: clean its checklist history and unlink
    dependent assets/stock/faults/jobs, then remove the room itself."""
    room = session.get(Room, room_id)
    if room is None:
        return False

    try:
        _clean_room_dependents(session, room_id)
        session.delete(room)
        _audit_delete(session, "room", room_id, user_id)
        session.commit()
    except Exception:
        session.rollback()
        raise
    return True


def delete_building_cascade(session: Session, building_id: int, user_id: Optional[int] = None) -> bool:
    """Issue 5 — run the room cleanup for every room in the building, then
    remove those rooms and the building, all in one transaction."""
    building = session.get(Building, building_id)
    if building is None:
        return False

    try:
        rooms = session.exec(select(Room).where(Room.building_id == building_id)).all()
        for room in rooms:
            _clean_room_dependents(session, room.room_id)
            session.delete(room)

        # Faults/jobs can also point directly at a building (no room).
        session.exec(update(Faultcard).where(Faultcard.building_id == building_id).values(building_id=None))
        session.exec(update(Jobcard).where(Jobcard.building_id == building_id).values(building_id=None))

        session.delete(building)
        _audit_delete(session, "building", building_id, user_id)
        session.commit()
    except Exception:
        session.rollback()
        raise
    return True


def delete_location_cascade(session: Session, location_id: int, user_id: Optional[int] = None) -> bool:
    """Issue 6 — run the building cleanup for every building in the campus, then
    remove those buildings and the campus, all in one transaction."""
    location = session.get(Location, location_id)
    if location is None:
        return False

    try:
        buildings = session.exec(select(Building).where(Building.location_id == location_id)).all()
        for building in buildings:
            rooms = session.exec(select(Room).where(Room.building_id == building.building_id)).all()
            for room in rooms:
                _clean_room_dependents(session, room.room_id)
                session.delete(room)

            session.exec(update(Faultcard).where(Faultcard.building_id == building.building_id).values(building_id=None))
            session.exec(update(Jobcard).where(Jobcard.building_id == building.building_id).values(building_id=None))

            session.delete(building)

        # Faults/jobs can also point directly at a campus (no building/room).
        session.exec(update(Faultcard).where(Faultcard.location_id == location_id).values(location_id=None))
        session.exec(update(Jobcard).where(Jobcard.location_id == location_id).values(location_id=None))

        session.delete(location)
        _audit_delete(session, "location", location_id, user_id)
        session.commit()
    except Exception:
        session.rollback()
        raise
    return True
