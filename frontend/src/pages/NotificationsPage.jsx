// =============================================================================
// Kennisgewingsgeskiedenis-bladsy (web)
// Vloei:
//   1) fetchNotifs() roep GET /notifications met filter + paginering
//   2) Gebruiker kan filtreer op tipe / gelees-status
//   3) "Wys voorkeure"-knoppie laai GET /notifications/preferences
//   4) togglePref() stuur PATCH /notifications/preferences vir een veld
//   5) Kliek op 'n item = merk as gelees + navigeer na die verwysing
// =============================================================================
import React, { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../services/api';
import NotificationItem from '../components/Notifications/NotificationItem';
import { useNotificationContext } from '../components/Notifications/NotificationContext';
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import '../components/Notifications/Notifications.css';

// --- Filter-kieslysopsies (stem ooreen met NOTIFICATION_TYPES in die backend) ---
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

// --- Voorkeure per tipe (vir die "Wys voorkeure"-tafel) ---
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

// --- Verstek-voorkeur (as die gebruiker nog geen stel nie) ---
const defaultPref = { in_app_enabled: true, email_enabled: false, push_enabled: true };

function NotificationsPage() {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { markAsRead } = useNotificationContext();

  // --- Lys-toestand ---
  const [notifications, setNotifications] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const perPage = 20;
  const [filterType, setFilterType] = useState('');
  const [filterRead, setFilterRead] = useState('');
  const [loading, setLoading] = useState(true);

  // --- Voorkeure-toestand ---
  const [prefs, setPrefs] = useState({});
  const [prefsOpen, setPrefsOpen] = useState(false);
  const [prefsLoaded, setPrefsLoaded] = useState(false);

  // --- Laai die kennisgewingslys (word weereens geroep na filter/paginering/verwyder) ---
  const fetchNotifs = useCallback(async () => {
    setLoading(true);

    try {
      const params = { page, per_page: perPage };
      if (filterType) params.notification_type = filterType;
      if (filterRead !== '') params.is_read = filterRead === 'read';
      const res = await apiClient.get('/notifications', { params });
      setNotifications(res.data.items || []);
      setTotal(res.data.total || 0);
    } catch (err) {
      showToast({ type: 'error', message: err.response?.data?.detail || 'Kon nie kennisgewings laai nie.' });
    } finally {
      setLoading(false);
    }
  }, [page, perPage, filterType, filterRead]);

  // --- Herlaai wanneer filter/paginering verander ---
  useEffect(() => { fetchNotifs(); }, [fetchNotifs]);

  // --- Laai gebruiker-voorkeure (net een keer) ---
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
      showToast({ type: 'error', title: 'Fout', message: 'Kon nie voorkeure laai nie' });
    }
  };

  // --- Skakel een voorkeur-veld aan/af en stoor dit op die bediener ---
  const togglePref = async (type, field) => {
    const current = (prefs[type] || defaultPref)[field];
    const newVal = !current;
    setPrefs(prev => ({
      ...prev,
      [type]: { ...(prev[type] || defaultPref), [field]: newVal },
    }));
    try {
      await apiClient.patch('/notifications/preferences', [
        { notification_type: type, [field]: newVal },
      ]);
    } catch (err) {
      // Terugrol as die versoek misluk
      setPrefs(prev => ({
        ...prev,
        [type]: { ...(prev[type] || defaultPref), [field]: current },
      }));
      showToast({ type: 'error', title: 'Fout', message: 'Kon nie voorkeur stoor nie' });
    }
  };

  // --- Kliek op 'n kennisgewing: merk as gelees + navigeer na verwysing ---
  const handleClick = (notif) => {
    if (!notif.is_read) markAsRead(notif.notification_id);
    const refMap = { fault: '/fault-tickets', job: '/work-orders', stock: '/stock', asset: '/assets', calendar: '/calendar' };
    const path = refMap[notif.reference_type];
    if (path) window.location.href = path;
  };

  // --- Verwyder een kennisgewing (met bevestiging) ---
  const handleDelete = async (id, e) => {
    e.stopPropagation();
    const confirmed = await confirm({
      message: 'Is jy seker jy wil hierdie kennisgewing verwyder?',
      variant: 'danger',
      confirmLabel: 'Verwyder',
      cancelLabel: 'Kanselleer'
    });
    if (!confirmed) return;
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
    <div className="main">
    <div className="content">
      <div className="notif-page">
            <div className="notif-page-header">
              <h2>Kennisgewingsgeskiedenis</h2>
              <span style={{ color: '#666', fontSize: '13px' }}>{total} totaal</span>
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
                        <th className="toggle-cell">E-pos</th>
                        <th className="toggle-cell">Stoot</th>
                      </tr>
                    </thead>
                    <tbody>
                      {prefGroups.map(group => (
                        <React.Fragment key={group}>
                          <tr><td colSpan={4} style={{ fontWeight: 700, color: '#0e1e3b', background: '#eef3fa', padding: '10px 14px' }}>{group}</td></tr>
                          {PREF_TYPES.filter(t => t.group === group).map(t => {
                            const p = prefs[t.type] || defaultPref;
                            return (
                              <tr key={t.type}>
                                <td>{t.label}</td>
                                <td className="toggle-cell">
                                  <label className="toggle-switch">
                                    <input type="checkbox" checked={p.in_app_enabled} onChange={() => togglePref(t.type, 'in_app_enabled')} />
                                    <span className="toggle-slider" />
                                  </label>
                                </td>
                                <td className="toggle-cell">
                                  <label className="toggle-switch">
                                    <input type="checkbox" checked={p.email_enabled} onChange={() => togglePref(t.type, 'email_enabled')} />
                                    <span className="toggle-slider" />
                                  </label>
                                </td>
                                <td className="toggle-cell">
                                  <label className="toggle-switch">
                                    <input type="checkbox" checked={p.push_enabled} onChange={() => togglePref(t.type, 'push_enabled')} />
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
                      onClick={(e) => handleDelete(n.notification_id, e)}
                      style={{
                        background: 'none', border: 'none', color: '#dc3545',
                        cursor: 'pointer', fontSize: '16px', padding: '4px',
                        alignSelf: 'center'
                      }}
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
      {dialog}
        </div>
    </div>
  );
}

export default NotificationsPage;
