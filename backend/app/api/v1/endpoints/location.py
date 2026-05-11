from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....db.database import getSession
from ....models.location import JobcardRead, JobcardCreate, JobcardUpdate
from ....services.location_service import location_service

router = APIRouter()

@router.get("/", response_model=List[JobcardRead])
def readLocations(session: Session = Depends(getSession)):
    #Fetch all locations
    return location_service.getAll(Session)

@router.get("/{locationID}", response_model=JobcardRead)
def readLocation(locationID: int, session: Session = Depends(getSession)):
    #Fetch single location by id
    location = location_service.getByID(session, locationID)
    if not location:
        raise HTTPException(status_code=404, detail="Location not found")
    
    return location

@router.post("/", response_model=JobcardRead, status_code=status.HTTP_201_CREATED)
def addLocation(locationIn: JobcardCreate, session: Session = Depends(getSession)):
    #Create new location
    return location_service.create(session, locationIn)

@router.patch("/{locationID}", response_model=JobcardRead)
def patchLocation(locationID: int, locationIn: JobcardUpdate, session: Session = Depends(getSession)):
    #Update existing location
    location = location_service.update(session, locationID, locationIn)
    if not location:
        raise HTTPException(status_code=404, detail="Location not found")
    
    return location

@router.delete("/{locationID}", status_code=status.HTTP_204_NO_CONTENT)
def removeLocation(locationID: int, session: Session =Depends(getSession)):
    #Delete location
    if not location_service.delete(session, locationID):
        raise HTTPException(status_code=404, detail="Location not found")
    
    return None