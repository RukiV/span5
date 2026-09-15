import json
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlmodel import Session, select
from ....auth.permissions import get_current_user, require_any_right, require_right
from ....db.database import getSession
from ....models.room_check import RoomCheckRead, RoomCheckCreate
from ....models.room_check_session import RoomCheckSession
from ....models.asset import Asset
from ....models.user import User
from ....models.fault import Faultcard, FaultcardCreate, FaultStatus, WRONG_ROOM_FAULT_PREFIX
from ....models.location import Room, Building
from ....services.room_check_service import room_check_service
from ....services.fault_service import fault_service
from ....services.notification_service import NotificationService

router = APIRouter()

class MissingFoundIn(BaseModel):
    asset_id: int
    room_id: int
    original_fault_id: Optional[int] = None

def _to_read(session: Session, check) -> RoomCheckRead:
    data = RoomCheckRead.model_validate(check)
    if check.user_id:
        user = session.get(User, check.user_id)
        if user:
            data.user_name = f"{user.user_name} {user.user_surname}".strip()
    items = []
    try:
        items = json.loads(check.summary or '[]')
    except Exception:
        items = []
    has_issues = any(i.get('status') in ('fault_reported', 'missing') for i in items)
    data.check_status = "Voltooi"
    data.items = list(items)

    for item in data.items:
        asset = session.get(Asset, item.get("asset_id"))
        if asset:
            item["asset_name"] = asset.asset_name
            item["asset_serial"] = asset.asset_serial
    return data

@router.post("", response_model=RoomCheckRead, status_code=status.HTTP_201_CREATED)
def create_room_check(
    data: RoomCheckCreate,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("room_checks.manage")),
):
    check = room_check_service.create(session, data, user_id=user.user_id)

    open_session = session.exec(
        select(RoomCheckSession).where(
            RoomCheckSession.room_id == data.room_id,
            RoomCheckSession.status == "scheduled",
        )
    ).first()
    if open_session:
        open_session.status = "completed"
        open_session.room_check_id = check.room_check_id
        if not open_session.scheduled_datetime:
            open_session.scheduled_datetime = check.checked_datetime or datetime.utcnow()
        session.add(open_session)
        session.commit()
        session.refresh(open_session)
    else:
        completed_at = check.checked_datetime or datetime.utcnow()
        session.add(
            RoomCheckSession(
                room_id=data.room_id,
                assigned_user_id=user.user_id,
                scheduled_datetime=completed_at,
                status="completed",
                room_check_id=check.room_check_id,
                created_by=user.user_id,
                notes="Onmiddellike kontrole (geen skedule)",
            )
        )
        session.commit()

    return _to_read(session, check)

@router.get("", response_model=List[RoomCheckRead])
def list_room_checks(
    room_id: int,
    limit: Optional[int] = Query(None),
    session: Session = Depends(getSession),
    _user: User = Depends(require_right("room_checks.manage")),
):
    query = select(room_check_service.model).where(
        room_check_service.model.room_id == room_id
    ).order_by(room_check_service.model.checked_datetime.desc())
    if limit:
        query = query.limit(limit)
    checks = session.exec(query).all()
    return [_to_read(session, check) for check in checks]

def _latest_item_per_asset(session: Session) -> dict:
    """Bou die mees onlangse room-check-item per bate uit al die opsommings.

    Gee 'n mapping {asset_id: (latest_item, room_check)} terug.
    """
    checks = session.exec(select(room_check_service.model).order_by(
        room_check_service.model.checked_datetime.desc()
    )).all()
    latest = {}
    for check in checks:
        try:
            items = json.loads(check.summary or '[]')
        except Exception:
            continue
        for item in items:
            aid = item.get("asset_id")
            if aid is None:
                continue
            if aid not in latest:
                latest[aid] = (item, check)
    return latest


@router.get("/missing", response_model=List[dict])
def list_missing_assets(
    session: Session = Depends(getSession),
    _user: User = Depends(require_any_right("room_checks.manage", "roomchecks.execute")),
):
    """Lys bates waarvan die mees onlangse room-check-item 'vermis' is."""
    latest = _latest_item_per_asset(session)
    result = []
    for asset_id, (item, check) in latest.items():
        if item.get("status") != "missing":
            continue
        asset = session.get(Asset, asset_id)
        if not asset:
            continue
        found_room = session.get(Room, check.room_id) if check.room_id else None
        result.append({
            "asset_id": asset.asset_id,
            "asset_name": asset.asset_name,
            "asset_serial": asset.asset_serial,
            "assigned_room_id": asset.room_id,
            "found_room_id": check.room_id,
            "found_room_name": found_room.room_name if found_room else None,
            "original_fault_id": item.get("fault_id"),
            "latest_checked": check.checked_datetime.isoformat() if check.checked_datetime else None,
        })
    return result


