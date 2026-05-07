from dataclasses import dataclass, field
from typing import List
from app.dto.right_dto import RightDTO

@dataclass
class RoleDTO:
    id: int
    name: str
    rights: List[RightDTO] = field(default_factory=list)