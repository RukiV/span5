from dataclasses import dataclass

@dataclass
class QuoteDTO:
    id: int
    title: str
    description: str
    price: float