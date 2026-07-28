import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import { apiClient } from '../../services/api';
import { useToast } from '../Toast/useToast';

const NotificationContext = createContext(null);

const POLL_INTERVAL = 20000;

const TYPE_LABELS = {
  'fault.created': 'Fout Aangeteken',
  'fault.assigned': 'Fout Toegewys',
  'fault.resolved': 'Fout Opgelos',
  'job.created': 'Werksopdrag Geskep',
  'job.assigned': 'Werksopdrag Toegewys',
  'job.status_changed': 'Status Verandering',
  'stock.low': 'Lae Voorraad',
  'system.announcement': 'Aankondiging',
};

export function NotificationProvider({ children }) {
  const [unreadCount, setUnreadCount] = useState(0);
  const [latestNotifs, setLatestNotifs] = useState([]);
  const [loading, setLoading] = useState(false);
  const pollingRef = useRef(null);
  const prevCountRef = useRef(0);
  const { showToast } = useToast();

  const fetchUnread = useCallback(async () => {
    if (!sessionStorage.getItem('token')) return;
    try {
      setLoading(true);
      const res = await apiClient.get('/notifications/unread');
      const data = res.data;
      setUnreadCount(data.unread_count);
      setLatestNotifs(data.latest || []);

      if (data.unread_count > prevCountRef.current) {
        const newNotifs = (data.latest || []).filter(
          n => !prevCountRef.current || !latestNotifs.find(old => old.notification_id === n.notification_id)
        );
        newNotifs.forEach(n => {
          showToast({
            type: 'info',
            title: TYPE_LABELS[n.notification_type] || 'Kennisgewing',
            message: n.title,
            duration: 5000,
          });
        });
      }
      prevCountRef.current = data.unread_count;
    } catch (err) {
      if (err.response?.status !== 401) {
        console.warn('Polling notifications failed:', err);
      }
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    if (!sessionStorage.getItem('token')) return;
    fetchUnread();
    pollingRef.current = setInterval(fetchUnread, POLL_INTERVAL);
    return () => {
      if (pollingRef.current) clearInterval(pollingRef.current);
    };
  }, [fetchUnread]);

  const markAsRead = useCallback(async (id) => {
    try {
      await apiClient.patch(`/notifications/${id}/read`);
      setUnreadCount(prev => Math.max(0, prev - 1));
      setLatestNotifs(prev => prev.filter(n => n.notification_id !== id));
    } catch (err) {
      console.error('Failed to mark as read:', err);
    }
  }, []);

  const markAllAsRead = useCallback(async () => {
    try {
      await apiClient.patch('/notifications/read-all');
      setUnreadCount(0);
      setLatestNotifs([]);
    } catch (err) {
      console.error('Failed to mark all as read:', err);
    }
  }, []);

  const value = {
    unreadCount,
    latestNotifs,
    loading,
    fetchUnread,
    markAsRead,
    markAllAsRead,
  };

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  );
}

export function useNotificationContext() {
  const ctx = useContext(NotificationContext);
  if (!ctx) throw new Error('useNotificationContext must be used within NotificationProvider');
  return ctx;
}
