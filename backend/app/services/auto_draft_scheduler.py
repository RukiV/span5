"""Auto-draft scheduler for the AI job-draft pipeline (Phase 2a).

Second trigger for ``JobDraft.source="auto"``: drafts are generated from
analytical / prediction data instead of FK free text. The module mirrors
``reminder_scheduler.py`` — a module-level interval env var plus a background
``while True`` loop that guards each pass with try/except and logs errors, so a
bad pass never kills the app.

Every ``AI_AUTO_DRAFT_INTERVAL`` seconds the loop scans the live predictions
(computed on the fly — there is no prediction table). Any asset that trips an
analytical signal (>=3 faults in 12 months, lifespan exceeded, maintenance >180
days overdue), has no open faultcard, and has no draft yet (any status — so a
rejected draft is not re-created) gets a new draft in the FK/Admin review queue.

Optimizations:
- Minimum interval clamp (60s) prevents runaway loops from env misconfiguration
- Pagination: process assets in batches to avoid long DB locks
- Staggered startup: random delay prevents thundering herd on multi-worker deployments
"""

import asyncio
import json
import logging
import os
import random
from datetime import datetime, timedelta

from sqlmodel import Session, select

from ..auth.rights_catalog import ROLE_ADMIN, ROLE_FK
from ..db.database import engine as database_engine
from ..models.enums import FaultStatus
from ..models.fault import Faultcard
from ..models.jobdraft import JobDraft
from ..models.prediction import AssetPredictionRead
from ..models.user import User
from .jobdraft_service import jobdraft_service
from .llm_service import llm_service
from .notification_service import NotificationService
from .prediction_service import prediction_service
from .rules_classifier import classify_priority, classify_type

logger = logging.getLogger(__name__)

# Minimum interval to prevent runaway loops (e.g., env var set to 1 second)
MIN_AUTO_DRAFT_INTERVAL = 60

# Batch size for paginated processing
AUTO_DRAFT_BATCH_SIZE = 50

# Delay between batches (seconds) to yield DB
AUTO_DRAFT_BATCH_DELAY = 0.1

AI_AUTO_DRAFT_ENABLED = os.getenv("AI_AUTO_DRAFT_ENABLED", "true").lower() not in ("false", "0", "no")
_raw_interval = int(os.getenv("AI_AUTO_DRAFT_INTERVAL", "300"))
AI_AUTO_DRAFT_INTERVAL = max(_raw_interval, MIN_AUTO_DRAFT_INTERVAL)

if _raw_interval < MIN_AUTO_DRAFT_INTERVAL:
    logger.warning(
        f"AI_AUTO_DRAFT_INTERVAL={_raw_interval}s is below minimum {MIN_AUTO_DRAFT_INTERVAL}s; clamping to {AI_AUTO_DRAFT_INTERVAL}s"
    )

logger.info(f"Auto-draft scheduler configured: enabled={AI_AUTO_DRAFT_ENABLED}, interval={AI_AUTO_DRAFT_INTERVAL}s")

_OPEN_FAULT_STATUSES = (FaultStatus.OPEN, FaultStatus.WAIT, FaultStatus.CONFIRMED)


def _draft_signals(pred: AssetPredictionRead) -> list[str]:
    """Afrikaans reason strings that justify an auto-draft for ``pred``.

    An empty list means the asset has no analytical trigger (yet).
    """
    signals = []
    threshold = pred.replacement_threshold if pred.replacement_threshold else 3
    if pred.fault_count_12months >= threshold:
        signals.append(f"{pred.fault_count_12months} foute in die laaste 12 maande (drempel: {threshold})")
    if pred.lifespan_exceeded:
        # lifespan_pct_used is only None in a degenerate 0-month-lifespan case;
        # treat that as fully used rather than crashing the format call.
        pct = pred.lifespan_pct_used if pred.lifespan_pct_used is not None else 100.0
        signals.append(f"lewensduur oorskry ({pct:.0f}% gebruik)")
    # "Onderhoud agterstallig" is measured in days PAST the next-maintenance
    # date (next_maintenance_date), not days since the last service — a
    # 90-day-interval asset is overdue 90 days after its next date, while a
    # 365-day-interval asset needs a full year. This mirrors prediction_service.
    if pred.maintenance_overdue and pred.next_maintenance_date:
        days_overdue = (datetime.utcnow() - pred.next_maintenance_date).days
        if days_overdue >= 180:
            signals.append(
                f"onderhoud agterstallig ({days_overdue} dae oor sperdatum)"
            )
    # ML survival signal (Phase 2c): an ADDITIONAL trigger, not a replacement
    # for the rules above. survival_high_risk defaults to False when the model
    # is unavailable, so sparse/disabled deployments behave exactly as before.
    if getattr(pred, "survival_high_risk", False) and pred.survival_failure_prob_12mo is not None:
        signals.append(
            f"ML-risiko: {pred.survival_failure_prob_12mo * 100:.0f}% faalkans binne 12 maande"
        )
    return signals


def _asset_has_open_fault(session: Session, asset_id: int) -> bool:
    """True when the asset already carries an unclosed faultcard."""
    stmt = select(Faultcard).where(
        Faultcard.asset_id == asset_id,
        Faultcard.fault_status.in_(_OPEN_FAULT_STATUSES),
    )
    return session.exec(stmt).first() is not None


