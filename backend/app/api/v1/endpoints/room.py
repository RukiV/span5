from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from sqlmodel import select

from ....auth.permissions import require_right, require_any_right
from ....db.database import getSession
from ....models.location import Room, Building, RoomRead, RoomWithPathRead, RoomCreate, RoomUpdate
from ....models.user import User
from ....services.room_service import room_service
from ....services.cascade_delete_service import delete_room_cascade

router = APIRouter()

@router.get("", response_model=List[RoomRead])
def readRooms(session: Session = Depends(getSession), _user: User = Depends(require_any_right("rooms.view", "faults.create"))):
    #Fetch all rooms
    return room_service.getAll(session)

@router.get("/code/{code}", response_model=RoomWithPathRead)
def readRoomByCode(code: str, session: Session = Depends(getSession), _user: User = Depends(require_any_right("rooms.view", "faults.create"))):
    #Fetch a single room by its scannable room_code, including the campus path.
    room = session.exec(select(Room).where(Room.room_code == code)).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    building = session.get(Building, room.building_id)
    location_id = building.location_id if building else None
    return RoomWithPathRead(
        room_id=room.room_id,
        building_id=room.building_id,
        location_id=location_id,
        room_name=room.room_name,
        room_code=room.room_code,
        room_capacity=room.room_capacity,
        room_type=room.room_type,
        room_status=room.room_status,
    )

@router.get("/{roomID}", response_model=RoomRead)
def readRoom(roomID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("rooms.view"))):
    #Fetch single room by id
    room = room_service.getByID(session, roomID)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    return room

@router.post("/{roomID}/code", response_model=RoomRead)
def ensureRoomCode(roomID: int, session: Session = Depends(getSession), user: User = Depends(require_right("rooms.manage"))):
    #Generate a scannable room_code if the room does not yet have one.
    room = session.get(Room, roomID)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    if not room.room_code:
        room.room_code = f"R{room.room_id}"
        session.add(room)
        session.commit()
        session.refresh(room)
    return room

@router.post("", response_model=RoomRead, status_code=status.HTTP_201_CREATED)
def addRoom(roomIn: RoomCreate, session: Session = Depends(getSession), user: User = Depends(require_right("rooms.manage"))):
    #Create new room
    return room_service.create(session, roomIn, user_id=user.user_id)

@router.patch("/{roomID}", response_model=RoomRead)
def patchRoom(roomID: int, roomIn: RoomUpdate, session: Session = Depends(getSession), user: User = Depends(require_right("rooms.manage"))):
    #Update existing room
    room = room_service.update(session, roomID, roomIn, user_id=user.user_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    return room

@router.delete("/{roomID}", status_code=status.HTTP_204_NO_CONTENT)
def removeRoom(roomID: int, session: Session = Depends(getSession), user: User = Depends(require_right("rooms.manage"))):
    #Delete room (cascade: clean checklist history, unlink dependents)
    if not delete_room_cascade(session, roomID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Room not found")

    return None
