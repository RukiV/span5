# =============================================================================
# API-eindpunte vir die kennisgewingstelsel
# Vloei:  frontend (web/mobiel) → hierdie endpoints → NotificationService → modelle
# Elk van die endpoints gebruik require_right(...) vir regtebeheer.
# =============================================================================
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlmodel import Session
from ....db.database import getSession
from ....auth.permissions import get_current_user
from ....auth.permissions import require_right
from ....models.user import User
from ....models.notification import NotificationRead, NotificationPreference, NotificationPreferenceUpdate, DeviceTokenRegister, DeviceTokenUnregister
from ....services.notification_service import NotificationService, NOTIFICATION_TYPES

router = APIRouter()

def get_notif_service(session: Session = Depends(getSession)):
    return NotificationService(session)

# --- Lys kennisgewings met filter (tipe, gelees/ongelees) en paginering ---
@router.get("", response_model=dict)
def list_notifications(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    notification_type: Optional[str] = None,
    is_read: Optional[bool] = None,
    current_user: User = Depends(require_right("notifications.view")),
    service: NotificationService = Depends(get_notif_service),
):
    items, total = service.get_user_notifications(
        user_id=current_user.user_id,
        page=page,
        per_page=per_page,
        notification_type=notification_type,
        is_read=is_read,
    )
    return {
        "items": [NotificationRead.model_validate(n) for n in items],
        "total": total,
        "page": page,
        "per_page": per_page,
    }

# --- Kry ongelees-telling + die 5 mees onlangse (vir die navbar-kenteken en toast-voorskou) ---
@router.get("/unread")
def get_unread(
    current_user: User = Depends(require_right("notifications.view")),
    service: NotificationService = Depends(get_notif_service),
):
    count = service.get_unread_count(current_user.user_id)
    items, _ = service.get_user_notifications(current_user.user_id, page=1, per_page=5, is_read=False)
    return {
        "unread_count": count,
        "latest": [NotificationRead.model_validate(n) for n in items],
    }

# --- Merk een kennisgewing as gelees ---
@router.patch("/{notification_id}/read")
def mark_read(
    notification_id: int,
    current_user: User = Depends(require_right("notifications.view")),
    service: NotificationService = Depends(get_notif_service),
):
    ok = service.mark_read(current_user.user_id, notification_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"ok": True}

# --- Merk alle kennisgewings as gelees ---
@router.patch("/read-all")
def mark_all_read(
    current_user: User = Depends(require_right("notifications.view")),
    service: NotificationService = Depends(get_notif_service),
):
    count = service.mark_all_read(current_user.user_id)
    return {"ok": True, "count": count}

# --- Verwyder een kennisgewing permanent ---
@router.delete("/{notification_id}")
def delete_notification(
    notification_id: int,
    current_user: User = Depends(require_right("notifications.view")),
    service: NotificationService = Depends(get_notif_service),
):
    ok = service.delete_notification(current_user.user_id, notification_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"ok": True}

# --- Laai die huidige gebruiker se voorkeure (per kennisgewing-tipe) ---
@router.get("/preferences")
def get_preferences(
    current_user: User = Depends(require_right("notifications.manage")),
    service: NotificationService = Depends(get_notif_service),
):
    prefs = service.get_preferences(current_user.user_id)
    return prefs

@router.patch("/preferences")
def update_preferences(
    updates: list[dict],
    current_user: User = Depends(require_right("notifications.manage")),
    service: NotificationService = Depends(get_notif_service),
):
    results = []
    for u in updates:
        pref = service.update_preference(
            user_id=current_user.user_id,
            notification_type=u["notification_type"],
            in_app_enabled=u.get("in_app_enabled"),
            email_enabled=u.get("email_enabled"),
            push_enabled=u.get("push_enabled"),
        )
        results.append(pref)
    return results

@router.post("/send")
def send_announcement(
    payload: dict,
    current_user: User = Depends(require_right("notifications.send")),
    service: NotificationService = Depends(get_notif_service),
):
    from ....models.user import User as UserModel
    from sqlmodel import select
    stmt = select(UserModel).where(UserModel.user_status == "active")
    users = service.session.exec(stmt).all()
    count = 0
    for u in users:
        n = service.create_notification(
            user_id=u.user_id,
            notification_type="system.announcement",
            title=payload.get("title", "Announcement"),
            message=payload.get("message", ""),
            actor_id=current_user.user_id,
        )
        if n:
            count += 1
    return {"ok": True, "sent_to": count}

@router.post("/device-token")
def register_device(
    body: DeviceTokenRegister,
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notif_service),
):
    service.register_device_token(current_user.user_id, body.fcm_token, body.platform)
    return {"ok": True}

@router.delete("/device-token")
def unregister_device(
    body: DeviceTokenUnregister,
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notif_service),
):
    service.unregister_device_token(current_user.user_id, body.fcm_token)
    return {"ok": True}
