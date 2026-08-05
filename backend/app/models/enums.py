from enum import Enum

class Priority(Enum):
    """Enumeration for priority values."""
    LOW = "Laag"
    MEDIUM = "Medium"
    HIGH = "Hoog"

class Type(Enum):
    """Enumeration for type/werksoort values."""
    MAINTENANCE = "Onderhoud"
    REPAIR = "Herstel"
    INSPECTION = "Inspeksie"
    INSTALLATION = "Installasie"

class FaultStatus(Enum):
    """Enumeration for fault status values."""
    WAIT = "Wag"
    OPEN = "Oop"
    CONFIRMED = "Bevestig"
    IN_PROGRESS = "Besig"
    RESOLVED = "Opgelos"
    CLOSED = "Gesluit"

class JobStatus(Enum):
    """Enumeration for job status values."""
    WAIT = "Wag"
    OPEN = "Oop"
    SCHEDULED = "Geskeduleer"
    IN_PROGRESS = "Besig"
    COMPLETED = "Voltooid"
    CANCELLED = "Gekanselleer"

class AssetStatus(Enum):
    """Enumeration for asset status values."""
    ACTIVE = "Aktief"
    INACTIVE = "Onaktief"
    MAINTENANCE = "Instandhouding"
    DECOMMISSIONED = "Afgedank"

class RoomStatus(Enum):
    """Enumeration for room statuses."""
    OPERATIONAL = "Operasioneel"
    ISSUE_REPORTED = "Fout Aangemeld"
    MAINTENANCE = "Instandhouding"
    OUT_OF_SERVICE = "Buite Werking"

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
