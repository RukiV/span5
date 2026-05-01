@dataclass
class AssetDTO:
    id: int
    name: str
    type: str
    status: str
    description: Optional[str]
    isOutdoor: bool
    maintenanceDate: datetime