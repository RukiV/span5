import logging
from typing import Optional
from sqlmodel import Session, select, func
from ..models.notification import Notification, NotificationCreate, NotificationPreference, DeviceToken

logger = logging.getLogger(__name__)

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    _FIREBASE_AVAILABLE = True
except ImportError:
    _FIREBASE_AVAILABLE = False
    messaging = None

def _init_firebase():
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

NOTIFICATION_TYPES = [
    "fault.created", "fault.assigned", "fault.resolved", "fault.status_changed",
    "job.created", "job.assigned", "job.status_changed",
    "stock.low",
    "system.announcement",
    "calendar.reminder",
]

class NotificationService:
    def __init__(self, session: Session):
        self.session = session

    def _send_fcm_push(self, user_id: int, title: str, body: str, data: Optional[dict] = None):
        if not _FIREBASE_INITIALIZED:
            logger.debug(f"[FCM placeholder] Would push to user {user_id}: {title}")
            return
        tokens = self.session.exec(
            select(DeviceToken).where(DeviceToken.user_id == user_id)
        ).all()
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
        self._send_fcm_push(
            user_id=user_id,
            title=title,
            body=message,
            data={"type": notification_type, "reference_id": str(reference_id or "")},
        )
        return notif

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

    def get_unread_count(self, user_id: int) -> int:
        stmt = select(func.count(Notification.notification_id)).where(
            Notification.user_id == user_id,
            Notification.is_read == False,
        )
        return self.session.exec(stmt).one()

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

    def get_preferences(self, user_id: int):
        stmt = select(NotificationPreference).where(NotificationPreference.user_id == user_id)
        return self.session.exec(stmt).all()

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

    # --- Helper to notify users by location (terrein) ---
    def notify_location_users(self, location_id: int, notification_type: str, title: str, message: str,
                               actor_id: Optional[int] = None,
                               reference_type: Optional[str] = None, reference_id: Optional[int] = None):
        from ..models.user import User
        stmt = select(User).where(
            User.location_id == location_id,
            User.user_status == "active",
        )
        users = self.session.exec(stmt).all()
        for user in users:
            self.create_notification(
                user_id=user.user_id,
                notification_type=notification_type,
                title=title,
                message=message,
                actor_id=actor_id,
                reference_type=reference_type,
                reference_id=reference_id,
            )

    # --- Helper to notify all admins ---
    def notify_admins(self, notification_type: str, title: str, message: str,
                      actor_id: Optional[int] = None,
                      reference_type: Optional[str] = None, reference_id: Optional[int] = None):
        from ..models.user import User
        from ..auth.rights_catalog import ROLE_ADMIN
        stmt = select(User).where(
            User.role_id == ROLE_ADMIN,
            User.user_status == "active",
        )
        users = self.session.exec(stmt).all()
        for user in users:
            self.create_notification(
                user_id=user.user_id,
                notification_type=notification_type,
                title=title,
                message=message,
                actor_id=actor_id,
                reference_type=reference_type,
                reference_id=reference_id,
            )
