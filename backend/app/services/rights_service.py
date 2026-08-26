from typing import Optional

from sqlmodel import Session, select

from ..auth import permissions
from ..models.role import Rights, RightsCreate, RightsUpdate, RoleRight
from .base_service import BaseService


class RightsService(BaseService[Rights, RightsCreate, RightsUpdate]):
    """CRUD for the rights catalog.

    Built-in vs custom is enforced at the endpoint layer (403 on built-ins). This
    service only handles the mechanics: deleting a right cascades its RoleRight
    association rows and clears the permissions rights-cache.
    """

    def delete(self, session: Session, id: int, user_id: Optional[int] = None) -> bool:
        right = session.get(Rights, id)
        if not right:
            return False
        # Cascade the composite-PK association rows first (no DB-level cascade).
        for rr in session.exec(select(RoleRight).where(RoleRight.right_id == id)).all():
            session.delete(rr)
        result = super().delete(session, id, user_id=user_id)
        permissions.clear_rights_cache()
        return result


rights_service = RightsService(Rights)
