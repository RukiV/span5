"""AI job-draft endpoints.

Two-step workflow, per the Phase-0 hybrid decision. The pipeline is an
FK/Admin tool — regular job reports (including students') are created
immediately via POST /job and never pass through here:
  1. An FK/Admin submits free text via POST /ai/draft (right ``ai.use``).
     The backend runs the rules classifier (type/priority — always), the local
     LLM (extraction/disambiguation/duplicate detection — degraded gracefully
     when Ollama is unreachable), and backend-side entity resolution. The result
     is a *draft*, never a real Jobcard.
  2. FK/Admin (right ``ai.approve``) reviews the queue, inline-edits, then
     approves (creates the real Jobcard) or rejects with a reason.

Future trigger: drafts may also be auto-generated from analytical/prediction
data (``JobDraft.source="auto"``) — the schema already carries the flag.
"""

import json
import logging
from typing import Any, List, Optional, Sequence

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select, SQLModel

from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.asset import Asset
from ....models.enums import JobStatus, Priority, Type
from ....models.job import Jobcard, JobcardCreate
from ....models.jobdraft import (
    DraftCandidate,
    JobDraft,
    JobDraftApprove,
    JobDraftCreate,
    JobDraftDetail,
    JobDraftRead,
    JobDraftReject,
)
from ....models.location import Building, Room
from ....models.user import User
from ....services import entity_resolver, rules_classifier, suggest_service
from ....services.job_service import job_service
from ....services.jobdraft_service import jobdraft_service
from ....services.llm_service import llm_service
from ....services.notification_service import NotificationService

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/status")
def ai_status_get(
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.approve")),
):
    """Whether the local AI pipeline (Ollama/Gemma) is enabled for
    job-drafting. Used by the queue page indicator. Pure config read."""
    return {"ai_enabled": llm_service._enabled()}



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


def _open_jobs(session: Session, limit: int = 8) -> list[dict]:
    """Recent open jobs, surfaced to the LLM for duplicate detection. The LLM
    may only reference these ids; the endpoint validates that later."""
    rows = session.exec(
        select(Jobcard)
        .where(Jobcard.job_status.in_([JobStatus.WAIT, JobStatus.OPEN, JobStatus.SCHEDULED, JobStatus.IN_PROGRESS]))
        .order_by(Jobcard.job_createddatetime.desc())
        .limit(limit)
    ).all()
    return [{"id": j.jobcard_id, "name": (j.job_desc or "")[:80], "detail": ""} for j in rows]


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


def _name_map(session: Session, drafts: Sequence[JobDraft]) -> dict[int, dict[str, Optional[str]]]:
    """Bulk-laai bate/lokaal/gebou-name vir 'n lys konsepte (een vrae per tabel,
    nie een per ry nie). Val terug op die eerste kandidaat wanneer die LLM geen
    enkele oordeel gemaak het nie — sodat die Ligging-kolom tog leesbaar is."""
    def _resolved_or_first(d: JobDraft, resolved_id: Optional[int], json_key_ids: str) -> Optional[int]:
        if resolved_id is not None:
            return resolved_id
        ids = _json_ids(getattr(d, json_key_ids))
        return ids[0] if ids else None

    effective: dict[int, tuple[Optional[int], Optional[int]]] = {}
    for d in drafts:
        eff_asset = _resolved_or_first(d, d.resolved_asset_id, "asset_ids")
        eff_room = _resolved_or_first(d, d.resolved_room_id, "room_ids")
        effective[d.draft_id] = (eff_asset, eff_room)

    asset_ids = {a for a, _ in effective.values() if a}
    room_ids = {r for _, r in effective.values() if r}
    assets = {a.asset_id: a.asset_name for a in session.exec(select(Asset).where(Asset.asset_id.in_(asset_ids))).all()} if asset_ids else {}
    rooms = {r.room_id: r.room_name for r in session.exec(select(Room).where(Room.room_id.in_(room_ids))).all()} if room_ids else {}

    building_by_room: dict[int, Optional[str]] = {}
    if room_ids:
        for r in session.exec(select(Room).where(Room.room_id.in_(room_ids))).all():
            building_by_room[r.room_id] = session.get(Building, r.building_id).building_name if (r.building_id and session.get(Building, r.building_id)) else None

    out: dict[int, dict[str, Optional[str]]] = {}
    for d in drafts:
        eff_asset, eff_room = effective[d.draft_id]
        out[d.draft_id] = {
            "resolved_asset_name": assets.get(eff_asset),
            "resolved_room_name": rooms.get(eff_room),
            "building_name": building_by_room.get(eff_room),
        }
    return out


