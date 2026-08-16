from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select
from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.room_check import RoomCheckRead, RoomCheckCreate
from ....models.user import User
from ....services.room_check_service import room_check_service

router = APIRouter()

@router.post("", response_model=RoomCheckRead, status_code=status.HTTP_201_CREATED)
def create_room_check(
    data: RoomCheckCreate,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("room_checks.manage")),
):
    return room_check_service.create(session, data, user_id=user.user_id)

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
    return session.exec(query).all()

@router.get("/{check_id}", response_model=RoomCheckRead)
def get_room_check(
    check_id: int,
    session: Session = Depends(getSession),
    _user: User = Depends(require_right("room_checks.manage")),
):
    check = room_check_service.getByID(session, check_id)
    if not check:
        raise HTTPException(status_code=404, detail="Room check not found")
    return check
