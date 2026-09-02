from datetime import datetime
from typing import Optional
from sqlmodel import Field
from .base import Base


class RevokedToken(Base, table=True):
    """Server-side record of revoked session tokens.

    Tokens live here only until their natural expiry, at which point they are
    cleaned up by ``purge_expired_tokens``.  A token that appears in this table
    is rejected by ``verify_session_token`` regardless of its HMAC validity.
    """

    __tablename__: str = "revoked_tokens"

    token_id: Optional[int] = Field(default=None, primary_key=True)
    token_hash: str = Field(index=True, max_length=64)
    revoked_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime = Field()
    user_id: int = Field()
