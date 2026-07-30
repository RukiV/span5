import React from 'react';
import { IoNotifications, IoBug, IoConstruct, IoWarning, IoCalendar, IoMegaphone } from 'react-icons/io5';

const TYPE_ICONS = {
  'fault.created': IoBug,
  'fault.assigned': IoBug,
  'fault.resolved': IoBug,
  'fault.status_changed': IoBug,
  'job.created': IoConstruct,
  'job.assigned': IoConstruct,
  'job.status_changed': IoConstruct,
  'stock.low': IoWarning,
  'system.announcement': IoMegaphone,
  'calendar.reminder': IoCalendar,
};

const TYPE_COLORS = {
  'fault.created': '#dc3545',
  'fault.assigned': '#e0a800',
  'fault.resolved': '#28a745',
  'fault.status_changed': '#6f42c1',
  'job.created': '#2a5f9e',
  'job.assigned': '#935e28',
  'job.status_changed': '#6f42c1',
  'stock.low': '#dc3545',
  'system.announcement': '#0e1e3b',
  'calendar.reminder': '#0e1e3b',
};

function timeAgo(dateStr) {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diff = Math.floor((now - then) / 1000);
  if (diff < 60) return 'Nou net';
  if (diff < 3600) return `${Math.floor(diff / 60)}m gelede`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h gelede`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}d gelede`;
  return new Date(dateStr).toLocaleDateString('af-ZA');
}

function NotificationItem({ notification, isUnread, onClick }) {
  const Icon = TYPE_ICONS[notification.notification_type] || IoNotifications;
  const color = TYPE_COLORS[notification.notification_type] || '#666';

  return (
    <div
      className={`notif-item${isUnread ? ' unread' : ''}`}
      onClick={() => onClick?.(notification)}
    >
      <Icon className="notif-item-icon" style={{ color }} />
      <div className="notif-item-content">
        <div className="notif-item-title">{notification.title}</div>
        <div className="notif-item-message">{notification.message}</div>
        <div className="notif-item-time">{timeAgo(notification.created_at)}</div>
      </div>
    </div>
  );
}

export default NotificationItem;
export { timeAgo };
