from typing import Optional
from pydantic import BaseModel


class AnalyticsRequest(BaseModel):
    page: str
    date_from: Optional[str] = None
    date_to: Optional[str] = None


class Metric(BaseModel):
    label: str
    value: str


class ChartDataset(BaseModel):
    label: str
    data: list[float]
    backgroundColor: list[str]


class ChartData(BaseModel):
    type: str
    labels: list[str]
    datasets: list[ChartDataset]


class Suggestion(BaseModel):
    type: str
    label: str
    description: str
    params: dict = {}


class AnalyticsResponse(BaseModel):
    summary: str
    metrics: list[Metric]
    insights: list[str]
    suggestions: list[Suggestion] = []
    chart: Optional[ChartData] = None
