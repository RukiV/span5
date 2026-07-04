from ..models.job import Jobcard, JobcardCreate, JobcardUpdate
from .base_service import BaseService

job_service = BaseService[Jobcard, JobcardCreate, JobcardUpdate](Jobcard)