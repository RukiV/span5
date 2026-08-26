from datetime import datetime
from typing import Optional, Sequence
from sqlmodel import Session, select, cast, Integer
from sqlalchemy import func

from ..models.asset import Asset, AssetCreate, AssetUpdate, AssetHistoryEventRead
from ..models.audit import Auditlog
from ..models.job import Jobcard
from .base_service import BaseService
from .prediction_service import prediction_service


class AssetService(BaseService[Asset, AssetCreate, AssetUpdate]):
    def __init__(self):
        super().__init__(Asset)

    def create(self, session: Session, data: AssetCreate, user_id: Optional[int] = None) -> Asset:
        if data.asset_created_datetime is None:
            data.asset_created_datetime = datetime.utcnow()
        result = super().create(session, data, user_id=user_id)
        # Invalidate predictions cache since new asset affects predictions
        prediction_service.invalidateCache()
        return result
    
    def getBySerial(self, session: Session, serial: str) -> Asset | None:
        return session.exec(select(Asset).where(Asset.asset_serial == serial)).first()

    def getHistory(self, session: Session, asset_id: int) -> Sequence[AssetHistoryEventRead]:
        # room changes from auditlog
        audit_statement = (
            select(Auditlog)
            .where(Auditlog.affectedtable == "asset")
            .where(Auditlog.action.in_(["update", "create"]))
            .where(cast(Auditlog.json_data["asset_id"].as_string(), Integer) == asset_id)
            .where(Auditlog.json_data["room_id"].as_string() != None)
            .order_by(Auditlog.actiondatetime.desc())
        )

        audit_rows = session.exec(audit_statement).all()
        audit_events = []
        for row in audit_rows:
            audit_events.append(
                AssetHistoryEventRead(
                    event_type="room_change",
                    event_datetime=row.actiondatetime or datetime.utcnow(),
                    event_title=f"Aksie: ({row.action})",
                    event_description=(
                        f"Van lokaal {row.previous_value.get('room_id')} na {row.new_value.get('room_id')} verander."
                        if row.previous_value and row.new_value
                        else None
                    ),
                    asset_id=asset_id,
                    source="audit",
                    event_id=row.auditlog_id,
                    event_metadata={
                        "audit_action": row.action,
                        "affected_column": row.affectedcolumn,
                        "previous_value": row.previous_value,
                        "new_value": row.new_value,
                        "json_data": row.json_data,
                    },
                )
            )

        # maintenance jobs related to the asset
        job_statement = (
            select(Jobcard)
            .where(Jobcard.asset_id == asset_id)
            .where(Jobcard.job_type == "maintenance")
            .order_by(Jobcard.job_createddatetime.desc())
        )

        job_rows = session.exec(job_statement).all()
        job_events = []
        for row in job_rows:
            job_events.append(
                AssetHistoryEventRead(
                    event_type="maintenance",
                    event_datetime=row.job_createddatetime or datetime.utcnow(),
                    event_title=f"Werkopdrag {row.jobcard_id}",
                    event_description=row.job_desc,
                    asset_id=asset_id,
                    source="job",
                    event_id=row.jobcard_id,
                    event_metadata={
                        "job_status": row.job_status,
                        "room_id": row.room_id,
                        "fault_id": row.fault_id,
                    },
                )
            )

        merged = sorted(
            audit_events + job_events,
            key=lambda event: event.event_datetime,
            reverse=True,
        )
        return merged

    def getStatusSummary(self, session: Session) -> list[dict]:
        statement = (
            select(Asset.asset_status, func.count(Asset.asset_id))
            .group_by(Asset.asset_status)
        )
        results = session.exec(statement).all()

        return [
            {
                "status": status.value if hasattr(status, "value") else str(status),
                "count": count,
            }
            for status, count in results
        ]

assets_service = AssetService()