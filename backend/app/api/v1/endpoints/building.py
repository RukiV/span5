from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.location import BuildingRead, BuildingCreate, BuildingUpdate
from ....models.user import User
from ....services.building_service import building_service

router = APIRouter()

@router.get("", response_model=List[BuildingRead])
def readBuildings(session: Session = Depends(getSession), _user: User = Depends(require_right("buildings.manage"))):
    return building_service.getAll(session)

@router.get("/{buildingID}", response_model=BuildingRead)
def readBuilding(buildingID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("buildings.manage"))):
    building = building_service.getByID(session, buildingID)
    if not building:
        raise HTTPException(status_code=404, detail="Building not found")

    return building

@router.post("", response_model=BuildingRead, status_code=status.HTTP_201_CREATED)
def addBuilding(buildingIn: BuildingCreate, session: Session = Depends(getSession), user: User = Depends(require_right("buildings.manage"))):
    return building_service.create(session, buildingIn, user_id=user.user_id)

@router.patch("/{buildingID}", response_model=BuildingRead)
def patchBuilding(buildingID: int, buildingIn: BuildingUpdate, session: Session = Depends(getSession), user: User = Depends(require_right("buildings.manage"))):
    building = building_service.update(session, buildingID, buildingIn, user_id=user.user_id)
    if not building:
        raise HTTPException(status_code=404, detail="Building not found")

    return building

@router.delete("/{buildingID}", status_code=status.HTTP_204_NO_CONTENT)
def removeBuilding(buildingID: int, session: Session = Depends(getSession), user: User = Depends(require_right("buildings.manage"))):
    if not building_service.delete(session, buildingID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Building not found")

    return None
