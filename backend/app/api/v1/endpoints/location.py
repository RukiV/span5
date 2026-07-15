from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.location import LocationRead, LocationCreate, LocationUpdate
from ....services.location_service import location_service

router = APIRouter()


@router.get("", response_model=List[LocationRead])
def readLocations(session: Session = Depends(getSession)):
    return location_service.getAll(session)


@router.get("/{locationID}", response_model=LocationRead)
def readLocation(locationID: int, session: Session = Depends(getSession)):
    location = location_service.getByID(session, locationID)
    if not location:
        raise HTTPException(status_code=404, detail="Location not found")
    return location


@router.post("", response_model=LocationRead, status_code=status.HTTP_201_CREATED)
def addLocation(locationIn: LocationCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    return location_service.create(session, locationIn, user_id=user_id)


@router.patch("/{locationID}", response_model=LocationRead)
def patchLocation(locationID: int, locationIn: LocationUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    location = location_service.update(session, locationID, locationIn, user_id=user_id)
    if not location:
        raise HTTPException(status_code=404, detail="Location not found")
    return location


@router.delete("/{locationID}", status_code=status.HTTP_204_NO_CONTENT)
def removeLocation(locationID: int, session: Session = Depends(getSession)):
    if not location_service.delete(session, locationID):
        raise HTTPException(status_code=404, detail="Location not found")
    return None
