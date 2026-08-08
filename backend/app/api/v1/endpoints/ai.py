"""AI fault-draft endpoints.

Two-step workflow, per the Phase-0 hybrid decision. The pipeline is an
FK/Admin tool — regular fault reports (including students') are created
immediately via POST /fault and never pass through here:
  1. An FK/Admin submits free text via POST /ai/draft-fault (right ``ai.use``).
     The backend runs the rules classifier (type/priority — always), the local
     LLM (extraction/disambiguation/duplicate detection — degraded gracefully
     when Ollama is unreachable), and backend-side entity resolution. The result
     is a *draft*, never a real Faultcard.
  2. FK/Admin (right ``ai.approve``) reviews the queue, inline-edits, then
     approves (creates the real Faultcard) or rejects with a reason.

Future trigger: drafts may also be auto-generated from analytical/prediction
data (``FaultDraft.source="auto"``) — the schema already carries the flag.
"""

import json
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.asset import Asset
from ....models.enums import FaultStatus, Priority, Type
from ....models.fault import Faultcard, FaultcardCreate
from ....models.faultdraft import (
    DraftCandidate,
    FaultDraft,
    FaultDraftApprove,
    FaultDraftCreate,
    FaultDraftDetail,
    FaultDraftRead,
    FaultDraftReject,
)
from ....models.location import Building, Room
from ....models.user import User
from ....services import entity_resolver, rules_classifier
from ....services.fault_service import fault_service
from ....services.faultdraft_service import faultdraft_service
from ....services.llm_service import llm_service
from ....services.notification_service import NotificationService

logger = logging.getLogger(__name__)

router = APIRouter()


def _enum_by_name(enum_cls, name: str):
    """Resolve an enum member by NAME ('REPAIR' -> Type.REPAIR). Python's
    Enum(value) matches by value only ('Herstel'), so name lookup is needed."""
    try:
        return enum_cls[name]
    except KeyError:
        return enum_cls(name)


def _json_ids(raw: str) -> list[int]:
    try:
        parsed = json.loads(raw or "[]")
        return [int(x) for x in parsed if str(x).isdigit()]
    except (ValueError, TypeError):
        return []


def _open_faults(session: Session, limit: int = 8) -> list[dict]:
    """Recent open faults, surfaced to the LLM for duplicate detection. The LLM
    may only reference these ids; the endpoint validates that later."""
    rows = session.exec(
        select(Faultcard)
        .where(Faultcard.fault_status.in_([FaultStatus.OPEN, FaultStatus.WAIT, FaultStatus.CONFIRMED]))
        .order_by(Faultcard.fault_reportdatetime.desc())
        .limit(limit)
    ).all()
    return [{"id": f.fault_id, "name": (f.fault_description or "")[:80], "detail": ""} for f in rows]


def _asset_candidates(session: Session, ids: list[int]) -> list[dict]:
    out = []
    for asset_id in ids:
        asset = session.get(Asset, asset_id)
        if not asset:
            continue
        detail = asset.asset_brand or ""
        if asset.room_id:
            room = session.get(Room, asset.room_id)
            if room:
                detail = (detail + " · " if detail else "") + room.room_name
        out.append({"id": asset.asset_id, "name": asset.asset_name, "detail": detail})
    return out


def _room_candidates(session: Session, ids: list[int]) -> list[dict]:
    out = []
    for room_id in ids:
        room = session.get(Room, room_id)
        if not room:
            continue
        out.append({"id": room.room_id, "name": room.room_name, "detail": ""})
    return out


def _candidate_list(items: list[dict]) -> list[DraftCandidate]:
    return [DraftCandidate(id=it["id"], name=it["name"], detail=it.get("detail", "")) for it in items]


