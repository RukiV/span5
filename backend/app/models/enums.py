from enum import Enum

class Priority(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"

class Type(Enum):
    MAINTENANCE = "maintenance"
    REPAIR = "repair"
    UPGRADE = "upgrade"

class FaultStatus(Enum):
    WAIT = "wag"
    OPEN = "open"
    CONFRIMED = "bevestig"
    IN_PROGRESS = "besig"
    RESOLVED = "opgelos"
    CLOSED = "verwerp"

class JobStatus(Enum):
    WAIT = "wag"
    OPEN = "open"
    IN_PROGRESS = "besig"
    COMPLETED = "voltooid"
    CANCELLED = "geannuleerd"

class AssetStatus(Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    MAINTENANCE = "maintenance"
    DECOMMISSIONED = "decommissioned"   

class RoomType(Enum):
    OFFICE = "office"
    CONFERENCE = "conference"
    LABORATORY = "laboratory"
    WAREHOUSE = "warehouse"
    CLASSROOM = "classroom"
    OTHER = "other"