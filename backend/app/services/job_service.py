from sqlmodel import Session, select

from ..models.job import Jobcard, JobcardCreate, JobcardUpdate
from .base_service import BaseService

class JobService(BaseService[Jobcard, JobcardCreate, JobcardUpdate]):
    def __init__(self):
        super().__init__(Jobcard)

    def getRecent(self, session: Session, limit: int = 5):
        return session.exec(
            select(Jobcard)
            .order_by(Jobcard.job_createddatetime.desc().nullslast())
            .limit(limit)
        ).all()

job_service = JobService()