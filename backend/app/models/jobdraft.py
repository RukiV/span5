from typing import Optional
from datetime import datetime
from pydantic import field_validator
from sqlmodel import SQLModel, Field
from .base import Base
from .validators import sanitize_text


class JobDraftBase(SQLModel):
    """Base model for AI-generated job drafts (pre-approval queue).

    A draft is the result of the AI pipeline on a free-text description. It is
    never a real Jobcard until an FK/Admin approves it (inline edits allowed),
    so the existing manual job flow stays untouched.
    """
    description: str = Field(max_length=2000)
    cleaned_description: str = Field(default="", max_length=2000)
    title: str = Field(default="", max_length=255)
    work_instruction: str = Field(default="", max_length=2000)
    # Classification from the rules classifier (deterministic, LLM-independent).
    suggested_type: str = Field(default="REPAIR", max_length=20)
    suggested_priority: str = Field(default="MEDIUM", max_length=10)
    failure_category: str = Field(default="other", max_length=30)
    language: str = Field(default="af", max_length=5)
    # JSON arrays of candidate ids (entity resolution is backend-side; the LLM
    # never emits ids directly).
    asset_ids: str = Field(default="[]", max_length=2000)
    room_ids: str = Field(default="[]", max_length=1000)
    resolved_asset_id: Optional[int] = Field(default=None, foreign_key="asset.asset_id")
    resolved_room_id: Optional[int] = Field(default=None, foreign_key="room.room_id")
    duplicate_of: Optional[int] = Field(default=None, foreign_key="jobcard.jobcard_id")
    # "ok" when the full LLM pipeline ran, "degraded" when Ollama was unavailable.
    ai_status: str = Field(default="ok", max_length=10)
    # How the draft was triggered: "manual" = FK/Admin fed free text to the AI;
    # "auto" (future) = generated from analytical/prediction data.
    source: str = Field(default="manual", max_length=20)
    # draft | approved | rejected
    status: str = Field(default="draft", max_length=10)
    review_note: str = Field(default="", max_length=2000)

    @field_validator("description", "cleaned_description", "title", "work_instruction", "review_note", mode="before")
    @classmethod
    def _sanitize_texts(cls, v, info):
        return sanitize_text(v) if isinstance(v, str) else v


class JobDraft(JobDraftBase, Base, table=True):
    """Model for jobdraft data."""
    draft_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.user_id")
    reviewer_id: Optional[int] = Field(default=None, foreign_key="user.user_id")
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    reviewed_at: Optional[datetime] = None


class JobDraftCreate(SQLModel):
    """Input model for creating a job draft from free text."""
    description: str = Field(min_length=3, max_length=2000)

    @field_validator("description", mode="before")
    @classmethod
    def _sanitize_desc(cls, v, info):
        return sanitize_text(v) if isinstance(v, str) else v


class JobDraftRead(JobDraftBase):
    """Output model for reading a job draft."""
    draft_id: int
    user_id: int
    reviewer_id: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    reviewed_at: Optional[datetime] = None


class JobDraftApprove(SQLModel):
    """FK/Admin inline-edit + approval payload.

    Only the fields the reviewer may change are accepted; anything left out
    falls back to the draft's own AI suggestions. ``fault_type`` /
    ``fault_priority`` are validated against the real Jobcard enums.
    """
    cleaned_description: Optional[str] = Field(default=None, max_length=2000)
    title: Optional[str] = Field(default=None, max_length=255)
    work_instruction: Optional[str] = Field(default=None, max_length=2000)
    fault_type: Optional[str] = Field(default=None, max_length=20)
    fault_priority: Optional[str] = Field(default=None, max_length=10)
    asset_id: Optional[int] = None
    room_id: Optional[int] = None
    building_id: Optional[int] = None

    @field_validator("fault_type", mode="before")
    @classmethod
    def _check_type(cls, v, info):
        if v is not None and v not in ("REPAIR", "MAINTENANCE", "INSPECTION", "INSTALLATION"):
            raise ValueError("fault_type must be one of REPAIR|MAINTENANCE|INSPECTION|INSTALLATION")
        return v

    @field_validator("fault_priority", mode="before")
    @classmethod
    def _check_priority(cls, v, info):
        if v is not None and v not in ("LOW", "MEDIUM", "HIGH"):
            raise ValueError("fault_priority must be one of LOW|MEDIUM|HIGH")
        return v

    @field_validator("cleaned_description", "title", "work_instruction", mode="before")
    @classmethod
    def _sanitize_texts(cls, v, info):
        return sanitize_text(v) if isinstance(v, str) else v


class JobDraftReject(SQLModel):
    """Rejection payload — a reason is required so the submitter learns why."""
    reason: str = Field(min_length=2, max_length=2000)

    @field_validator("reason", mode="before")
    @classmethod
    def _sanitize_reason(cls, v, info):
        return sanitize_text(v) if isinstance(v, str) else v


class DraftCandidate(SQLModel):
    """A resolvable entity candidate surfaced to the FK approval UI."""
    id: int
    name: str
    detail: str = ""


class JobDraftDetail(JobDraftRead):
    """Draft detail enriched with the resolved candidate lists."""
    asset_candidates: list[DraftCandidate] = []
    room_candidates: list[DraftCandidate] = []
