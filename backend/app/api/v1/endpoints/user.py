<<<<<<< HEAD
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List

from ....auth.permissions import require_right, require_any_right
from ....db.database import getSession
from ....models.user import UserRead, UserCreate, UserUpdate, User
from ....services.user_service import user_service

router = APIRouter()

@router.get("", response_model=List[UserRead])
def readUsers(session: Session = Depends(getSession), _user: User = Depends(require_right("users.view"))):
    #Fetch all users
    return user_service.getAll(session)

@router.get("/assignable", response_model=List[UserRead])
def readAssignableUsers(session: Session = Depends(getSession), _user: User = Depends(require_any_right("jobs.view", "quotes.view", "room_checks.manage"))):
    #Users that can be assigned to work orders, chosen as quote contractors, or assigned room check sessions
    return session.exec(select(User).order_by(User.user_name, User.user_surname)).all()

@router.get("/{userID}", response_model=UserRead)
def readUser(userID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("users.view"))):
    #Fetch single user by id
    user = user_service.getByID(session, userID)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return user

@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def addUser(userIn: UserCreate, session: Session = Depends(getSession), current: User = Depends(require_right("users.manage"))):
    #Create new user
    return user_service.create(session, userIn, user_id=current.user_id)

@router.patch("/{userID}", response_model=UserRead)
def patchUser(userID: int, userIn: UserUpdate, session: Session = Depends(getSession), current: User = Depends(require_right("users.manage"))):
    #Update existing user
    user = user_service.update(session, userID, userIn, user_id=current.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return user

@router.delete("/{userID}", status_code=status.HTTP_204_NO_CONTENT)
def removeuser(userID: int, session: Session = Depends(getSession), current: User = Depends(require_right("users.manage"))):
    #Delete user
    if not user_service.delete(session, userID, user_id=current.user_id):
        raise HTTPException(status_code=404, detail="User not found")

    return None
=======
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.dependencies import get_current_user_id
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
def addUser(userIn: UserCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Create new user
    return user_service.create(session, userIn, user_id=user_id)
    
@router.patch("/{userID}", response_model=UserRead)
def patchUser(userID: int, userIn: UserUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Update existing user
    user = user_service.update(session, userID, userIn, user_id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return user

@router.delete("/{userID}", status_code=status.HTTP_204_NO_CONTENT)
def removeuser(userID: int, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Delete user
    if not user_service.delete(session, userID, user_id=user_id):
        raise HTTPException(status_code=404, detail="User not found")
    
    return None
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
