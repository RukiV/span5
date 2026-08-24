# =============================================================================
# Kern-logika vir die kennisgewingstelsel
# Vloei:  endpoint → NotificationService.create_notification()
#         → 1) laai gebruiker-voorkeur  → 2) as in_app_enabled=False, los
#         → 3) stoor Notification in DB   → 4) as push_enabled, stuur FCM
# =============================================================================
import logging
from typing import Optional
from sqlmodel import Session, select, func
from ..models.notification import Notification, NotificationCreate, NotificationPreference, DeviceToken

logger = logging.getLogger(__name__)

# --- Firebase/FCM vir stootkennisgewings (mobiele app) ---
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    _FIREBASE_AVAILABLE = True
except ImportError:
    _FIREBASE_AVAILABLE = False
    messaging = None

def _init_firebase():
    """Laai Firebase-sertifikaat eenmalig. As dit misluk, werk stootkennisgewings nie."""
    if not _FIREBASE_AVAILABLE:
        return False
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate("firebase-service-account.json")
            firebase_admin.initialize_app(cred)
        return True
    except Exception as e:
        logger.warning(f"Firebase init failed (push notifications disabled): {e}")
        return False

_FIREBASE_INITIALIZED = _init_firebase()

# --- Alle geldige kennisgewing-tipes wat die stelsel ken ---
NOTIFICATION_TYPES = [
    "fault.created", "fault.assigned", "fault.resolved", "fault.status_changed",
    "job.created", "job.assigned", "job.status_changed", "job.completion_requested",
    "stock.low",
    "system.announcement",
    "calendar.reminder",
]

