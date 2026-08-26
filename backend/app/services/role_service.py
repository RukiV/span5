from typing import List, Optional

from sqlmodel import Session, select

from ..auth import permissions
from ..auth.rights_catalog import ROLE_ADMIN
from ..models.role import Role, RoleCreate, RoleUpdate, Rights, RoleRight
from .base_service import BaseService


class RoleService(BaseService[Role, RoleCreate, RoleUpdate]):
    """CRUD for roles, plus management of a role's RoleRight assignments.

    The RoleRight association has a composite primary key, so it does not fit the
    generic BaseService single-id methods — assignment changes are handled by the
    custom ``set_rights`` below, and role deletion cascades the association rows.
    Every assignment change clears the permissions rights-cache so it applies
    immediately (see auth/permissions.py).
    """

    def get_rights(self, session: Session, role_id: int) -> List[Rights]:
        return session.exec(
            select(Rights)
            .join(RoleRight, RoleRight.right_id == Rights.right_id)
            .where(RoleRight.role_id == role_id)
        ).all()

    def get_right_ids(self, session: Session, role_id: int) -> List[int]:
        return list(session.exec(
            select(RoleRight.right_id).where(RoleRight.role_id == role_id)
        ).all())

    def set_rights(self, session: Session, role_id: int, right_ids: List[int], user_id: Optional[int] = None) -> Optional[List[int]]:
        """Replace a role's rights with ``right_ids`` (idempotent set semantics).

        Returns the sorted new right_ids, or None if the role does not exist.
        Raises ValueError for unknown right_ids, PermissionError if it would strip
        ``users.manage`` from the Admin role (self-lockout guard).
        """
        role = session.get(Role, role_id)
        if not role:
            return None

        requested = set(right_ids or [])
        if requested:
            valid_ids = set(session.exec(
                select(Rights.right_id).where(Rights.right_id.in_(requested))
            ).all())
            unknown = requested - valid_ids
            if unknown:
                raise ValueError(f"Unknown right_id(s): {sorted(unknown)}")

        # Self-lockout guard: the Admin role must always keep users.manage.
        if role_id == ROLE_ADMIN:
            users_manage_id = session.exec(
                select(Rights.right_id).where(Rights.right_name == "users.manage")
            ).first()
            if users_manage_id is not None and users_manage_id not in requested:
                raise PermissionError("The Admin role must keep the 'users.manage' right.")

        existing = session.exec(select(RoleRight).where(RoleRight.role_id == role_id)).all()
        before_ids = sorted(rr.right_id for rr in existing)
        for rr in existing:
            session.delete(rr)
        for right_id in sorted(requested):
            session.add(RoleRight(role_id=role_id, right_id=right_id))

        self._create_audit_log(
            session,
            "update",
            {
                "previous_value": {"right_ids": before_ids},
                "new_value": {"right_ids": sorted(requested)},
            },
            affected_columns=["rights"],
            user_id=user_id,
            affected_id=role_id,
            json_data={"role_id": role_id, "right_ids": sorted(requested)},
        )
        session.commit()
        permissions.clear_rights_cache()
        return sorted(requested)

    def delete(self, session: Session, id: int, user_id: Optional[int] = None) -> bool:
        role = session.get(Role, id)
        if not role:
            return False
        # Cascade the composite-PK association rows first (no DB-level cascade).
        for rr in session.exec(select(RoleRight).where(RoleRight.role_id == id)).all():
            session.delete(rr)
        result = super().delete(session, id, user_id=user_id)
        permissions.clear_rights_cache()
        return result


role_service = RoleService(Role)
