import React, { useState, useRef, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { IoNotificationsOutline } from 'react-icons/io5';
import { useNotificationContext } from './NotificationContext';
import NotificationItem from './NotificationItem';
import './Notifications.css';

function NotificationBell() {
  const { unreadCount, latestNotifs, markAsRead, markAllAsRead } = useNotificationContext();
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    if (!open) return;
    const handler = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [open]);

  const handleClick = (notif) => {
    markAsRead(notif.notification_id);
    setOpen(false);
    const refMap = {
      fault: '/fault-tickets',
      job: '/work-orders',
      stock: '/stock',
      asset: '/assets',
      calendar: '/calendar',
    };
    const path = refMap[notif.reference_type];
    if (path) window.location.href = path;
  };

  return (
    <div ref={ref} style={{ position: 'relative' }}>
      <div className="notif-bell-wrapper" onClick={() => setOpen(!open)}>
        <IoNotificationsOutline className="notif-bell-icon" />
        {unreadCount > 0 && (
          <span className="notif-badge">{unreadCount > 99 ? '99+' : unreadCount}</span>
        )}
      </div>
      {open && (
        <div className="notif-dropdown">
          <div className="notif-dropdown-header">
            <span>Kennisgewings</span>
            {unreadCount > 0 && (
              <button onClick={markAllAsRead}>Merk almal as gelees</button>
            )}
          </div>
          <div className="notif-dropdown-list">
            {latestNotifs.length === 0 ? (
              <div className="notif-empty">Geen nuwe kennisgewings nie</div>
            ) : (
              latestNotifs.map(n => (
                <NotificationItem
                  key={n.notification_id}
                  notification={n}
                  isUnread={!n.is_read}
                  onClick={handleClick}
                />
              ))
            )}
          </div>
          <div className="notif-dropdown-footer">
            <Link to="/notifications" onClick={() => setOpen(false)}>Sien alle kennisgewings</Link>
          </div>
        </div>
      )}
    </div>
  );
}

export default NotificationBell;
