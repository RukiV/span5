from enum import Enum

class Priority(Enum):
    """Enumeration for priority values."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"

class Type(Enum):
    """Enumeration for type values."""
    MAINTENANCE = "maintenance"
    REPAIR = "repair"
    UPGRADE = "upgrade"

class FaultStatus(Enum):
    """Enumeration for fault status values."""
    WAIT = "wag"
    OPEN = "open"
    CONFRIMED = "bevestig"
    IN_PROGRESS = "besig"
    RESOLVED = "opgelos"
    CLOSED = "verwerp"

class JobStatus(Enum):
    """Enumeration for job status values."""
    WAIT = "wag"
    OPEN = "open"
    IN_PROGRESS = "besig"
    COMPLETED = "voltooid"
    CANCELLED = "geannuleerd"

class AssetStatus(Enum):
    """Enumeration for asset status values."""
    ACTIVE = "active"
    INACTIVE = "inactive"
    MAINTENANCE = "maintenance"
    DECOMMISSIONED = "decommissioned"   

class RoomType(Enum):
    """Enumeration for room type values."""
    OFFICE = "Kantoor"
    CONFERENCE = "conference"
    LABORATORY = "laboratory"
    WAREHOUSE = "warehouse"
    CLASSROOM = "classroom"
    OTHER = "other"
