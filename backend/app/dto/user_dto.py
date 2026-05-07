from dataclasses import dataclass, field
from typing import Optional, List

from app.dto.role_dto import RoleDTO
from app.dto.report_dto import ReportDTO

@dataclass
class UserDTO:
    id: int
    username: str
    email: str
    pNumber: str
    microsoftID: str
    passwordHash: str
    status: bool
    role: RoleDTO
    reports: Optional[List[ReportDTO]] = field(default_factory=list)