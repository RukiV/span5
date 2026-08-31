from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

<<<<<<< HEAD
from ....auth.permissions import require_right, require_any_right
=======
from ....auth.dependencies import get_current_user_id
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
from ....db.database import getSession
from ....models.location import BuildingRead, BuildingCreate, BuildingUpdate
from ....services.building_service import building_service

router = APIRouter()

@router.get("", response_model=List[BuildingRead])
<<<<<<< HEAD
def readBuildings(session: Session = Depends(getSession), _user: User = Depends(require_any_right("buildings.view", "faults.create"))):
    return building_service.getAll(session)

@router.get("/{buildingID}", response_model=BuildingRead)
def readBuilding(buildingID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("buildings.view"))):
=======
def readBuildings(session: Session = Depends(getSession)):
    return building_service.getAll(session)

@router.get("/{buildingID}", response_model=BuildingRead)
def readBuilding(buildingID: int, session: Session = Depends(getSession)):
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
    building = building_service.getByID(session, buildingID)
    if not building:
        raise HTTPException(status_code=404, detail="Building not found")

    return building

@router.post("", response_model=BuildingRead, status_code=status.HTTP_201_CREATED)
def addBuilding(buildingIn: BuildingCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    return building_service.create(session, buildingIn, user_id=user_id)

@router.patch("/{buildingID}", response_model=BuildingRead)
def patchBuilding(buildingID: int, buildingIn: BuildingUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    building = building_service.update(session, buildingID, buildingIn, user_id=user_id)
    if not building:
        raise HTTPException(status_code=404, detail="Building not found")

    return building

@router.delete("/{buildingID}", status_code=status.HTTP_204_NO_CONTENT)
def removeBuilding(buildingID: int, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    if not building_service.delete(session, buildingID, user_id=user_id):
        raise HTTPException(status_code=404, detail="Building not found")

    return None