class AiSuggestRequest(SQLModel):
    """Vorm-state vir veldvoorstelle: context = watter tipe vorm, fields = die
    huidige waardes. Die enjin voorsel slegs leë velde en net wanneer minstens
    3 velde reeds ingevul is."""
    context: str
    fields: dict[str, Any] = {}


@router.post("/suggest")
def suggestFields(
    payload: AiSuggestRequest,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.use")),
):
    """DB-similariteit veldvoorstelle (bv. assettype uit soortgelyke bates se
    name, tipe/prioriteit uit die reëls-klassifiseerder). Stil leeg by twyfel."""
    return {"suggestions": suggest_service.suggest(payload.context, session, payload.fields)}


@router.post("", response_model=JobDraftRead, status_code=status.HTTP_201_CREATED)
def createDraft(
    payload: JobDraftCreate,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.use")),
):
    """Submit free text; the AI pipeline produces a job draft for FK review."""
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
            open_jobs = _open_jobs(session)
            open_ids = {j["id"] for j in open_jobs}
            decision = llm_service.disambiguate(
                description=desc,
                asset_candidates=_asset_candidates(session, asset_ids),
                room_candidates=_room_candidates(session, room_ids),
                open_jobs=open_jobs,
            )
            if decision.get("asset_id") in asset_ids:
                resolved_asset = decision.get("asset_id")
            if decision.get("room_id") in room_ids:
                resolved_room = decision.get("room_id")
            if decision.get("duplicate_of") in open_ids:
                duplicate_of = decision.get("duplicate_of")
        except Exception:
            pass  # candidates stay unresolved; FK decides in the queue

    draft = jobdraft_service.create_draft(
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
            title="Nuwe AI-werkskonsep",
            message=f"{draft.title or draft.description[:60]} — wag op goedkeuring.",
            actor_id=user.user_id,
            reference_type="jobdraft",
            reference_id=draft.draft_id,
        )
    except Exception:
        logger.exception("Notification fan-out failed after creating AI draft %s", draft.draft_id)
    return draft


@router.get("", response_model=List[JobDraftRead])
def listDrafts(
    status_filter: Optional[str] = "draft",
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.approve")),
):
    """FK/Admin approval queue."""
    stmt = select(JobDraft).order_by(JobDraft.created_at.desc())
    if status_filter:
        stmt = stmt.where(JobDraft.status == status_filter)
    drafts = session.exec(stmt).all()
    names = _name_map(session, drafts)
    out: List[JobDraftRead] = []
    for d in drafts:
        rd = JobDraftRead.model_validate(d)
        for key, val in names.get(d.draft_id, {}).items():
            setattr(rd, key, val)
        out.append(rd)
    return out


@router.get("/{draft_id}", response_model=JobDraftDetail)
def getDraft(
    draft_id: int,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.approve")),
):
    """Draft detail, enriched with the resolvable candidate lists so the FK UI
    can show what the AI found and let the reviewer pick."""
    draft = session.get(JobDraft, draft_id)
    if not draft:
        raise HTTPException(status_code=404, detail="Draft not found")
    detail = JobDraftDetail.model_validate(draft)
    for key, val in _name_map(session, [draft]).get(draft.draft_id, {}).items():
        setattr(detail, key, val)
    detail.asset_candidates = _candidate_list(_asset_candidates(session, _json_ids(draft.asset_ids)))
    detail.room_candidates = _candidate_list(_room_candidates(session, _json_ids(draft.room_ids)))
    return detail


