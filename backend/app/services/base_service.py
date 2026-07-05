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
        affected_columns: Optional[Any] = None,
        user_id: Optional[int] = None,
        affected_id: Optional[int] = None,
        json_data: Optional[Any] = None,
    ) -> None:
        previous_value = payload.get("previous_value") if isinstance(payload, dict) else None
        new_value = payload.get("new_value") if isinstance(payload, dict) else None

        audit_log = Auditlog(
            action=action,
            affectedtable=self._get_table_name(),
            affectedcolumn=affected_columns,
            affectedid=affected_id,
            previous_value=previous_value,
            new_value=new_value,
            json_data=json_data if json_data is not None else payload,
            actiondatetime=datetime.utcnow(),
            user_id=user_id,
        )
        session.add(audit_log)

    @staticmethod
    def _get_changed_fields(before_data: dict[str, Any], after_data: dict[str, Any], update_data: dict[str, Any]) -> list[str]:
        return [
            field
            for field in update_data.keys()
            if field in before_data and before_data[field] != after_data[field]
        ]

    def _extract_obj_id(self, obj: ModelType) -> Optional[int]:
        data = obj.model_dump(mode="json")
        model_name = self.model.__name__.lower()
        # common primary key patterns
        candidates = [f"{model_name}_id", "id"]
        for key in candidates:
            if key in data and isinstance(data[key], int):
                return data[key]
        # fallback: first _id field that isn't user_id
        for k, v in data.items():
            if k.endswith("_id") and k != "user_id" and isinstance(v, int):
                return v
        return None

    def getAll(self, session: Session) -> Sequence[ModelType]:
        return session.exec(select(self.model)).all()

    def getByID(self, session: Session, id: int) -> Optional[ModelType]:
        return session.get(self.model, id)

    def create(self, session: Session, data: CreateType, user_id: Optional[int] = None) -> ModelType:
        obj = self.model.model_validate(data)

        session.add(obj)
        try:
            session.flush()
            affected_id = self._extract_obj_id(obj)
            self._create_audit_log(
                session,
                "create",
                {
                    "previous_value": None,
                    "new_value": obj.model_dump(mode="json"),
                },
                affected_columns=None,
                user_id=user_id,
                affected_id=affected_id,
                json_data=obj.model_dump(mode="json"),
            )
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise

        return obj

    def update(self, session: Session, id: int, data: UpdateType, user_id: Optional[int] = None) -> Optional[ModelType]:
        obj = session.get(self.model, id)
        if not obj:
            return None

        before_data = obj.model_dump(mode="json")
        update_data = data.model_dump(exclude_unset=True)
        obj.sqlmodel_update(update_data)

        session.add(obj)
        try:
            after_data = obj.model_dump(mode="json")
            changed_fields = self._get_changed_fields(before_data, after_data, update_data)
            if changed_fields:
                filtered_before = {field: before_data[field] for field in changed_fields}
                filtered_after = {field: after_data[field] for field in changed_fields}
                affected_id = self._extract_obj_id(obj)
                # store all changed fields as JSON (list) in affectedcolumn
                self._create_audit_log(
                    session,
                    "update",
                    {
                        "previous_value": filtered_before,
                        "new_value": filtered_after,
                    },
                    affected_columns=changed_fields,
                    user_id=user_id,
                    affected_id=affected_id,
                    json_data=after_data,
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
        affected_id = None
        if isinstance(payload, dict):
            # try common id patterns
            model_name = self.model.__name__.lower()
            if f"{model_name}_id" in payload and isinstance(payload[f"{model_name}_id"], int):
                affected_id = payload[f"{model_name}_id"]
            elif "id" in payload and isinstance(payload["id"], int):
                affected_id = payload["id"]
            else:
                for k, v in payload.items():
                    if k.endswith("_id") and k != "user_id" and isinstance(v, int):
                        affected_id = v
                        break

        session.delete(obj)
        try:
            self._create_audit_log(
                session,
                "delete",
                {
                    "previous_value": payload,
                    "new_value": None,
                },
                affected_columns=None,
                user_id=user_id,
                affected_id=affected_id,
                json_data=payload,
            )
            session.commit()
        except Exception:
            session.rollback()
            raise

        return True