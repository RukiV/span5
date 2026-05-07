from dataclasses import dataclass

@dataclass
class ReportDTO:
    id: int
    title: str
    description: str
    #file