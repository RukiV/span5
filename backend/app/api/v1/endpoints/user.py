from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....db.database import getSession
from ....models.user import UserRead, UserCreate, UserUpdate
from ....services.user_service import user_service

router = APIRouter()

@router.get("", response_model=List[UserRead])
def readUsers(session: Session = Depends(getSession)):
    #Fetch all users
    return user_service.getAll(session)

@router.get("/{userID}", response_model=UserRead)
def readUser(userID: int, session: Session = Depends(getSession)):
    #Fetch single user by id
    user = user_service.getByID(session, userID)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return user

@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def addUser(userIn: UserCreate, session: Session = Depends(getSession)):
    #Create new user
    return user_service.create(session, userIn)
    
@router.patch("/{userID}", response_model=UserRead)
def patchUser(userID: int, userIn: UserUpdate, session: Session = Depends(getSession)):
    #Update existing user
    user = user_service.update(session, userID, userIn)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return user

@router.delete("/{userID}", status_code=status.HTTP_204_NO_CONTENT)
def removeuser(userID: int, session: Session = Depends(getSession)):
    #Delete user
    if not user_service.delete(session, userID):
        raise HTTPException(status_code=404, detail="User not found")
    
    return None