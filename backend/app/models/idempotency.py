from datetime import datetime
from typing import Optional
from sqlmodel import Field, SQLModel


class IdempotencyRecord(SQLModel, table=True):
    """Stores idempotency keys for POST requests to prevent duplicate processing.

    Uses a unique constraint on ``key_hash`` as a distributed lock:
    only one request can INSERT the same hash, preventing race conditions
    even under concurrent spam-clicks.
    """
    __tablename__ = "idempotency_record"

    id: int = Field(default=None, primary_key=True, sa_column_kwargs={"autoincrement": True})
    key_hash: str = Field(max_length=64, unique=True, index=True, nullable=False)
    method: str = Field(max_length=10, nullable=False)
    path: str = Field(max_length=500, nullable=False)
    response_status: Optional[int] = Field(default=None, nullable=True)
    response_body: Optional[str] = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = Field(default=None, nullable=True)