@router.post("", response_model=FaultDraftRead, status_code=status.HTTP_201_CREATED)
def createDraft(
    payload: FaultDraftCreate,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.use")),
):
    """Submit free text; the AI pipeline produces a fault draft for FK review."""
    desc = payload.description

    # 1. Rules classification — deterministic, always on.
    suggested_type = rules_classifier.classify_type(desc)
    suggested_priority = rules_classifier.classify_priority(desc)

    # 2. LLM extraction — degrades to the raw text when Ollama is unavailable.
    ai_status = "ok"
    try:
        llm = llm_service.extract(desc)
        cleaned = (llm.get("cleaned_description") or "").strip()[:2000] or desc[:2000]
        title = (llm.get("title") or "").strip()[:255]
        work_instruction = (llm.get("work_instruction") or "").strip()[:2000]
        failure_category = llm.get("failure_category", "other")
        language = llm.get("language", "af")
        asset_mention = (llm.get("asset_mention") or "").strip()
        room_mention = (llm.get("room_mention") or "").strip()
    except Exception:
        ai_status = "degraded"
        cleaned, title = desc[:2000], desc[:80]
        work_instruction, failure_category, language = "", "other", "af"
        asset_mention, room_mention = "", ""

    # 3. Backend entity resolution (mentions -> candidate ids).
    if asset_mention:
        asset_ids = entity_resolver.resolve_asset_mention(session, asset_mention)
    elif ai_status == "degraded":
        asset_ids = entity_resolver.resolve_asset_mention(session, desc)
    else:
        asset_ids = []

    if room_mention:
        room_ids = entity_resolver.resolve_room_mention(session, room_mention)
    elif ai_status == "degraded":
        room_ids = entity_resolver.resolve_room_mention(session, desc)
    else:
        room_ids = []

    # 4. LLM disambiguation + duplicate detection (only when there are choices).
    # Defense in depth: even though LlmService.disambiguate filters its output
    # to the candidate ids it was given, the endpoint re-validates here so a
    # misbehaving/replaced model can never inject foreign ids into the draft.
    resolved_asset = None
    resolved_room = None
    duplicate_of = None
    if ai_status == "ok" and (asset_ids or room_ids):
        try:
            open_faults = _open_faults(session)
            open_ids = {f["id"] for f in open_faults}
            decision = llm_service.disambiguate(
                description=desc,
                asset_candidates=_asset_candidates(session, asset_ids),
                room_candidates=_room_candidates(session, room_ids),
                open_faults=open_faults,
            )
            if decision.get("asset_id") in asset_ids:
                resolved_asset = decision.get("asset_id")
            if decision.get("room_id") in room_ids:
                resolved_room = decision.get("room_id")
            if decision.get("duplicate_of") in open_ids:
                duplicate_of = decision.get("duplicate_of")
        except Exception:
            pass  # candidates stay unresolved; FK decides in the queue

    draft = faultdraft_service.create_draft(
        session,
        user_id=user.user_id,
        values={
            "description": desc,
            "cleaned_description": cleaned,
            "title": title,
            "work_instruction": work_instruction,
            "suggested_type": suggested_type,
            "suggested_priority": suggested_priority,
            "failure_category": failure_category,
            "language": language,
            "asset_ids": json.dumps(asset_ids),
            "room_ids": json.dumps(room_ids),
            "resolved_asset_id": resolved_asset,
            "resolved_room_id": resolved_room,
            "duplicate_of": duplicate_of,
            "ai_status": ai_status,
            "source": "manual",
            "status": "draft",
        },
    )

    try:
        notif_svc = NotificationService(session)
        notif_svc.notify_admins(
            notification_type="ai.draft_created",
            title="Nuwe AI-foutkonsep",
            message=f"{draft.title or draft.description[:60]} — wag op goedkeuring.",
            actor_id=user.user_id,
            reference_type="faultdraft",
            reference_id=draft.draft_id,
        )
    except Exception:
        logger.exception("Notification fan-out failed after creating AI draft %s", draft.draft_id)
    return draft


@router.get("", response_model=List[FaultDraftRead])
def listDrafts(
    status_filter: Optional[str] = "draft",
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.approve")),
):
    """FK/Admin approval queue."""
    stmt = select(FaultDraft).order_by(FaultDraft.created_at.desc())
    if status_filter:
        stmt = stmt.where(FaultDraft.status == status_filter)
    return session.exec(stmt).all()


@router.get("/{draft_id}", response_model=FaultDraftDetail)
def getDraft(
    draft_id: int,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.approve")),
):
    """Draft detail, enriched with the resolvable candidate lists so the FK UI
    can show what the AI found and let the reviewer pick."""
    draft = session.get(FaultDraft, draft_id)
    if not draft:
        raise HTTPException(status_code=404, detail="Draft not found")
    detail = FaultDraftDetail.model_validate(draft)
    detail.asset_candidates = _candidate_list(_asset_candidates(session, _json_ids(draft.asset_ids)))
    detail.room_candidates = _candidate_list(_room_candidates(session, _json_ids(draft.room_ids)))
    return detail


