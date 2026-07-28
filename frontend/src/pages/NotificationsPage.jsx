import React, { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../services/api';
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import UserProfileHeader from '../components/UserProfileHeader';
import NotificationItem from '../components/Notifications/NotificationItem';
import { useNotificationContext } from '../components/Notifications/NotificationContext';
import { useToast } from '../components/Toast/useToast';
import '../components/Notifications/Notifications.css';

const TYPE_OPTIONS = [
  { value: '', label: 'Alle tipes' },
  { value: 'fault.created', label: 'Fout Aangeteken' },
  { value: 'fault.assigned', label: 'Fout Toegewys' },
  { value: 'fault.resolved', label: 'Fout Opgelos' },
  { value: 'fault.status_changed', label: 'Fout Status Verander' },
  { value: 'job.created', label: 'Werksopdrag Geskep' },
  { value: 'job.assigned', label: 'Werksopdrag Toegewys' },
  { value: 'job.status_changed', label: 'Status Verandering' },
  { value: 'stock.low', label: 'Lae Voorraad' },
  { value: 'system.announcement', label: 'Aankondiging' },
  { value: 'calendar.reminder', label: 'Kalender Herinnering' },
];

const PREF_TYPES = [
  { type: 'fault.created', label: 'Fout Aangeteken', group: 'Foute' },
  { type: 'fault.assigned', label: 'Fout Toegewys', group: 'Foute' },
  { type: 'fault.resolved', label: 'Fout Opgelos', group: 'Foute' },
  { type: 'fault.status_changed', label: 'Fout Status Verander', group: 'Foute' },
  { type: 'job.created', label: 'Werksopdrag Geskep', group: 'Werksopdragte' },
  { type: 'job.assigned', label: 'Werksopdrag Toegewys', group: 'Werksopdragte' },
  { type: 'job.status_changed', label: 'Status Verandering', group: 'Werksopdragte' },
  { type: 'stock.low', label: 'Lae Voorraad', group: 'Voorraad' },
  { type: 'system.announcement', label: 'Aankondiging', group: 'Stelsel' },
  { type: 'calendar.reminder', label: 'Kalender Herinnering', group: 'Kalender' },
];

const defaultPref = { in_app_enabled: true };

function NotificationsPage() {
  const logout = useLogout();
  const { showToast } = useToast();
  const { markAsRead } = useNotificationContext();
  const [notifications, setNotifications] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [perPage] = useState(20);
  const [filterType, setFilterType] = useState('');
  const [filterRead, setFilterRead] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [prefs, setPrefs] = useState({});
  const [prefsOpen, setPrefsOpen] = useState(false);
  const [prefsLoaded, setPrefsLoaded] = useState(false);

  const fetchNotifs = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = { page, per_page: perPage };
      if (filterType) params.notification_type = filterType;
      if (filterRead !== '') params.is_read = filterRead === 'read';
      const res = await apiClient.get('/notifications', { params });
      setNotifications(res.data.items || []);
      setTotal(res.data.total || 0);
    } catch (err) {
      setError(err.response?.data?.detail || 'Kon nie kennisgewings laai nie.');
    } finally {
      setLoading(false);
    }
  }, [page, perPage, filterType, filterRead]);

  useEffect(() => { fetchNotifs(); }, [fetchNotifs]);

  const fetchPrefs = async () => {
    if (prefsLoaded) return;
    try {
      const res = await apiClient.get('/notifications/preferences');
      const prefMap = {};
      (res.data || []).forEach(p => {
        prefMap[p.notification_type] = p;
      });
      setPrefs(prefMap);
      setPrefsLoaded(true);
    } catch (err) {
      console.error('Failed to load preferences', err);
    }
  };

  const togglePref = async (type) => {
    const current = (prefs[type] || defaultPref).in_app_enabled;
    const newVal = !current;
    setPrefs(prev => ({
      ...prev,
      [type]: { ...(prev[type] || defaultPref), in_app_enabled: newVal },
    }));
    try {
      await apiClient.patch('/notifications/preferences', [
        { notification_type: type, in_app_enabled: newVal },
      ]);
    } catch (err) {
      setPrefs(prev => ({
        ...prev,
        [type]: { ...(prev[type] || defaultPref), in_app_enabled: current },
      }));
      showToast({ type: 'error', title: 'Fout', message: 'Kon nie voorkeur stoor nie' });
    }
  };

  const handleClick = (notif) => {
    if (!notif.is_read) markAsRead(notif.notification_id);
    const refMap = { fault: '/fault-tickets', job: '/work-orders', stock: '/stock', asset: '/assets', calendar: '/calendar' };
    const path = refMap[notif.reference_type];
    if (path) window.location.href = path;
  };

  const handleDelete = async (id, e) => {
    e.stopPropagation();
    try {
      await apiClient.delete(`/notifications/${id}`);
      showToast({ type: 'success', title: 'Verwyder', message: 'Kennisgewing verwyder' });
      fetchNotifs();
    } catch (err) {
      showToast({ type: 'error', title: 'Fout', message: 'Kon nie kennisgewing verwyder nie' });
    }
  };

  const totalPages = Math.ceil(total / perPage);
  const prefGroups = [...new Set(PREF_TYPES.map(t => t.group))];

  return (
    <div style={{ display: 'flex' }}>
      <Sidebar currentPath="/notifications" onLogout={logout} />
      <div className="main">
        <div className="navbar">
          <h3>Kennisgewings</h3>
          <UserProfileHeader />
        </div>
        <div className="content">
          <div className="notif-page">
            <div className="notif-page-header">
              <h2>Kennisgewingsgeskiedenis</h2>
              <span style={{ color: '#666', fontSize: '13px' }}>{total} totaal</span>
            </div>

            <div className="analytics-grid" style={{ marginBottom: '16px' }}>
              <div className="analytics-card"><h4>Totale Kennisgewings</h4><p className="analytics-value">{notifications.length}</p></div>
              <div className="analytics-card"><h4>Ongelees</h4><p className="analytics-value warning">{notifications.filter(n => !n.is_read).length}</p></div>
              <div className="analytics-card"><h4>Foute</h4><p className="analytics-value">{notifications.filter(n => n.notification_type?.startsWith('fault')).length}</p></div>
              <div className="analytics-card"><h4>Werksopdragte</h4><p className="analytics-value">{notifications.filter(n => n.notification_type?.startsWith('job')).length}</p></div>
            </div>

            <div className="notif-page-filters">
              <select value={filterType} onChange={e => { setFilterType(e.target.value); setPage(1); }}>
                {TYPE_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
              <select value={filterRead} onChange={e => { setFilterRead(e.target.value); setPage(1); }}>
                <option value="">Alle status</option>
                <option value="unread">Ongelees</option>
                <option value="read">Gelees</option>
              </select>
              <button
                className="btn-cancel"
                style={{ marginLeft: 'auto', fontSize: '13px' }}
                onClick={() => { setPrefsOpen(!prefsOpen); if (!prefsLoaded) fetchPrefs(); }}
              >
                {prefsOpen ? 'Versteek voorkeure' : 'Wys voorkeure'}
              </button>
            </div>

            {prefsOpen && (
              <div style={{ marginBottom: '20px', border: '1px solid #e0e0e0', borderRadius: '8px', overflow: 'hidden' }}>
                <table className="notif-prefs-table" style={{ margin: 0 }}>
                  <thead>
                    <tr>
                      <th>Tipe</th>
                      <th className="toggle-cell">In-App</th>
                    </tr>
                  </thead>
                  <tbody>
                    {prefGroups.map(group => (
                      <React.Fragment key={group}>
                        <tr><td colSpan={2} style={{ fontWeight: 700, color: '#0e1e3b', background: '#eef3fa', padding: '10px 14px' }}>{group}</td></tr>
                        {PREF_TYPES.filter(t => t.group === group).map(t => {
                          const p = prefs[t.type] || defaultPref;
                          return (
                            <tr key={t.type}>
                              <td>{t.label}</td>
                              <td className="toggle-cell">
                                <label className="toggle-switch">
                                  <input type="checkbox" checked={p.in_app_enabled} onChange={() => togglePref(t.type)} />
                                  <span className="toggle-slider" />
                                </label>
                              </td>
                            </tr>
                          );
                        })}
                      </React.Fragment>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {error && <div style={{ color: '#dc3545', padding: '10px', marginBottom: '10px', backgroundColor: '#f8d7da', borderRadius: '4px' }}>{error}</div>}

            {loading ? (
              <div style={{ textAlign: 'center', padding: '40px', color: '#999' }}>Laai...</div>
            ) : notifications.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px', color: '#999' }}>Geen kennisgewings nie</div>
            ) : (
              <div className="notif-page-list">
                {notifications.map(n => (
                  <div key={n.notification_id} className={`notif-page-item${n.is_read ? '' : ' unread'}`} onClick={() => handleClick(n)}>
                    <div style={{ flex: 1 }}>
                      <NotificationItem notification={n} isUnread={!n.is_read} onClick={() => {}} />
                    </div>
                    <button
                      className="btn-delete"
                      onClick={(e) => handleDelete(n.notification_id, e)}
                      style={{ background: 'none', border: 'none', color: '#dc3545', cursor: 'pointer', fontSize: '16px', padding: '4px', alignSelf: 'center' }}
                      title="Verwyder"
                    >
                      &times;
                    </button>
                  </div>
                ))}
              </div>
            )}

            {totalPages > 1 && (
              <div style={{ display: 'flex', justifyContent: 'center', gap: '8px', marginTop: '20px', alignItems: 'center' }}>
                <button className="btn-cancel" onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page <= 1} style={{ opacity: page <= 1 ? 0.5 : 1 }}>Vorige</button>
                <span style={{ fontSize: '13px', color: '#666' }}>Bladsy {page} van {totalPages}</span>
                <button className="btn-cancel" onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page >= totalPages} style={{ opacity: page >= totalPages ? 0.5 : 1 }}>Volgende</button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default NotificationsPage;
