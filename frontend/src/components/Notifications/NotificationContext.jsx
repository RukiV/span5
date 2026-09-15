// =============================================================================
// Konteks-verskaffer vir die kennisgewingstelsel (web)
// Vloei:  NotificationProvider omhul AppContent in App.jsx
//         1) Laai ongelees-telling + nuutste 5 d.m.v. polling elke 20s
//         2) As die telling styg, wys 'n toast vir elke nuwe kennisgewing
//         3) Bied markAsRead / markAllAsRead aan die res van die app
// =============================================================================
import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import { apiClient } from '../../services/api';
import { useToast } from '../Toast/useToast';

const NotificationContext = createContext(null);

// --- Peil elke 20 sekondes of daar nuwe kennisgewings is ---
const POLL_INTERVAL = 20000;

// --- Afrikaanse etikette vir toast-title ---
const TYPE_LABELS = {
  'fault.created': 'Fout Aangeteken',
  'fault.assigned': 'Fout Toegewys',
  'fault.resolved': 'Fout Opgelos',
  'fault.status_changed': 'Fout Status Verander',
  'job.created': 'Werksopdrag Geskep',
  'job.assigned': 'Werksopdrag Toegewys',
  'job.status_changed': 'Status Verandering',
  'stock.low': 'Lae Voorraad',
  'system.announcement': 'Aankondiging',
  'calendar.reminder': 'Kalender Herinnering',
};

export function NotificationProvider({ children }) {
  const [unreadCount, setUnreadCount] = useState(0);   // vir die kenteken op die bel-ikoon
  const [latestNotifs, setLatestNotifs] = useState([]); // vir die rooster-voorskou
  const [loading, setLoading] = useState(false);
  const pollingRef = useRef(null);
  const prevCountRef = useRef(0);  // hou vorige telling om toename te bespeur
  const latestRef = useRef([]);    // hou vorige lys (sonder om state-deps te verander)
  const { showToast } = useToast();
  const showToastRef = useRef(showToast);

  // Hou die nuutste showToast in 'n ref sodat fetchUnread stabiel bly
  useEffect(() => {
    showToastRef.current = showToast;
  }, [showToast]);

  // --- Haal die ongelees-telling + nuutste 5 van die bediener ---
  const fetchUnread = useCallback(async () => {
    if (!sessionStorage.getItem('token')) return;
    try {
      setLoading(true);
      const res = await apiClient.get('/notifications/unread');
      const data = res.data;
      setUnreadCount(data.unread_count);
      const newLatest = data.latest || [];
      setLatestNotifs(newLatest);

      // --- Wys 'n toast as die telling toegeneem het (nuwe kennisgewing) ---
      // prevCountRef > 0 keer dat die eerste laai nie 'n vloed toasts stuur nie
      if (prevCountRef.current > 0 && data.unread_count > prevCountRef.current) {
        const newNotifs = newLatest.filter(
          n => !latestRef.current.find(old => old.notification_id === n.notification_id)
        );
        newNotifs.forEach(n => {
          showToastRef.current({
            type: 'info',
            title: TYPE_LABELS[n.notification_type] || 'Kennisgewing',
            message: n.title,
            duration: 5000,
          });
        });
      }
      prevCountRef.current = data.unread_count;
      latestRef.current = newLatest;
    } catch (err) {
      if (err.response?.status !== 401) {
        console.warn('Polling notifications failed:', err);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  // --- Begin / stop polling wanneer die komponent monteer/ontmonteer ---
  useEffect(() => {
    if (!sessionStorage.getItem('token')) return;
    fetchUnread();
    pollingRef.current = setInterval(fetchUnread, POLL_INTERVAL);
    return () => {
      if (pollingRef.current) clearInterval(pollingRef.current);
    };
  }, [fetchUnread]);

  // --- Merk een as gelees (in die databasis en plaaslik) ---
  const markAsRead = useCallback(async (id) => {
    try {
      await apiClient.patch(`/notifications/${id}/read`);
      setUnreadCount(prev => Math.max(0, prev - 1));
      setLatestNotifs(prev => prev.filter(n => n.notification_id !== id));
    } catch (err) {
      showToast({ type: 'error', title: 'Fout', message: 'Kon nie as gelees merk nie' });
    }
  }, []);

  // --- Merk alles as gelees ---
  const markAllAsRead = useCallback(async () => {
    try {
      await apiClient.patch('/notifications/read-all');
      setUnreadCount(0);
      setLatestNotifs([]);
    } catch (err) {
      showToast({ type: 'error', title: 'Fout', message: 'Kon nie alle as gelees merk nie' });
    }
  }, []);

  // --- Waardes wat die res van die app via useNotificationContext() kan gebruik ---
  const value = {
    unreadCount,     // aantal ongelees (vir NotificationBell)
    latestNotifs,    // onlangse kennisgewings (vir die aftrekkie)
    loading,
    fetchUnread,     // dwing 'n peilingsiklus af
    markAsRead,
    markAllAsRead,
  };

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  );
}

// --- Verbruiker-haak — gee 'n fout as dit buite die Provider gebruik word ---
export function useNotificationContext() {
  const ctx = useContext(NotificationContext);
  if (!ctx) throw new Error('useNotificationContext must be used within NotificationProvider');
  return ctx;
}