@router.post("/{draft_id}/approve", response_model=JobDraftRead)
def approveDraft(
    draft_id: int,
    payload: JobDraftApprove,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.approve")),
):
    """Approve a draft — the reviewer's inline edits override the AI values; a
    real Jobcard is created (owned by the original submitter) and the
    submitter is notified. Concurrency-safe: only one reviewer can win the
    atomic ``draft -> approved`` claim; a second attempt gets 409."""
    draft = session.get(JobDraft, draft_id)
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
    if not jobdraft_service.claim_review(session, draft_id, reviewer_id=user.user_id, status="approved"):
        raise HTTPException(status_code=409, detail="Draft already reviewed")

    job_in = JobcardCreate(
        job_desc=final_desc,
        job_type=final_type,
        job_priority=final_priority,
        asset_id=final_asset,
        room_id=final_room,
        building_id=building_id,
        location_id=location_id,
        duplicate_of=draft.duplicate_of,
    )
    try:
        # The submitter keeps ownership of the jobcard (view_own scoping);
        # the reviewer's action is captured in the audit trail.
        job = job_service.create(session, job_in, user_id=draft.user_id)
        if job.user_id is None:
            job.user_id = draft.user_id
            session.add(job)
            session.commit()
            session.refresh(job)
        draft = jobdraft_service.finalize_review(
            session, draft_id,
            resolved={"asset_id": final_asset, "room_id": final_room},
            duplicate_of=draft.duplicate_of,
            title=payload.title,
            work_instruction=payload.work_instruction,
        )
    except Exception:
        jobdraft_service.revert_claim(session, draft_id)
        raise

    # Notifications must never turn a committed approval into a 500.
    try:
        notif_svc = NotificationService(session)
        notif_svc.notify_admins(
            notification_type="job.created",
            title="Nuwe werkskaartjie",
            message=f"Werk #{job.jobcard_id} goedgekeur uit AI-konsep {draft.description[:60]}.",
            actor_id=user.user_id,
            reference_type="job",
            reference_id=job.jobcard_id,
        )
        if draft.user_id != user.user_id:
            notif_svc.create_notification(
                user_id=draft.user_id,
                notification_type="ai.draft_approved",
                title="Werkskonsep goedgekeur",
                message=f"Jou AI-werkskonsep is goedgekeur as werkskaartjie #{job.jobcard_id}.",
                actor_id=user.user_id,
                reference_type="job",
                reference_id=job.jobcard_id,
            )
    except Exception:
        logger.exception("Notification fan-out failed after approving AI draft %s", draft_id)
    return draft


@router.post("/{draft_id}/reject", response_model=JobDraftRead)
def rejectDraft(
    draft_id: int,
    payload: JobDraftReject,
    session: Session = Depends(getSession),
    user: User = Depends(require_right("ai.approve")),
):
    """Reject a draft — the reason is kept on the draft and sent to the submitter."""
    draft = session.get(JobDraft, draft_id)
    if not draft:
        raise HTTPException(status_code=404, detail="Draft not found")
    if draft.status != "draft":
        raise HTTPException(status_code=409, detail="Draft already reviewed")
    if not jobdraft_service.claim_review(session, draft_id, reviewer_id=user.user_id, status="rejected"):
        raise HTTPException(status_code=409, detail="Draft already reviewed")

    draft = jobdraft_service.finalize_review(session, draft_id, review_note=payload.reason)

    if draft.user_id != user.user_id:
        try:
            notif_svc = NotificationService(session)
            notif_svc.create_notification(
                user_id=draft.user_id,
                notification_type="ai.draft_rejected",
                title="Werkskonsep afgekeur",
                message=f"Jou AI-werkskonsep is afgekeur. Rede: {payload.reason}",
                actor_id=user.user_id,
                reference_type="jobdraft",
                reference_id=draft.draft_id,
            )
        except Exception:
            logger.exception("Notification fan-out failed after rejecting AI draft %s", draft_id)
    return draft