@router.post("/missing-found", response_model=dict)
def mark_missing_found(
    data: MissingFoundIn,
    session: Session = Depends(getSession),
    user: User = Depends(require_any_right("room_checks.manage", "roomchecks.execute")),
):
    """Merk 'n vermiste bate as (verkeerdelik) gevind in 'n ander lokaal.

    Skep/hernu 'n "Bate gevind in verkeerde lokaal"-foutkaartjie en stel die
    kampus-FK en administrateurs in kennis. As daar reeds 'n oop sulke
    foutkaartjie vir die bate is, word dit hergebruik eerder as om 'n dubbel te skep.
    """
    asset = session.get(Asset, data.asset_id)
    if not asset:
        raise HTTPException(status_code=404, detail="Bate nie gevind nie")
    room = session.get(Room, data.room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Lokaal nie gevind nie")

    open_fault = session.exec(
        select(Faultcard).where(
            Faultcard.asset_id == data.asset_id,
            Faultcard.fault_description.like(f"{WRONG_ROOM_FAULT_PREFIX}%"),
            Faultcard.fault_status != FaultStatus.RESOLVED,
        ).order_by(Faultcard.fault_id.desc())
    ).first()

    if not open_fault:
        create = FaultcardCreate(
            fault_description=f"{WRONG_ROOM_FAULT_PREFIX}: {asset.asset_name}",
            fault_type=None,
            fault_status=FaultStatus.WAIT,
            asset_id=asset.asset_id,
            room_id=data.room_id,
            duplicate_of=data.original_fault_id,
        )
        open_fault = fault_service.create(session, create, user_id=user.user_id)
        notif_svc = NotificationService(session)
        notif_svc.notify_admins(
            notification_type="asset.found_wrong_room",
            title="Bate gevind in verkeerde lokaal",
            message=f"{asset.asset_name} gevind in {room.room_name}",
            actor_id=user.user_id,
            reference_type="asset",
            reference_id=asset.asset_id,
        )
        building = session.get(Building, room.building_id) if room.building_id else None
        campus_loc = building.location_id if building else None
        if campus_loc:
            notif_svc.notify_location_users(
                location_id=campus_loc,
                notification_type="asset.found_wrong_room",
                title="Bate gevind in verkeerde lokaal",
                message=f"{asset.asset_name} (lokaal {room.room_name})",
                actor_id=user.user_id,
                reference_type="asset",
                reference_id=asset.asset_id,
            )

    return {
        "asset_id": asset.asset_id,
        "asset_name": asset.asset_name,
        "fault_id": open_fault.fault_id,
        "found_room_id": data.room_id,
        "found_room_name": room.room_name,
    }


def _asset_state(session: Session, asset) -> dict:
    """Bereken die "toestand" van 'n bate oor room-checks en verkeerde-lokaal-foute heen.

    1. Oop "gevind in verkeerde lokaal"-foutkaartjie  → state=wrong_room
    2. Mees onlangse room-check-item 'vermis'          → state=missing
    3. Anders                                          → state=clear
    """
    open_fault = session.exec(
        select(Faultcard).where(
            Faultcard.asset_id == asset.asset_id,
            Faultcard.fault_description.like(f"{WRONG_ROOM_FAULT_PREFIX}%"),
            Faultcard.fault_status != FaultStatus.RESOLVED,
        ).order_by(Faultcard.fault_id.desc())
    ).first()
    if open_fault:
        found_room = session.get(Room, open_fault.room_id) if open_fault.room_id else None
        return {
            "asset_id": asset.asset_id,
            "state": "wrong_room",
            "found_room_id": open_fault.room_id,
            "found_room_name": found_room.room_name if found_room else None,
            "fault_id": open_fault.fault_id,
            "original_fault_id": open_fault.duplicate_of,
        }

    latest = _latest_item_per_asset(session)
    item, check = latest.get(asset.asset_id, (None, None))
    if item and item.get("status") == "missing":
        found_room = session.get(Room, check.room_id) if check and check.room_id else None
        return {
            "asset_id": asset.asset_id,
            "state": "missing",
            "found_room_id": check.room_id if check else None,
            "found_room_name": found_room.room_name if found_room else None,
            "fault_id": item.get("fault_id"),
            "original_fault_id": None,
        }

    return {"asset_id": asset.asset_id, "state": "clear"}


@router.get("/asset-state/{asset_id}", response_model=dict)
def get_asset_state(
    asset_id: int,
    session: Session = Depends(getSession),
    _user: User = Depends(get_current_user),
):
    """Gee die vermis/verkeerde-lokaal-toestand vir 'n enkele bate."""
    asset = session.get(Asset, asset_id)
    if not asset:
        raise HTTPException(status_code=404, detail="Bate nie gevind nie")
    return _asset_state(session, asset)

@router.get("/{check_id}", response_model=RoomCheckRead)
def get_room_check(
    check_id: int,
    session: Session = Depends(getSession),
    _user: User = Depends(require_right("room_checks.manage")),
):
    check = room_check_service.getByID(session, check_id)
    if not check:
        raise HTTPException(status_code=404, detail="Room check not found")
    return _to_read(session, check)
