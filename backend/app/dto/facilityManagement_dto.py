from dataclasses import asdict, dataclass
from typing import Any, Dict

@dataclass
class FacilityManagementDTO:
    id: int
    name: str

    def get_details(self) -> Dict[str, Any]:
        return asdict(self)