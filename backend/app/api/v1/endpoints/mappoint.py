from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.permissions import require_right, require_any_right
from ....db.database import getSession
from ....models.mappoint import MappointRead, MappointCreate, MappointUpdate
from ....models.user import User
from ....services.mappoint_service import mappoint_service

router = APIRouter()


@router.get("", response_model=List[MappointRead])
def readMappoints(session: Session = Depends(getSession), _user: User = Depends(require_any_right("assets.view", "faults.create", "jobs.view"))):
    return mappoint_service.getAll(session)


@router.get("/{mappointID}", response_model=MappointRead)
def readMappoint(mappointID: int, session: Session = Depends(getSession), _user: User = Depends(require_any_right("assets.view", "faults.create", "jobs.view"))):
    mappoint = mappoint_service.getByID(session, mappointID)
    if not mappoint:
        raise HTTPException(status_code=404, detail="Mappoint not found")
    return mappoint


@router.post("", response_model=MappointRead, status_code=status.HTTP_201_CREATED)
def addMappoint(mappointIn: MappointCreate, session: Session = Depends(getSession), user: User = Depends(require_any_right("assets.manage", "faults.create", "jobs.manage"))):
    return mappoint_service.create(session, mappointIn, user_id=user.user_id)


@router.patch("/{mappointID}", response_model=MappointRead)
def patchMappoint(mappointID: int, mappointIn: MappointUpdate, session: Session = Depends(getSession), user: User = Depends(require_right("assets.manage"))):
    mappoint = mappoint_service.update(session, mappointID, mappointIn, user_id=user.user_id)
    if not mappoint:
        raise HTTPException(status_code=404, detail="Mappoint not found")
    return mappoint


@router.delete("/{mappointID}", status_code=status.HTTP_204_NO_CONTENT)
def removeMappoint(mappointID: int, session: Session = Depends(getSession), user: User = Depends(require_right("assets.manage"))):
    if not mappoint_service.delete(session, mappointID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Mappoint not found")
    return None
