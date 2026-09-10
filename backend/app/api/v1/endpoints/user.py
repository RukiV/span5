from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List

from ....auth.permissions import require_right, require_any_right
from ....auth.rights_catalog import ROLE_ADMIN, ROLE_FK
from ....db.database import getSession
from ....models.user import UserRead, UserCreate, UserUpdate, User
from ....services.user_service import user_service

router = APIRouter()

@router.get("", response_model=List[UserRead])
def readUsers(session: Session = Depends(getSession), current: User = Depends(require_right("users.view"))):
    users = user_service.getAll(session)
    if current.role_id != ROLE_ADMIN:
        users = [u for u in users if u.role_id != ROLE_ADMIN]
    return users

@router.get("/assignable", response_model=List[UserRead])
def readAssignableUsers(session: Session = Depends(getSession), _user: User = Depends(require_any_right("jobs.view", "quotes.view", "room_checks.manage"))):
    #Users that can be assigned to work orders, chosen as quote contractors, or assigned room check sessions
    return session.exec(select(User).order_by(User.user_name, User.user_surname)).all()

@router.post("/contractors", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def addContractor(userIn: UserCreate, session: Session = Depends(getSession), current: User = Depends(require_right("contractors.manage"))):
    #Create a new contractor user (role_id = 4). Gated by contractors.manage so
    #FK's (who manage quotes/contractors but not users) can add name-only
    #contractors straight from a quote.
    userIn = userIn.model_copy(update={"role_id": 4})
    return user_service.create(session, userIn, user_id=current.user_id)

@router.get("/{userID}", response_model=UserRead)
def readUser(userID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("users.view"))):
    #Fetch single user by id
    user = user_service.getByID(session, userID)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return user

@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def addUser(userIn: UserCreate, session: Session = Depends(getSession), current: User = Depends(require_right("users.manage"))):
    if current.role_id != ROLE_ADMIN and userIn.role_id in (ROLE_ADMIN, ROLE_FK):
        raise HTTPException(status_code=403, detail="Kan nie 'n gebruiker met hierdie rol skep nie")
    return user_service.create(session, userIn, user_id=current.user_id)

@router.patch("/{userID}", response_model=UserRead)
def patchUser(userID: int, userIn: UserUpdate, session: Session = Depends(getSession), current: User = Depends(require_right("users.manage"))):
    user = user_service.getByID(session, userID)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if current.role_id != ROLE_ADMIN and user.role_id == ROLE_ADMIN:
        raise HTTPException(status_code=403, detail="Kan nie 'n administrateur wysig nie")
    if current.role_id != ROLE_ADMIN and userIn.role_id in (ROLE_ADMIN, ROLE_FK):
        raise HTTPException(status_code=403, detail="Kan nie hierdie rol toewys nie")
    updated = user_service.update(session, userID, userIn, user_id=current.user_id)
    return updated

@router.delete("/{userID}", status_code=status.HTTP_204_NO_CONTENT)
def removeuser(userID: int, session: Session = Depends(getSession), current: User = Depends(require_right("users.manage"))):
    user = user_service.getByID(session, userID)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if current.role_id != ROLE_ADMIN and user.role_id == ROLE_ADMIN:
        raise HTTPException(status_code=403, detail="Kan nie 'n administrateur verwyder nie")
    if not user_service.delete(session, userID, user_id=current.user_id):
        raise HTTPException(status_code=404, detail="User not found")
    return None
