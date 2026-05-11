from typing import Type, TypeVar, List, Generic, Optional
from sqlmodel import Session, select, SQLModel

ModelType = TypeVar("ModelType", bound=SQLModel)
CreateType = TypeVar("CreateType", bound=SQLModel)
UpdateType = TypeVar("UpdateType", bound=SQLModel)

class BaseService(Generic[ModelType, CreateType, UpdateType]):
    def __init__(self, model: Type[ModelType]):
        self.model = model

    def getAll(self, session: Session) -> List[ModelType]:
        return session.exec(select(self.model)).all()
    
    def getByID(self, session: Session, id: int) -> Optional[ModelType]:
        return session.get(self.model, id)
    
    def create(self, session: Session, data: CreateType) -> ModelType:
        obj = self.model.model_validate(data)

        session.add(obj)
        session.commit()
        session.refresh(obj)

        return obj
    
    def update(self, session: Session, id: int, data: UpdateType) -> Optional[ModelType]:
        obj = session.get(self.model, id)
        if not obj:
            return None
        
        session.add(obj)
        session.commit()
        session.refresh(obj)
        
        return obj
    
    def delete(self, session: Session, id: int) -> bool:
        obj = session.get(self.model, id)
        if not obj:
            return False
        
        session.delete(obj)
        session.commit()

        return True