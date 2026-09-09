from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session

from ....auth.permissions import require_right
from ....auth.rights_catalog import BUILTIN_RIGHT_NAMES
from ....db.database import getSession
from ....models.role import Rights, RightsRead, RightsUpdate
from ....models.user import User
from ....services.rights_service import rights_service

router = APIRouter()


# Response model for the management UI: right + whether it's a protected built-in.
class RightManageRead(RightsRead):
    is_builtin: bool = False


def _to_manage_read(right: Rights) -> RightManageRead:
    return RightManageRead(**right.model_dump(), is_builtin=right.right_name in BUILTIN_RIGHT_NAMES)


@router.get("", response_model=List[RightManageRead])
def readRights(session: Session = Depends(getSession), _user: User = Depends(require_right("rights.manage"))):
    return [_to_manage_read(right) for right in rights_service.getAll(session)]


@router.get("/{rightID}", response_model=RightManageRead)
def readRight(rightID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("rights.manage"))):
    right = rights_service.getByID(session, rightID)
    if not right:
        raise HTTPException(status_code=404, detail="Right not found")
    return _to_manage_read(right)


@router.patch("/{rightID}", response_model=RightManageRead)
def patchRight(rightID: int, rightIn: RightsUpdate, session: Session = Depends(getSession), current: User = Depends(require_right("rights.manage"))):
    right = rights_service.getByID(session, rightID)
    if not right:
        raise HTTPException(status_code=404, detail="Right not found")
    if right.right_name in BUILTIN_RIGHT_NAMES:
        raise HTTPException(status_code=403, detail="Built-in rights cannot be modified.")
    updated = rights_service.update(session, rightID, rightIn, user_id=current.user_id)
    return _to_manage_read(updated)


@router.delete("/{rightID}", status_code=status.HTTP_204_NO_CONTENT)
def removeRight(rightID: int, session: Session = Depends(getSession), current: User = Depends(require_right("rights.manage"))):
    right = rights_service.getByID(session, rightID)
    if not right:
        raise HTTPException(status_code=404, detail="Right not found")
    if right.right_name in BUILTIN_RIGHT_NAMES:
        raise HTTPException(status_code=403, detail="Built-in rights cannot be deleted.")
    rights_service.delete(session, rightID, user_id=current.user_id)
    return None
