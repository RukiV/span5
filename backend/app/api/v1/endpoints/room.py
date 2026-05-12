from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....db.database import getSession
from ....models.location import RoomRead, RoomCreate, RoomUpdate
from ....services.room_service import room_service

router = APIRouter()

@router.get("", response_model=List[RoomRead])
def readRooms(session: Session = Depends(getSession)):
    #Fetch all rooms
    return room_service.getAll(session)

@router.get("/{roomID}", response_model=RoomRead)
def readRoom(roomID: int, session: Session = Depends(getSession)):
    #Fetch single room by id
    room = room_service.getByID(session, roomID)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    return room

@router.post("", response_model=RoomRead, status_code=status.HTTP_201_CREATED)
def addRoom(roomIn: RoomCreate, session: Session = Depends(getSession)):
    #Create new room
    return room_service.create(session, roomIn)

@router.patch("/{roomID}", response_model=RoomRead)
def patchRoom(roomID: int, roomIn: RoomUpdate, session: Session = Depends(getSession)):
    #Update existing room
    room = room_service.update(session, roomID, roomIn)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    return room

@router.delete("/{roomID}", status_code=status.HTTP_204_NO_CONTENT)
def removeRoom(roomID: int, session: Session =Depends(getSession)):
    #Delete room
    if not room_service.delete(session, roomID):
        raise HTTPException(status_code=404, detail="Room not found")
    
    return None