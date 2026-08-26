from datetime import datetime
from typing import Any, Optional

from sqlmodel import Session, update

from ..models.jobdraft import JobDraft
from .base_service import BaseService


class JobDraftService(BaseService[JobDraft, Any, Any]):
    """Persistence + audit for AI job drafts.

    ``BaseService``'s generic create/update already write audit logs; we add the
    pipeline-specific helpers here so the endpoint stays thin.
    """

    def create_draft(self, session: Session, *, user_id: int, values: dict) -> JobDraft:
        now = datetime.utcnow()
        obj = JobDraft(**values, user_id=user_id, created_at=now, updated_at=now)
        session.add(obj)
        try:
            session.flush()
            self._create_audit_log(
                session,
                "create",
                {"previous_value": None, "new_value": obj.model_dump(mode="json")},
                affected_columns=None,
                user_id=user_id,
                affected_id=obj.draft_id,
                json_data=obj.model_dump(mode="json"),
            )
            session.commit()
            session.refresh(obj)
        except Exception:
            session.rollback()
            raise
        return obj

    def claim_review(self, session: Session, draft_id: int, *, reviewer_id: int,
                     status: str) -> bool:
        """Atomically move a draft from ``draft`` to ``status``.

        The UPDATE is conditional on the row still being in ``draft`` state and
        the row count is checked, so two concurrent approvals cannot both win:
        exactly one call returns True (the loser gets False and must 409).
        Returns False when the draft was already reviewed.
        """
        now = datetime.utcnow()
        before = session.get(JobDraft, draft_id)
        result = session.exec(
            update(JobDraft)
            .where(JobDraft.draft_id == draft_id, JobDraft.status == "draft")
            .values(status=status, reviewer_id=reviewer_id, reviewed_at=now, updated_at=now)
        )
        if result.rowcount != 1:
            session.rollback()
            return False
        try:
            self._create_audit_log(
                session,
                "update",
                {
                    "previous_value": {"status": before.status if before else "draft"},
                    "new_value": {"status": status, "reviewer_id": reviewer_id},
                },
                affected_columns=["status", "reviewer_id", "reviewed_at"],
                user_id=reviewer_id,
                affected_id=draft_id,
                json_data={"status": status, "reviewer_id": reviewer_id, "reviewed_at": str(now)},
            )
            session.commit()
        except Exception:
            session.rollback()
            raise
        return True

    def finalize_review(self, session: Session, draft_id: int, *,
                        review_note: str = "", resolved: Optional[dict] = None,
                        duplicate_of: Optional[int] = None,
                        title: Optional[str] = None,
                        work_instruction: Optional[str] = None) -> JobDraft:
        """Write the review details (reason, resolved ids, duplicate link,
        reviewer overrides) onto a draft that ``claim_review`` already flipped.
        No status change. ``title`` / ``work_instruction`` are the reviewer's
        inline edits — persisted so they are not silently lost."""
        draft = session.get(JobDraft, draft_id)
        if not draft:
            raise ValueError("Draft not found")
        before = draft.model_dump(mode="json")
        if review_note:
            draft.review_note = review_note
        if resolved:
            draft.resolved_asset_id = resolved.get("asset_id", draft.resolved_asset_id)
            draft.resolved_room_id = resolved.get("room_id", draft.resolved_room_id)
        if duplicate_of is not None:
            draft.duplicate_of = duplicate_of
        if title is not None:
            draft.title = title
        if work_instruction is not None:
            draft.work_instruction = work_instruction
        draft.updated_at = datetime.utcnow()
        session.add(draft)
        try:
            session.flush()
            self._create_audit_log(
                session,
                "update",
                {"previous_value": {"status": before["status"]}, "new_value": draft.model_dump(mode="json")},
                affected_columns=["review_note", "resolved_asset_id", "resolved_room_id", "duplicate_of", "title", "work_instruction"],
                user_id=draft.reviewer_id,
                affected_id=draft.draft_id,
                json_data=draft.model_dump(mode="json"),
            )
            session.commit()
            session.refresh(draft)
        except Exception:
            session.rollback()
            raise
        return draft

    def revert_claim(self, session: Session, draft_id: int) -> None:
        """Undo a ``claim_review`` after a failure (e.g. jobcard creation
        crashed) so the draft can be reviewed again."""
        session.exec(
            update(JobDraft)
            .where(JobDraft.draft_id == draft_id, JobDraft.status != "draft")
            .values(status="draft", reviewer_id=None, reviewed_at=None, updated_at=datetime.utcnow())
        )
        session.commit()


jobdraft_service = JobDraftService(JobDraft)
