from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlmodel import Session, select

from ....auth.permissions import require_right
from ....auth.rights_catalog import BUILTIN_ROLE_IDS, ROLE_ADMIN, ROLE_FK
from ....db.database import getSession
from ....models.role import Role, RoleRead, RoleCreate, RoleUpdate
from ....models.user import User
from ....services.role_service import role_service

router = APIRouter()


# Response model for the management UI: role + whether it's a protected built-in
# + the ids of the rights currently assigned to it (so the UI can pre-check the
# rights checkboxes in one round-trip).
class RoleManageRead(RoleRead):
    is_builtin: bool = False
    right_ids: List[int] = []


class RoleManageCreate(RoleCreate):
    right_ids: Optional[List[int]] = None


class RoleManageUpdate(RoleUpdate):
    right_ids: Optional[List[int]] = None


class RoleRightsUpdate(BaseModel):
    right_ids: List[int]


def _to_manage_read(session: Session, role: Role) -> RoleManageRead:
    right_ids = sorted(role_service.get_right_ids(session, role.role_id))
    return RoleManageRead(
        **role.model_dump(),
        is_builtin=role.role_id in BUILTIN_ROLE_IDS,
        right_ids=right_ids,
    )


@router.get("", response_model=List[RoleManageRead])
def readRoles(session: Session = Depends(getSession), _user: User = Depends(require_right("roles.manage"))):
    return [_to_manage_read(session, role) for role in role_service.getAll(session)]


@router.get("/{roleID}", response_model=RoleManageRead)
def readRole(roleID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("roles.manage"))):
    role = role_service.getByID(session, roleID)
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    return _to_manage_read(session, role)


@router.get("/{roleID}/rights", response_model=List[int])
def readRoleRights(roleID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("roles.manage"))):
    role = role_service.getByID(session, roleID)
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    return sorted(role_service.get_right_ids(session, roleID))


@router.post("", response_model=RoleManageRead, status_code=status.HTTP_201_CREATED)
def addRole(roleIn: RoleManageCreate, session: Session = Depends(getSession), current: User = Depends(require_right("roles.manage"))):
    role = role_service.create(session, RoleCreate(role_name=roleIn.role_name), user_id=current.user_id)
    new_id = role.role_id
    if roleIn.right_ids is not None:
        try:
            role_service.set_rights(session, new_id, roleIn.right_ids, user_id=current.user_id)
        except PermissionError as exc:
            raise HTTPException(status_code=403, detail=str(exc))
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))
    return _to_manage_read(session, role_service.getByID(session, new_id))


@router.patch("/{roleID}", response_model=RoleManageRead)
def patchRole(roleID: int, roleIn: RoleManageUpdate, session: Session = Depends(getSession), current: User = Depends(require_right("roles.manage"))):
    role = role_service.getByID(session, roleID)
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")

    if current.role_id != ROLE_ADMIN and roleID in (ROLE_ADMIN, ROLE_FK):
        raise HTTPException(status_code=403, detail="Kan nie hierdie rol wysig nie")

    # Built-in roles: the name is immutable (relied on by seed/login gate), but
    # their right-assignments remain editable.
    renaming = roleIn.role_name is not None and roleIn.role_name != role.role_name
    if roleID in BUILTIN_ROLE_IDS and renaming:
        raise HTTPException(status_code=403, detail="Built-in role names cannot be changed.")
    if renaming:
        role_service.update(session, roleID, RoleUpdate(role_name=roleIn.role_name), user_id=current.user_id)

    if roleIn.right_ids is not None:
        try:
            role_service.set_rights(session, roleID, roleIn.right_ids, user_id=current.user_id)
        except PermissionError as exc:
            raise HTTPException(status_code=403, detail=str(exc))
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))

    return _to_manage_read(session, role_service.getByID(session, roleID))


@router.put("/{roleID}/rights", response_model=List[int])
def setRoleRights(roleID: int, payload: RoleRightsUpdate, session: Session = Depends(getSession), current: User = Depends(require_right("roles.manage"))):
    role = role_service.getByID(session, roleID)
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    if current.role_id != ROLE_ADMIN and roleID in (ROLE_ADMIN, ROLE_FK):
        raise HTTPException(status_code=403, detail="Kan nie die regte van hierdie rol wysig nie")
    try:
        return role_service.set_rights(session, roleID, payload.right_ids, user_id=current.user_id)
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.delete("/{roleID}", status_code=status.HTTP_204_NO_CONTENT)
def removeRole(roleID: int, session: Session = Depends(getSession), current: User = Depends(require_right("roles.manage"))):
    role = role_service.getByID(session, roleID)
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    if roleID in BUILTIN_ROLE_IDS:
        raise HTTPException(status_code=403, detail="Built-in roles cannot be deleted.")
    # Refuse to delete a role that users still reference (would orphan them).
    in_use = session.exec(select(User).where(User.role_id == roleID)).first()
    if in_use is not None:
        raise HTTPException(status_code=409, detail="Role is still assigned to one or more users.")
    role_service.delete(session, roleID, user_id=current.user_id)
    return None
