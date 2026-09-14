from ..models.report import Reports, ReportsCreate, ReportsUpdate
from .base_service import BaseService

report_service = BaseService[Reports, ReportsCreate, ReportsUpdate](Reports)