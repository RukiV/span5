from typing import List, Optional, Sequence

from sqlmodel import Session, select

from ..models.location import (
    Building,
    BuildingCreate,
    BuildingRead,
    BuildingTypeLink,
    BuildingUpdate,
)
from .base_service import BaseService
from . import cascade_delete


class BuildingService(BaseService[Building, BuildingCreate, BuildingUpdate]):
    def _get_building_types(self, session: Session, building_id: int) -> List:
        rows = session.exec(
            select(BuildingTypeLink).where(BuildingTypeLink.building_id == building_id)
        ).all()
        return [row.building_type for row in rows]

    def _to_read(self, session: Session, building: Building) -> BuildingRead:
        return BuildingRead(
            building_id=building.building_id,
            building_name=building.building_name,
            building_types=self._get_building_types(session, building.building_id),
            location_id=building.location_id,
        )

    def getAll(self, session: Session) -> Sequence[BuildingRead]:
        buildings = session.exec(select(Building)).all()
        return [self._to_read(session, b) for b in buildings]

    def getByID(self, session: Session, id: int) -> Optional[BuildingRead]:
        building = session.get(Building, id)
        if building is None:
            return None
        return self._to_read(session, building)

    def create(self, session: Session, data: BuildingCreate, user_id: Optional[int] = None) -> BuildingRead:
        values = data.model_dump(exclude_unset=True)
        building_types = values.pop("building_types", []) or []
        building = Building(**values)

        session.add(building)
        try:
            session.flush()
            for t in building_types:
                session.add(BuildingTypeLink(building_id=building.building_id, building_type=t))

            self._create_audit_log(
                session,
                "create",
                {
                    "previous_value": None,
                    "new_value": {
                        **building.model_dump(mode="json"),
                        "building_types": [t.value for t in building_types],
                    },
                },
                affected_columns=None,
                user_id=user_id,
                affected_id=building.building_id,
                json_data={
                    **building.model_dump(mode="json"),
                    "building_types": [t.value for t in building_types],
                },
            )
            session.commit()
            session.refresh(building)
        except Exception:
            session.rollback()
            raise

        return self._to_read(session, building)

    def update(self, session: Session, id: int, data: BuildingUpdate, user_id: Optional[int] = None) -> Optional[BuildingRead]:
        building = session.get(Building, id)
        if not building:
            return None

        before_data = building.model_dump(mode="json")
        before_data["building_types"] = [t.value for t in self._get_building_types(session, id)]

        update_data = data.model_dump(exclude_unset=True)
        building_types = update_data.pop("building_types", None)

        building.sqlmodel_update(update_data)

        if building_types is not None:
            existing = session.exec(
                select(BuildingTypeLink).where(BuildingTypeLink.building_id == id)
            ).all()
            for row in existing:
                session.delete(row)
            for t in building_types:
                session.add(BuildingTypeLink(building_id=id, building_type=t))

        session.add(building)
        try:
            after_data = building.model_dump(mode="json")
            after_data["building_types"] = [t.value for t in self._get_building_types(session, id)]

            changed_fields = [
                field
                for field in update_data.keys()
                if field in before_data and before_data[field] != after_data[field]
            ]
            if building_types is not None and before_data.get("building_types") != after_data.get("building_types"):
                changed_fields.append("building_types")

            if changed_fields:
                filtered_before = {field: before_data[field] for field in changed_fields}
                filtered_after = {field: after_data[field] for field in changed_fields}
                self._create_audit_log(
                    session,
                    "update",
                    {
                        "previous_value": filtered_before,
                        "new_value": filtered_after,
                    },
                    affected_columns=changed_fields,
                    user_id=user_id,
                    affected_id=building.building_id,
                    json_data=after_data,
                )
            session.commit()
            session.refresh(building)
        except Exception:
            session.rollback()
            raise

        return self._to_read(session, building)

    def delete(self, session: Session, id: int, user_id: Optional[int] = None) -> bool:
        obj = session.get(self.model, id)
        if not obj:
            return False

        payload = obj.model_dump(mode="json")
        payload["building_types"] = [t.value for t in self._get_building_types(session, id)]
        cascade_delete.cascade_delete_building(session, id)
        try:
            self._create_audit_log(
                session,
                "delete",
                {"previous_value": payload, "new_value": None},
                affected_columns=None,
                user_id=user_id,
                affected_id=id,
                json_data=payload,
            )
            session.commit()
        except Exception:
            session.rollback()
            raise
        return True


building_service = BuildingService(Building)