@router.post("/{draft_id}/approve", response_model=FaultDraftRead)
def approveDraft(
    draft_id: int,
    payload: FaultDraftApprove,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.approve")),
):
    """Approve a draft — the reviewer's inline edits override the AI values; a
    real Faultcard is created (owned by the original submitter) and the
    submitter is notified. Concurrency-safe: only one reviewer can win the
    atomic ``draft -> approved`` claim; a second attempt gets 409."""
    draft = session.get(FaultDraft, draft_id)
    if not draft:
        raise HTTPException(status_code=404, detail="Draft not found")
    if draft.status != "draft":
        raise HTTPException(status_code=409, detail="Draft already reviewed")

    final_desc = (payload.cleaned_description or draft.cleaned_description or draft.description).strip()
    final_type = payload.fault_type or draft.suggested_type
    final_priority = payload.fault_priority or draft.suggested_priority

    # --- Reviewer-override ids: must exist and be mutually consistent. ---
    final_asset = payload.asset_id if payload.asset_id is not None else draft.resolved_asset_id
    final_room = payload.room_id if payload.room_id is not None else draft.resolved_room_id
    if final_asset is not None and not session.get(Asset, final_asset):
        raise HTTPException(status_code=422, detail="asset_id does not exist")
    building_id = None
    if final_room is not None:
        room = session.get(Room, final_room)
        if not room:
            raise HTTPException(status_code=422, detail="room_id does not exist")
        if payload.building_id is not None and payload.building_id != room.building_id:
            raise HTTPException(status_code=422, detail="building_id does not match the room's building")
        building_id = payload.building_id if payload.building_id is not None else room.building_id
        location_id = room.building.location_id if room.building else None
    else:
        if payload.building_id is not None and not session.get(Building, payload.building_id):
            raise HTTPException(status_code=422, detail="building_id does not exist")
        building_id = payload.building_id
        location_id = None

    # --- Atomic claim: exactly one reviewer wins the draft. ---
    if not faultdraft_service.claim_review(session, draft_id, reviewer_id=user.user_id, status="approved"):
        raise HTTPException(status_code=409, detail="Draft already reviewed")

    fault_in = FaultcardCreate(
        fault_description=final_desc,
        fault_type=_enum_by_name(Type, final_type),
        fault_priority=_enum_by_name(Priority, final_priority),
        asset_id=final_asset,
        room_id=final_room,
        building_id=building_id,
        location_id=location_id,
        duplicate_of=draft.duplicate_of,
    )
    try:
        # The submitter keeps ownership of the faultcard (view_own scoping);
        # the reviewer's action is captured in the audit trail.
        fault = fault_service.create(session, fault_in, user_id=draft.user_id)
        draft = faultdraft_service.finalize_review(
            session, draft_id,
            resolved={"asset_id": final_asset, "room_id": final_room},
            duplicate_of=draft.duplicate_of,
            title=payload.title,
            work_instruction=payload.work_instruction,
        )
    except Exception:
        faultdraft_service.revert_claim(session, draft_id)
        raise

    # Notifications must never turn a committed approval into a 500.
    try:
        notif_svc = NotificationService(session)
        notif_svc.notify_admins(
            notification_type="fault.created",
            title="Nuwe foutkaartjie",
            message=f"Fout #{fault.fault_id} goedgekeur uit AI-konsep {draft.description[:60]}.",
            actor_id=user.user_id,
            reference_type="fault",
            reference_id=fault.fault_id,
        )
        if draft.user_id != user.user_id:
            notif_svc.create_notification(
                user_id=draft.user_id,
                notification_type="ai.draft_approved",
                title="Foutkonsep goedgekeur",
                message=f"Jou AI-foutkonsep is goedgekeur as foutkaartjie #{fault.fault_id}.",
                actor_id=user.user_id,
                reference_type="fault",
                reference_id=fault.fault_id,
            )
    except Exception:
        logger.exception("Notification fan-out failed after approving AI draft %s", draft_id)
    return draft


@router.post("/{draft_id}/reject", response_model=FaultDraftRead)
def rejectDraft(
    draft_id: int,
    payload: FaultDraftReject,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.approve")),
):
    """Reject a draft — the reason is kept on the draft and sent to the submitter."""
    draft = session.get(FaultDraft, draft_id)
    if not draft:
        raise HTTPException(status_code=404, detail="Draft not found")
    if draft.status != "draft":
        raise HTTPException(status_code=409, detail="Draft already reviewed")
    if not faultdraft_service.claim_review(session, draft_id, reviewer_id=user.user_id, status="rejected"):
        raise HTTPException(status_code=409, detail="Draft already reviewed")

    draft = faultdraft_service.finalize_review(session, draft_id, review_note=payload.reason)

    if draft.user_id != user.user_id:
        try:
            notif_svc = NotificationService(session)
            notif_svc.create_notification(
                user_id=draft.user_id,
                notification_type="ai.draft_rejected",
                title="Foutkonsep afgekeur",
                message=f"Jou AI-foutkonsep is afgekeur. Rede: {payload.reason}",
                actor_id=user.user_id,
                reference_type="faultdraft",
                reference_id=draft.draft_id,
            )
        except Exception:
            logger.exception("Notification fan-out failed after rejecting AI draft %s", draft_id)
    return draft
