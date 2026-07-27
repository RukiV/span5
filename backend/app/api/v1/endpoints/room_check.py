from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List
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
    user: User = Depends(require_right("assets.manage")),
):
    return room_check_service.create(session, data, user_id=user.user_id)

@router.get("", response_model=List[RoomCheckRead])
def list_room_checks(
    room_id: int,
    session: Session = Depends(getSession),
    _user: User = Depends(require_right("assets.manage")),
):
    from sqlmodel import select
    return session.exec(
        select(room_check_service.model).where(room_check_service.model.room_id == room_id)
    ).all()

@router.get("/{check_id}", response_model=RoomCheckRead)
def get_room_check(
    check_id: int,
    session: Session = Depends(getSession),
    _user: User = Depends(require_right("assets.manage")),
):
    check = room_check_service.getByID(session, check_id)
    if not check:
        raise HTTPException(status_code=404, detail="Room check not found")
    return check
