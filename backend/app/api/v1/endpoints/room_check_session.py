from typing import List, Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select
from ....auth.permissions import require_any_right, require_right, user_has_right
from ....db.database import getSession
from ....models.room_check import RoomCheck
from ....models.room_check_session import (
    RoomCheckSession,
    RoomCheckSessionCreate,
    RoomCheckSessionRead,
    RoomCheckSessionUpdate,
)
from ....models.calendar_event import CalendarEvent, CalendarEventCreate, CalendarEventUpdate
from ....models.location import Room
from ....models.user import User
from ....services.calendar_service import calendar_service
from ....services.notification_service import NotificationService
from ....services.room_check_session_service import room_check_session_service

router = APIRouter()

_EVENT_COLOR = "#00796B"
_EVENT_TITLE = "Lokaal Kontrole"


def _to_read(session: Session, obj: RoomCheckSession) -> RoomCheckSessionRead:
    data = RoomCheckSessionRead.model_validate(obj)
    room = session.get(Room, obj.room_id)
    if room:
        data.room_name = room.room_name
    user = session.get(User, obj.assigned_user_id)
    if user:
        data.assigned_user_name = f"{user.user_name} {user.user_surname}".strip()
    if obj.room_check_id is not None:
        check = session.get(RoomCheck, obj.room_check_id)
        if check:
            data.completed_datetime = check.checked_datetime
    return data


def _build_event(room_name: str, scheduled: Optional[datetime]) -> CalendarEventCreate:
    start = scheduled or datetime.utcnow()
    return CalendarEventCreate(
        title=_EVENT_TITLE,
        description=f"Lokaal kontrole geskeduleer vir {room_name}",
        start_datetime=start,
        end_datetime=start + timedelta(hours=1),
        all_day=False,
        color=_EVENT_COLOR,
        notify_email=False,
        reminder_minutes=60,
    )


@router.post("", response_model=RoomCheckSessionRead, status_code=status.HTTP_201_CREATED)
def create_session(
    data: RoomCheckSessionCreate,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("room_checks.manage")),
):
    room = session.get(Room, data.room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    existing = session.exec(
        select(RoomCheckSession).where(
            RoomCheckSession.room_id == data.room_id,
            RoomCheckSession.status == "scheduled",
        )
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail="Hierdie lokaal het reeds 'n aktiewe skedule. Wysig die bestaande skedule eerder.",
        )

    event = calendar_service.create(session, _build_event(room.room_name, data.scheduled_datetime), user_id=data.assigned_user_id)

    obj = RoomCheckSession.model_validate(data)
    obj.calendar_event_id = event.event_id
    obj.created_by = user.user_id
    session.add(obj)
    session.commit()
    session.refresh(obj)

    try:
        NotificationService(session).create_notification(
            user_id=data.assigned_user_id,
            notification_type="roomcheck.assigned",
            title="Lokaal Kontrole Toegewys",
            message=f"Jy is aangestel vir 'n lokaal kontrole van {room.room_name}",
            actor_id=user.user_id,
            reference_type="room_check_session",
            reference_id=obj.session_id,
        )
    except Exception:
        session.rollback()

    return _to_read(session, obj)


@router.get("", response_model=List[RoomCheckSessionRead])
def list_sessions(
    assigned_user_id: Optional[int] = Query(None),
    room_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    session: Session = Depends(getSession),
    user: User = Depends(require_any_right("room_checks.manage", "roomchecks.execute")),
):
    query = select(RoomCheckSession).order_by(RoomCheckSession.scheduled_datetime.desc())
    if assigned_user_id is not None:
        query = query.where(RoomCheckSession.assigned_user_id == assigned_user_id)
    if room_id is not None:
        query = query.where(RoomCheckSession.room_id == room_id)
    if status is not None:
        query = query.where(RoomCheckSession.status == status)
    if user_has_right(session, user.role_id, "roomchecks.execute") and not user_has_right(session, user.role_id, "room_checks.manage"):
        query = query.where(RoomCheckSession.assigned_user_id == user.user_id)
    items = session.exec(query).all()
    return [_to_read(session, obj) for obj in items]


@router.patch("/{session_id}", response_model=RoomCheckSessionRead)
def update_session(
    session_id: int,
    data: RoomCheckSessionUpdate,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("room_checks.manage")),
):
    obj = room_check_session_service.getByID(session, session_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Session not found")

    if data.assigned_user_id is not None and data.assigned_user_id != obj.assigned_user_id:
        if obj.calendar_event_id is not None:
            calendar_service.update(
                session,
                obj.calendar_event_id,
                CalendarEventUpdate(user_id=data.assigned_user_id),
                user_id=user.user_id,
            )
        try:
            NotificationService(session).create_notification(
                user_id=data.assigned_user_id,
                notification_type="roomcheck.assigned",
                title="Lokaal Kontrole Wysig",
                message=f"Lokaal kontrole is wysig aan jou (skedule #{session_id})",
                actor_id=user.user_id,
                reference_type="room_check_session",
                reference_id=session_id,
            )
        except Exception:
            session.rollback()

    obj = room_check_session_service.update(session, session_id, data, user_id=user.user_id)
    return _to_read(session, obj)


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_session(
    session_id: int,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("room_checks.manage")),
):
    obj = room_check_session_service.getByID(session, session_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Session not found")
    if obj.calendar_event_id is not None:
        calendar_service.delete(session, obj.calendar_event_id, user_id=user.user_id)
    room_check_session_service.delete(session, session_id, user_id=user.user_id)
    return None


@router.post("/{session_id}/complete", response_model=RoomCheckSessionRead)
def complete_session(
    session_id: int,
    session: Session = Depends(getSession),
    user: User = Depends(require_any_right("room_checks.manage", "roomchecks.execute")),
):
    obj = room_check_session_service.getByID(session, session_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Session not found")
    if obj.status == "completed":
        return _to_read(session, obj)

    obj.status = "completed"
    session.add(obj)
    session.commit()
    session.refresh(obj)
    return _to_read(session, obj)