class NotificationService:
    """Sentrale diensklas — elk van die endpoints in notifications.py roep hierdie klas aan."""

    def __init__(self, session: Session):
        self.session = session

    # --- Privaat: stuur Firebase Cloud Message na al die gebruiker se toestelle ---
    def _send_fcm_push(self, user_id: int, title: str, body: str, data: Optional[dict] = None):
        if not _FIREBASE_INITIALIZED:
            logger.debug(f"[FCM placeholder] Would push to user {user_id}: {title}")
            return
        tokens = self.session.exec(
            select(DeviceToken).where(DeviceToken.user_id == user_id)
        ).all()
        logger.info(f"FCM: {len(tokens)} toestel-tokens gevind vir gebruiker {user_id}")
        for t in tokens:
            try:
                msg = messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data={k: str(v) for k, v in (data or {}).items()},
                    token=t.fcm_token,
                )
                messaging.send(msg)
            except Exception as e:
                logger.warning(f"FCM send failed for token {t.fcm_token[:20]}...: {e}")

    # --- Hoof-inskrypingspunt: skep 'n kennisgewing en stuur dit volgens voorkeure ---
    # 1. Haal NotificationPreference vir (user, type)
    # 2. As in_app_enabled=False → los sonder om enigiets te stoor
    # 3. Stoor Notification in die databasis
    # 4. As push_enabled=True (of geen voorkeur) → stuur FCM na alle toestelle
    def create_notification(
        self,
        user_id: int,
        notification_type: str,
        title: str,
        message: str,
        actor_id: Optional[int] = None,
        reference_type: Optional[str] = None,
        reference_id: Optional[int] = None,
    ) -> Optional[Notification]:
        pref = self.session.exec(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id,
                NotificationPreference.notification_type == notification_type,
            )
        ).first()
        if pref and not pref.in_app_enabled:
            return None
        notif = Notification(
            user_id=user_id,
            actor_id=actor_id,
            notification_type=notification_type,
            title=title,
            message=message,
            reference_type=reference_type,
            reference_id=reference_id,
        )
        self.session.add(notif)
        self.session.commit()
        self.session.refresh(notif)
        if not pref or pref.push_enabled:
            self._send_fcm_push(
                user_id=user_id,
                title=title,
                body=message,
                data={"type": notification_type, "reference_id": str(reference_id or "")},
            )
        return notif

    # --- Blaai deur kennisgewings (lysweergawe met filter en paginering) ---
    def get_user_notifications(self, user_id: int, page: int = 1, per_page: int = 20,
                                notification_type: Optional[str] = None, is_read: Optional[bool] = None):
        query = select(Notification).where(Notification.user_id == user_id)
        if notification_type:
            query = query.where(Notification.notification_type == notification_type)
        if is_read is not None:
            query = query.where(Notification.is_read == is_read)
        query = query.order_by(Notification.created_at.desc())
        total = len(self.session.exec(query).all())
        query = query.offset((page - 1) * per_page).limit(per_page)
        items = self.session.exec(query).all()
        return items, total

    # --- Tel hoeveel ongelees vir die koppelvlak-kenteken ---
    def get_unread_count(self, user_id: int) -> int:
        stmt = select(func.count(Notification.notification_id)).where(
            Notification.user_id == user_id,
            Notification.is_read == False,
        )
        return self.session.exec(stmt).one()

    # --- Merk een kennisgewing as gelees ---
    def mark_read(self, user_id: int, notification_id: int) -> bool:
        notif = self.session.exec(
            select(Notification).where(
                Notification.notification_id == notification_id,
                Notification.user_id == user_id,
            )
        ).first()
        if not notif:
            return False
        notif.is_read = True
        self.session.commit()
        return True

    # --- Merk alles as gelees ---
    def mark_all_read(self, user_id: int) -> int:
        stmt = select(Notification).where(
            Notification.user_id == user_id,
            Notification.is_read == False,
        )
        notifs = self.session.exec(stmt).all()
        for n in notifs:
            n.is_read = True
        self.session.commit()
        return len(notifs)

    # --- Verwyder 'n kennisgewing permanent ---
    def delete_notification(self, user_id: int, notification_id: int) -> bool:
        notif = self.session.exec(
            select(Notification).where(
                Notification.notification_id == notification_id,
                Notification.user_id == user_id,
            )
        ).first()
        if not notif:
            return False
        self.session.delete(notif)
        self.session.commit()
        return True

    # --- Laai alle voorkeure vir die huidige gebruiker (per tipe) ---
    def get_preferences(self, user_id: int):
        stmt = select(NotificationPreference).where(NotificationPreference.user_id == user_id)
        return self.session.exec(stmt).all()

    # --- Werk een voorkeur-ry by (skep een as dit nie bestaan nie) ---
    def update_preference(self, user_id: int, notification_type: str,
                          in_app_enabled: Optional[bool] = None,
                          email_enabled: Optional[bool] = None,
                          push_enabled: Optional[bool] = None):
        pref = self.session.exec(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id,
                NotificationPreference.notification_type == notification_type,
            )
        ).first()
        if not pref:
            pref = NotificationPreference(user_id=user_id, notification_type=notification_type)
            self.session.add(pref)
        if in_app_enabled is not None:
            pref.in_app_enabled = in_app_enabled
        if email_enabled is not None:
            pref.email_enabled = email_enabled
        if push_enabled is not None:
            pref.push_enabled = push_enabled
        self.session.commit()
        self.session.refresh(pref)
        return pref

    # --- Teken 'n FCM-toestel-token aan sodat stootkennisgewings die regte foon bereik ---
    def register_device_token(self, user_id: int, fcm_token: str, platform: str):
        existing = self.session.exec(
            select(DeviceToken).where(
                DeviceToken.user_id == user_id,
                DeviceToken.fcm_token == fcm_token,
            )
        ).first()
        if existing:
            existing.platform = platform
        else:
            existing = DeviceToken(user_id=user_id, fcm_token=fcm_token, platform=platform)
            self.session.add(existing)
        self.session.commit()
        return existing

    # --- Verwyder 'n toestel-token (ontkoppel) ---
    def unregister_device_token(self, user_id: int, fcm_token: str):
        existing = self.session.exec(
            select(DeviceToken).where(
                DeviceToken.user_id == user_id,
                DeviceToken.fcm_token == fcm_token,
            )
        ).first()
        if existing:
            self.session.delete(existing)
            self.session.commit()
            return True
        return False

    # --- Hulp: stuur kennisgewing aan alle aktiewe gebruikers by 'n terrein ---
    def notify_location_users(self, location_id: int, notification_type: str, title: str, message: str,
                               actor_id: Optional[int] = None,
                               reference_type: Optional[str] = None, reference_id: Optional[int] = None,
                               exclude_user_ids: Optional[set[int]] = None) -> set[int]:
        from ..auth.rights_catalog import ROLE_CONTRACTOR
        from ..models.user import User
        # Kontrakteurs word uitgesluit: hulle mag slegs kennisgewings ontvang wat
        # direk aan hulle gerig is (bv. hul eie werksopdragte), nie terreinwye uitsaai nie.
        stmt = select(User).where(
            User.location_id == location_id,
            User.role_id != ROLE_CONTRACTOR,
            User.user_status == "active",
        )
        users = self.session.exec(stmt).all()
        notified: set[int] = set()
        for user in users:
            if exclude_user_ids and user.user_id in exclude_user_ids:
                continue
            notified.add(user.user_id)
            self.create_notification(
                user_id=user.user_id,
                notification_type=notification_type,
                title=title,
                message=message,
                actor_id=actor_id,
                reference_type=reference_type,
                reference_id=reference_id,
            )
        return notified

    # --- Hulp: stuur kennisgewing aan alle aktiewe administratore EN FK-bestuurders ---
    def notify_admins(self, notification_type: str, title: str, message: str,
                      actor_id: Optional[int] = None,
                      reference_type: Optional[str] = None, reference_id: Optional[int] = None,
                      exclude_user_ids: Optional[set[int]] = None) -> set[int]:
        from ..models.user import User
        from ..auth.rights_catalog import ROLE_ADMIN, ROLE_FK
        stmt = select(User).where(
            User.role_id.in_([ROLE_ADMIN, ROLE_FK]),
            User.user_status == "active",
        )
        users = self.session.exec(stmt).all()
        notified: set[int] = set()
        for user in users:
            if exclude_user_ids and user.user_id in exclude_user_ids:
                continue
            notified.add(user.user_id)
            self.create_notification(
                user_id=user.user_id,
                notification_type=notification_type,
                title=title,
                message=message,
                actor_id=actor_id,
                reference_type=reference_type,
                reference_id=reference_id,
            )
        return notified
