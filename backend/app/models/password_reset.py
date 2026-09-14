from datetime import datetime, timedelta
from typing import Optional
from sqlmodel import Field
from .base import Base

_RESET_TOKEN_EXPIRY_HOURS = 1


class PasswordResetToken(Base, table=True):
    __tablename__: str = "password_reset_tokens"

    reset_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    token_hash: str = Field(index=True, max_length=64)
    expires_at: datetime = Field()
    used: bool = Field(default=False)

    @property
    def is_expired(self) -> bool:
        return datetime.utcnow() > self.expires_at

    @staticmethod
    def create_expiry() -> datetime:
        return datetime.utcnow() + timedelta(hours=_RESET_TOKEN_EXPIRY_HOURS)
