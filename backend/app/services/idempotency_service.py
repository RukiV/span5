import hashlib
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select

from ..models.idempotency import IdempotencyRecord

IDEMPOTENCY_TTL_HOURS = 24


def compute_key_hash(method: str, path: str, body: bytes) -> str:
    """Deterministic hash of the request signature (method + path + body)."""
    raw = f"{method}:{path}:{body.decode('utf-8', errors='replace')}"
    return hashlib.sha256(raw.encode()).hexdigest()


def try_claim(session: Session, key_hash: str, method: str, path: str) -> bool:
    """Atomically try to claim *key_hash* for processing.

    Returns ``True`` if this caller is the first to claim the key
    (INSERT succeeded).  Returns ``False`` if another request already
    claimed it (unique-constraint violation).
    """
    try:
        record = IdempotencyRecord(
            key_hash=key_hash,
            method=method,
            path=path,
            response_status=None,
            response_body=None,
        )
        session.add(record)
        session.commit()
        return True
    except IntegrityError:
        session.rollback()
        return False


def get_cached(session: Session, key_hash: str) -> Optional[IdempotencyRecord]:
    """Return a completed idempotency record, or *None* if still processing."""
    record = session.exec(
        select(IdempotencyRecord).where(IdempotencyRecord.key_hash == key_hash)
    ).first()
    if record and record.response_status is not None:
        return record
    return None


def complete(
    session: Session,
    key_hash: str,
    response_status: int,
    response_body: str,
) -> None:
    """Mark a claimed key_hash as completed with the final response."""
    record = session.exec(
        select(IdempotencyRecord).where(IdempotencyRecord.key_hash == key_hash)
    ).first()
    if record:
        record.response_status = response_status
        record.response_body = response_body
        record.completed_at = datetime.utcnow()
        session.add(record)
        session.commit()


def release(session: Session, key_hash: str) -> None:
    """Remove a claim -- used when the request failed (5xx)."""
    record = session.exec(
        select(IdempotencyRecord).where(IdempotencyRecord.key_hash == key_hash)
    ).first()
    if record:
        session.delete(record)
        session.commit()


def cleanup_expired(session: Session) -> int:
    """Remove records older than *IDEMPOTENCY_TTL_HOURS*. Returns count."""
    cutoff = datetime.utcnow() - timedelta(hours=IDEMPOTENCY_TTL_HOURS)
    records = session.exec(
        select(IdempotencyRecord).where(IdempotencyRecord.created_at < cutoff)
    ).all()
    count = len(records)
    for r in records:
        session.delete(r)
    session.commit()
    return count
