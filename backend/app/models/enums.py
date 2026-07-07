from enum import Enum

class Priority(Enum):
    """Enumeration for priority values."""
    LOW = "Laag"
    MEDIUM = "Medium"
    HIGH = "Hoog"

class Type(Enum):
    """Enumeration for type values."""
    MAINTENANCE = "Instandhouding"
    REPAIR = "Herstelwerk"
    UPGRADE = "Opgradering"

class FaultStatus(Enum):
    """Enumeration for fault status values."""
    WAIT = "Wag"
    OPEN = "Oop"
    CONFRIMED = "Bevestig"
    IN_PROGRESS = "Besig"
    RESOLVED = "Opgelos"
    CLOSED = "Gesluit"

class JobStatus(Enum):
    """Enumeration for job status values."""
    WAIT = "Wag"
    OPEN = "Oop"
    IN_PROGRESS = "Besig"
    COMPLETED = "Voltooid"
    CANCELLED = "Gekanselleer"

class AssetStatus(Enum):
    """Enumeration for asset status values."""
    ACTIVE = "Aktief"
    INACTIVE = "Onaktief"
    MAINTENANCE = "Instandhouding"
    DECOMMISSIONED = "Afgedank"

class BuildingType(Enum):
    """Enumeration for building type values."""
    ADMIN = "Kantoorgebou"
    EDUCATIONAL = "Onderwys"
    LABORATORY = "Laboratorium"
    WAREHOUSE = "warehouse"
    KAFERERIA = "Kafeteria"
    OTHER = "Ander"

class RoomType(Enum):
    """Enumeration for room type values."""
    OFFICE = "Kantoor"
    CONFERENCE = "Konferensiekamer"
    LABORATORY = "Laboratorium"
    WAREHOUSE = "Pakhuis"
    CLASSROOM = "Klaskamer"
    BATHROOM = "Badkamer"
    OTHER = "Ander"
