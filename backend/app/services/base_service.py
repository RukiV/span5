from datetime import datetime
from typing import Type, TypeVar, List, Generic, Optional, Any
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

    def _create_audit_log(self, session: Session, action: str, payload: Any) -> None:
        audit_log = Auditlog(
            action=action,
            affectedtable=self._get_table_name(),
            json_data=payload,
            actiondatetime=datetime.utcnow(),
        )
        session.add(audit_log)

    def getAll(self, session: Session) -> List[ModelType]:
        return session.exec(select(self.model)).all()

    def getByID(self, session: Session, id: int) -> Optional[ModelType]:
        return session.get(self.model, id)

    def create(self, session: Session, data: CreateType) -> ModelType:
        obj = self.model.model_validate(data)

        session.add(obj)
        try:
            self._create_audit_log(session, "create", data.model_dump(mode="json"))
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise

        return obj

    def update(self, session: Session, id: int, data: UpdateType) -> Optional[ModelType]:
        obj = session.get(self.model, id)
        if not obj:
            return None

        before_data = obj.model_dump(mode="json")
        updateData = data.model_dump(exclude_unset=True)

        obj.sqlmodel_update(updateData)

        session.add(obj)
        try:
            self._create_audit_log(session, "update", {"before": before_data, "after": obj.model_dump(mode="json")})
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise

        return obj

    def delete(self, session: Session, id: int) -> bool:
        obj = session.get(self.model, id)
        if not obj:
            return False

        payload = obj.model_dump(mode="json")
        session.delete(obj)
        try:
            self._create_audit_log(session, "delete", payload)
            session.commit()
        except Exception:
            session.rollback()
            raise

        return True