from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.calendar_event import CalendarEventRead, CalendarEventCreate, CalendarEventUpdate
from ....models.user import User
from ....services.calendar_service import calendar_service
from ....services.email_service import send_event_created

router = APIRouter()

@router.get("/events", response_model=List[dict])
def read_calendar_events(
    start: str = Query(..., description="ISO start datum"),
    end: str = Query(..., description="ISO end datum"),
    session: Session = Depends(getSession),
):
    try:
        start_dt = datetime.fromisoformat(start)
        end_dt = datetime.fromisoformat(end)
    except ValueError:
        raise HTTPException(status_code=400, detail="Ongeldige datum formaat. Gebruik ISO formaat (YYYY-MM-DD)")

    return calendar_service.get_events_in_range(session, start_dt, end_dt)

@router.get("/events/{event_id}", response_model=CalendarEventRead)
def read_calendar_event(event_id: int, session: Session = Depends(getSession)):
    event = calendar_service.getByID(session, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event nie gevind nie")
    return event

@router.post("/events", response_model=CalendarEventRead, status_code=status.HTTP_201_CREATED)
def create_calendar_event(
    event_in: CalendarEventCreate,
    session: Session = Depends(getSession),
    user_id: int | None = Depends(get_current_user_id),
):
    event = calendar_service.create(session, event_in, user_id=user_id)
    if user_id and event.notify_email:
        user = session.get(User, user_id)
        if user and user.user_email:
            send_event_created(
                to_email=user.user_email,
                event_title=event.title,
                start_datetime_str=event.start_datetime.strftime("%Y-%m-%d %H:%M"),
                location=event.location or "",
                description=event.description or "",
            )
    return event

@router.patch("/events/{event_id}", response_model=CalendarEventRead)
def update_calendar_event(
    event_id: int,
    event_in: CalendarEventUpdate,
    session: Session = Depends(getSession),
    user_id: int | None = Depends(get_current_user_id),
):
    event = calendar_service.update(session, event_id, event_in, user_id=user_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event nie gevind nie")
    return event

@router.delete("/events/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_calendar_event(
    event_id: int,
    session: Session = Depends(getSession),
    user_id: int | None = Depends(get_current_user_id),
):
    if not calendar_service.delete(session, event_id, user_id=user_id):
        raise HTTPException(status_code=404, detail="Event nie gevind nie")
