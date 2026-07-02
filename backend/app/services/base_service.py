from datetime import datetime
from typing import Type, TypeVar, Sequence, Generic, Optional, Any
from sqlmodel import Session, select, SQLModel

from ..models.audit import Auditlog

ModelType = TypeVar("ModelType", bound=SQLModel)
CreateType = TypeVar("CreateType", bound=SQLModel)
UpdateType = TypeVar("UpdateType", bound=SQLModel)


class BaseService(Generic[ModelType, CreateType, UpdateType]):
    def __init__(self, model: Type[ModelType]):
        self.model = model

    def _get_table_name(self) -> str:
        return getattr(self.model, "__tablename__", self.model.__name__.lower())

    def _create_audit_log(
        self,
        session: Session,
        action: str,
        payload: Any,
        affected_column: Optional[str] = None,
        user_id: Optional[int] = None,
    ) -> None:
        previous_value = payload.get("previous_value") if isinstance(payload, dict) else None
        new_value = payload.get("new_value") if isinstance(payload, dict) else None

        audit_log = Auditlog(
            action=action,
            affectedtable=self._get_table_name(),
            affectedcolumn=affected_column,
            previous_value=previous_value,
            new_value=new_value,
            json_data=payload,
            actiondatetime=datetime.utcnow(),
            user_id=user_id,
        )
        session.add(audit_log)

    def getAll(self, session: Session) -> Sequence[ModelType]:
        return session.exec(select(self.model)).all()

    def getByID(self, session: Session, id: int) -> Optional[ModelType]:
        return session.get(self.model, id)

    def create(self, session: Session, data: CreateType, user_id: Optional[int] = None) -> ModelType:
        obj = self.model.model_validate(data)

        session.add(obj)
        try:
            session.flush()
            session.refresh(obj)
            self._create_audit_log(
                session,
                "create",
                {
                    "previous_value": None,
                    "new_value": obj.model_dump(mode="json"),
                },
                user_id=user_id,
            )
            session.commit()
        except Exception:
            session.rollback()
            raise

        return obj

    def update(self, session: Session, id: int, data: UpdateType, user_id: Optional[int] = None) -> Optional[ModelType]:
        obj = session.get(self.model, id)
        if not obj:
            return None

        before_data = obj.model_dump(mode="json")
        updateData = data.model_dump(exclude_unset=True)
        changed_fields = list(updateData.keys())

        obj.sqlmodel_update(updateData)

        session.add(obj)
        try:
            filtered_before = {field: before_data[field] for field in changed_fields if field in before_data}
            filtered_after = {field: obj.model_dump(mode="json")[field] for field in changed_fields}

            pk_fields = [col.name for col in self.model.__table__.primary_key]
            for pk in pk_fields:
                if pk in before_data:
                    filtered_before.setdefault(pk, before_data[pk])
                if pk in obj.model_dump(mode="json"):
                    filtered_after.setdefault(pk, obj.model_dump(mode="json")[pk])

            self._create_audit_log(
                session,
                "update",
                {
                    "previous_value": filtered_before,
                    "new_value": filtered_after,
                },
                affected_column=changed_fields[0] if changed_fields else None,
                user_id=user_id,
            )
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise

        return obj

    def delete(self, session: Session, id: int, user_id: Optional[int] = None) -> bool:
        obj = session.get(self.model, id)
        if not obj:
            return False

        payload = obj.model_dump(mode="json")
        session.delete(obj)
        try:
            self._create_audit_log(
                session,
                "delete",
                {
                    "previous_value": payload,
                    "new_value": None,
                },
                user_id=user_id,
            )
            session.commit()
        except Exception:
            session.rollback()
            raise

        return True