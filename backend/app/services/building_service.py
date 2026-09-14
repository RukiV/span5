from typing import Optional
from sqlmodel import Session, select

from ..models.location import Building, BuildingCreate, BuildingRead, BuildingTypeLink, BuildingUpdate
from .base_service import BaseService
from . import cascade_delete


class BuildingService(BaseService[Building, BuildingCreate, BuildingUpdate]):
    def _types(self, session: Session, building_id: int):
        return [row.building_type for row in session.exec(
            select(BuildingTypeLink).where(BuildingTypeLink.building_id == building_id)
        ).all()]

    def _read(self, session: Session, building: Building) -> BuildingRead:
        types = self._types(session, building.building_id)
        return BuildingRead(
            building_id=building.building_id,
            building_name=building.building_name,
            building_types=types,
            building_type=types[0] if types else None,
            location_id=building.location_id,
        )

    def getAll(self, session: Session):
        return [self._read(session, building) for building in session.exec(select(Building)).all()]

    def getByID(self, session: Session, id: int):
        building = session.get(Building, id)
        return self._read(session, building) if building else None

    def create(self, session: Session, data: BuildingCreate, user_id: Optional[int] = None):
        values = data.model_dump(exclude_unset=True)
        legacy_type = values.pop("building_type", None)
        types = values.pop("building_types", []) or ([] if legacy_type is None else [legacy_type])
        building = Building(**values)
        session.add(building)
        session.flush()
        for building_type in types:
            session.add(BuildingTypeLink(building_id=building.building_id, building_type=building_type))
        session.commit()
        session.refresh(building)
        return self._read(session, building)

    def update(self, session: Session, id: int, data: BuildingUpdate, user_id: Optional[int] = None):
        building = session.get(Building, id)
        if not building:
            return None
        values = data.model_dump(exclude_unset=True)
        legacy_type = values.pop("building_type", None)
        types = values.pop("building_types", None)
        if types is None and legacy_type is not None:
            types = [legacy_type]
        building.sqlmodel_update(values)
        if types is not None:
            for link in session.exec(select(BuildingTypeLink).where(BuildingTypeLink.building_id == id)).all():
                session.delete(link)
            for building_type in types:
                session.add(BuildingTypeLink(building_id=id, building_type=building_type))
        session.add(building)
        session.commit()
        session.refresh(building)
        return self._read(session, building)

    def delete(self, session: Session, id: int, user_id: Optional[int] = None) -> bool:
        obj = session.get(self.model, id)
        if not obj:
            return False

        payload = obj.model_dump(mode="json")
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