def _asset_has_draft(session: Session, asset_id: int) -> bool:
    """True when a draft (any status) already references the asset.

    The resolved_asset_id equality catches auto-drafts; the asset_ids JSON
    membership check catches drafts where the asset was only a mention. The
    JSON is ``json.dumps([...])`` of *ints* (no quotes), so a textual LIKE
    would be unreliable — membership is parsed instead. Checking every status
    dedups across approvals *and* rejections so a turned-down draft is not
    re-created.
    """
    resolved_stmt = select(JobDraft).where(JobDraft.resolved_asset_id == asset_id)
    if session.exec(resolved_stmt).first() is not None:
        return True
    for draft in session.exec(select(JobDraft.asset_ids)).all():
        try:
            if asset_id in json.loads(draft[0] or "[]"):
                return True
        except (ValueError, TypeError):
            continue  # malformed JSON on an old row must not block the scan
    return False


def scan_and_create_auto_drafts(engine=None) -> list[int]:
    """One scan pass: turn prediction signals into auto-drafts.

    Returns the ids of the drafts created in this pass (empty list when there
    is nothing to do or no FK/Admin operator exists). ``jobdraft_service``
    commits per draft, so each new draft is durable even if a later one fails.

    Optimizations:
    - Pagination: process assets in batches of AUTO_DRAFT_BATCH_SIZE
    - Batch delay: small sleep between batches to yield DB
    """
    if engine is None:
        engine = database_engine

    created: list[int] = []
    with Session(engine) as session:
        # The draft is owned by an FK operator (falls back to an admin).
        operator = session.exec(select(User).where(User.role_id == ROLE_FK)).first()
        if operator is None:
            operator = session.exec(select(User).where(User.role_id == ROLE_ADMIN)).first()
        if operator is None:
            logger.warning("Auto-draft skandeerder: geen FK/Admin gebruiker gevind — oorslaan.")
            return []

        # Get all predictions
        preds = prediction_service.getPredictions(session)
        logger.debug(f"Auto-draft scan: processing {len(preds)} assets")

        # Paginate processing
        for i in range(0, len(preds), AUTO_DRAFT_BATCH_SIZE):
            batch = preds[i:i + AUTO_DRAFT_BATCH_SIZE]
            
            for pred in batch:
                # One bad asset (e.g. deleted between prediction and insert) must
                # not abort the whole pass — log and move on to the next asset.
                try:
                    signals = _draft_signals(pred)
                    if not signals:
                        continue
                    if _asset_has_open_fault(session, pred.asset_id):
                        continue
                    if _asset_has_draft(session, pred.asset_id):
                        continue

                    description = (
                        f"Voorspellende instandhouding: {pred.asset_name} ({pred.asset_serial})"
                        f" — {', '.join(signals)}."
                    )
                    suggested_type = classify_type(description)
                    suggested_priority = classify_priority(description)

                    # LLM enrichment is optional — any failure degrades to rules-only.
                    try:
                        llm = llm_service.extract(description)
                        cleaned = (llm.get("cleaned_description") or description)[:2000]
                        title = (
                            llm.get("title") or f"{pred.asset_name} — voorspellende instandhouding"
                        )[:255]
                        work_instruction = (llm.get("work_instruction") or "")[:2000]
                        ai_status = "ok"
                    except Exception:
                        cleaned = description
                        title = f"{pred.asset_name} — voorspellende instandhouding"
                        work_instruction = ""
                        ai_status = "degraded"

                    draft = jobdraft_service.create_draft(
                        session,
                        user_id=operator.user_id,
                        values={
                            "description": description,
                            "cleaned_description": cleaned,
                            "title": title,
                            "work_instruction": work_instruction,
                            "suggested_type": suggested_type,
                            "suggested_priority": suggested_priority,
                            "failure_category": "predictive",
                            "language": "af",
                            "asset_ids": json.dumps([pred.asset_id]),
                            "room_ids": "[]",
                            "resolved_asset_id": pred.asset_id,
                            "resolved_room_id": None,
                            "duplicate_of": None,
                            "ai_status": ai_status,
                            "source": "auto",
                            "status": "draft",
                        },
                    )
                    created.append(draft.draft_id)
                except Exception:
                    logger.exception(
                        "Auto-draft misluk vir bate %s — oorslaan.",
                        getattr(pred, "asset_id", "?"),
                    )

            # Yield to DB between batches
            if i + AUTO_DRAFT_BATCH_SIZE < len(preds):
                import time
                time.sleep(AUTO_DRAFT_BATCH_DELAY)

        # Fan out one notification for the whole batch — never let it fail the scan.
        if created:
            try:
                notif_svc = NotificationService(session)
                notif_svc.notify_admins(
                    notification_type="ai.draft_created",
                    title="Nuwe AI-werkskonsepte",
                    message=f"{len(created)} AI-werkskonsepte gegenereer uit voorspellende data.",
                    actor_id=operator.user_id,
                    reference_type="jobdraft",
                    reference_id=created[0],
                )
            except Exception:
                logger.exception("Kennisgewing-na-uitsaai misluk ná outomatiese AI-konsepte.")
    return created


async def auto_draft_loop():
    """Background loop: scan for new auto-drafts every AI_AUTO_DRAFT_INTERVAL.

    The scan is synchronous (several queries per asset), so it runs in a
    worker thread via ``asyncio.to_thread`` to keep the event loop responsive.
    Check-then-create dedup assumes a single scheduler worker — running
    multiple uvicorn workers would need a unique constraint on resolved_asset_id.
    """
    # Staggered startup: random delay to prevent thundering herd on multi-worker deployments
    startup_delay = random.uniform(0, 30)
    logger.info(f"Auto-draft scheduler starting in {startup_delay:.1f}s (staggered)")
    await asyncio.sleep(startup_delay)
    
    while True:
        try:
            await asyncio.to_thread(scan_and_create_auto_drafts)
        except Exception as e:
            logger.error(f"Auto-draft loop fout: {e}")
        await asyncio.sleep(AI_AUTO_DRAFT_INTERVAL)
