from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List

from ....auth.permissions import require_right, require_any_right
from ....db.database import getSession
from ....models.location import LocationRead, LocationCreate, LocationUpdate
from ....models.user import User
from ....services.location_service import location_service
from ....services.cascade_delete_service import delete_location_cascade

router = APIRouter()


@router.get("", response_model=List[LocationRead])
def readLocations(session: Session = Depends(getSession), _user: User = Depends(require_any_right("locations.view", "faults.create"))):
    return location_service.getAll(session)


@router.get("/{locationID}", response_model=LocationRead)
def readLocation(locationID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("locations.view"))):
    location = location_service.getByID(session, locationID)
    if not location:
        raise HTTPException(status_code=404, detail="Location not found")
    return location


@router.post("", response_model=LocationRead, status_code=status.HTTP_201_CREATED)
def addLocation(locationIn: LocationCreate, session: Session = Depends(getSession), user: User = Depends(require_right("locations.manage"))):
    return location_service.create(session, locationIn, user_id=user.user_id)


@router.patch("/{locationID}", response_model=LocationRead)
def patchLocation(locationID: int, locationIn: LocationUpdate, session: Session = Depends(getSession), user: User = Depends(require_right("locations.manage"))):
    location = location_service.update(session, locationID, locationIn, user_id=user.user_id)
    if not location:
        raise HTTPException(status_code=404, detail="Location not found")
    return location


@router.delete("/{locationID}", status_code=status.HTTP_204_NO_CONTENT)
def removeLocation(locationID: int, session: Session = Depends(getSession), user: User = Depends(require_right("locations.manage"))):
    if not delete_location_cascade(session, locationID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Location not found")
    return None
