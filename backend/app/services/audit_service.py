from ..models.audit import Auditlog, AuditlogCreate, AuditlogUpdate
from .base_service import BaseService
from sqlmodel import Session, select, cast, Integer
from sqlalchemy import or_
from typing import Sequence

class AuditService(BaseService[Auditlog, AuditlogCreate, AuditlogUpdate]):
    def __init__(self):
        super().__init__(Auditlog)

    def getRoomChangesForAsset(self, session: Session, asset_id: int) -> Sequence[Auditlog]:
        statement = (
            select(Auditlog).where(Auditlog.affectedtable == "asset")
            .where(Auditlog.action.in_(["update", "create"]))
            .where(Auditlog.new_value["room_id"].as_string() != None)
            .where(cast(Auditlog.json_data["asset_id"].as_string(), Integer) == asset_id)
            .order_by(Auditlog.actiondatetime.desc())
        )

        return session.exec(statement).all()

audit_service = AuditService()