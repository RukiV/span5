import json
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select
from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.room_check import RoomCheckRead, RoomCheckCreate
from ....models.room_check_session import RoomCheckSession
from ....models.user import User
from ....services.room_check_service import room_check_service

router = APIRouter()

def _to_read(session: Session, check) -> RoomCheckRead:
    data = RoomCheckRead.model_validate(check)
    if check.user_id:
        user = session.get(User, check.user_id)
        if user:
            data.user_name = f"{user.user_name} {user.user_surname}".strip()
    try:
        items = json.loads(check.summary or '[]')
        has_issues = any(i.get('status') in ('fault_reported', 'missing') for i in items)
        data.check_status = "Onvoltooi" if has_issues else "Voltooi"
    except Exception:
        data.check_status = "Onvoltooi"
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
        session.add(open_session)
        session.commit()
        session.refresh(open_session)

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
