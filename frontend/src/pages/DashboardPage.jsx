import React, { useEffect, useState, useCallback, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { IoPencil, IoTrashOutline } from 'react-icons/io5';
import { useMsal } from '@azure/msal-react';
import '../styles/App.css';
import '../styles/Dashboard.css';
import '../styles/Calendar.css';
import Modal from '../components/Modal/Modal';
import { authAPI, apiClient, auditsAPI, workOrdersAPI, ticketsAPI, calendarEventsAPI } from '../services/api';
import { analyticsAPI } from '../services/analyticsAPI';
import { loginRequest } from '../services/msalConfig';
import { useCurrentUser } from '../hooks/useCurrentUser';
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';

const formatDateInput = (date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const formatTimeInput = (date) => {
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
};

const getDefaultEventTimes = (baseDate = new Date()) => {
  const start = new Date(baseDate);
  const end = new Date(start);
  end.setHours(end.getHours() + 1);
  return {
    startDate: formatDateInput(start),
    startTime: formatTimeInput(start),
    endDate: formatDateInput(end),
    endTime: formatTimeInput(end)
  };
};

const formatDateKey = (date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const escapeRegExp = (str) => str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const parseClock = (matched) => {
  const hourMin = matched.match(/(\d{1,2})(?::(\d{2}))?/);
  let hours = hourMin ? parseInt(hourMin[1], 10) : 8;
  const minutes = hourMin && hourMin[2] ? parseInt(hourMin[2], 10) : 0;
  const suffix = (matched.match(/(am|pm|vm|nm)$/i) || [])[1];
  if (suffix === 'am' || suffix === 'vm') {
    hours = hours === 12 ? 0 : hours;
  } else if (suffix === 'pm' || suffix === 'nm') {
    hours = hours === 12 ? 12 : hours + 12;
  }
  return { hours, minutes };
};

export const parseTimeFromText = (text) => {
  let cleanTitle = String(text || '').trim();
  let hours = 8;
  let minutes = 0;
  let endHours = null;
  let endMinutes = null;

  const endMatch = cleanTitle.match(
    /(?:\b(?:tot|until|bis)\s+|\s*[-–—]\s*)(\d{1,2}(?::\d{2})?\s*(?:am|pm|vm|nm)?)/i
  );
  if (endMatch) {
    ({ hours: endHours, minutes: endMinutes } = parseClock(endMatch[1]));
    cleanTitle = cleanTitle.replace(new RegExp(escapeRegExp(endMatch[0]), 'i'), '');
  }

  const lower = cleanTitle.toLowerCase();
  const noonMatch = lower.match(/\bnoon\b|(?:om\s+|at\s+)?(?:die\s+)?\bmiddag\b/);

  if (noonMatch) {
    ({ hours, minutes } = parseClock('12:00'));
    cleanTitle = cleanTitle.replace(/\bnoon\b|(?:om\s+|at\s+)?(?:die\s+)?\bmiddag\b/gi, '');
  } else {
    const timeMatch = lower.match(
      /(?:om|at)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm|vm|nm)?|\d{1,2}(?::\d{2})\s*(?:am|pm|vm|nm)?|\d{1,2}\s*(?:am|pm|vm|nm)/
    );
    if (timeMatch) {
      ({ hours, minutes } = parseClock(timeMatch[0]));
      cleanTitle = cleanTitle.replace(new RegExp(escapeRegExp(timeMatch[0]), 'i'), '');
    }
  }

  cleanTitle = cleanTitle
    .replace(/\s+/g, ' ')
    .replace(/^(om|at|die|tot|until|bis)\s+/i, '')
    .replace(/\s+(om|at|die|tot|until|bis)\s*$/i, '')
    .replace(/^[:;\s,.\-—!]+|[:;\s,.\-—!]+$/g, '')
    .trim();

  return { cleanTitle, hours, minutes, endHours, endMinutes };
};

const SOURCE_ICONS = {
  calendar_event: '📅',
  jobcard: '🔧',
  outlook: '☁️',
};

const SOURCE_LABELS = {
  calendar_event: 'Lokaal',
  jobcard: 'Werksopdrag',
  outlook: 'Outlook',
};

const DashboardPage = () => {
  const [activityItems, setActivityItems] = useState([]);
  const [summary, setSummary] = useState(null);
  const [opsDigest, setOpsDigest] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const { hasRight } = useCurrentUser();
  const { showToast } = useToast();
  const { confirm, dialog: confirmDialog } = useConfirmDialog();

  // ── Kalender toestand ──
  const { instance } = useMsal();
  const canManage = hasRight('calendar.manage');
  // Stabiele boolean (nie die `hasRight`-funksie nie) vir useEffect-deps — die
  // funksie-identiteit verander elke render en veroorsaak 'n herlaai-lus.
  const canViewCalendar = hasRight('calendar.view');
  const [events, setEvents] = useState([]);
  const [calendarError, setCalendarError] = useState(null);
  const [hasMsToken, setHasMsToken] = useState(false);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [viewMode, setViewMode] = useState('month');
  const [calendarLoading, setCalendarLoading] = useState(true);
  const [newEvent, setNewEvent] = useState({
    title: '',
    description: '',
    startDate: getDefaultEventTimes().startDate,
    startTime: getDefaultEventTimes().startTime,
    endDate: getDefaultEventTimes().endDate,
    endTime: getDefaultEventTimes().endTime,
    location: '',
    notify_email: false,
    reminder_minutes: 60,
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [deletingEventId, setDeletingEventId] = useState(null);
  const [syncingEventId, setSyncingEventId] = useState(null);
  const [quickTaskText, setQuickTaskText] = useState('');
  const [editingEvent, setEditingEvent] = useState(null);
  const [showEventModal, setShowEventModal] = useState(false);

  const formatActivityTime = (value) => {
    if (!value) return 'Onlangs';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return 'Onlangs';
    date.setHours(date.getHours() + 2);
    const day = String(date.getDate()).padStart(2, '0');
    const month = date.toLocaleString('af-ZA', { month: 'short' });
    const year = date.getFullYear();
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    return `${day} ${month} ${year} ${hours}:${minutes}:${seconds}`;
  };

  const buildActivityDescription = (entry) => {
    const action = String(entry?.action || '').toLowerCase();
    const table = String(entry?.affectedtable || '').toLowerCase();
    const payloadSources = [entry?.new_value, entry?.previous_value, entry?.json_data?.new_value, entry?.json_data?.previous_value].filter(Boolean);
    const getFirstValue = (keys) => {
      for (const source of payloadSources) {
        for (const key of keys) {
          if (source?.[key] != null && source[key] !== '') return source[key];
        }
      }
      return null;
    };
    const entityName = getFirstValue([
      'asset_name', 'room_name', 'stock_name', 'user_name', 'job_desc', 'fault_description', 'quote_id', 'location_name', 'report_name', 'name', 'title'
    ]);
    const actionLabel = action === 'delete' ? 'Verwyder' : action === 'update' ? 'Werk' : 'Skep';
    const labels = {
      asset: 'Bate', assettype: 'Bate-tipe', job: 'Werksopdrag', jobcard: 'Werksopdrag',
      fault: 'Foutkaartjie', faultcard: 'Foutkaartjie', room: 'Kamer', stock: 'Voorraaditem',
      user: 'Gebruiker', quote: 'Kwotasie', location: 'Ligging/Terrein', report: 'Verslag',
    };
    const label = labels[table] || table || 'Item';
    const nameText = entityName ? `: ${entityName}` : '';
    return `${actionLabel} ${label}${nameText}`;
  };

  const fetchData = useCallback(async () => {
    try {
      setLoading(true);
      // Let op: die AI-bedryfsopsomming (digest) word BEWUSTELIK buite die
      // Promise.all gehou — 'n koue Gemma kan 5-30s vat, en die kernpaneelbord
      // moet nie daarvoor wag nie. Die digest verskyn sodra dit gereed is.
      const [summaryRes, , auditResponse] = await Promise.all([
        Promise.resolve(apiClient.get('/analytics/dashboard-summary')).catch((e) => {
          console.warn('dashboard-summary failed, using fallback', e?.response?.status);
          return null;
        }),
        Promise.resolve(workOrdersAPI.getAll()).catch(() => ({ data: [] })),
        Promise.resolve(auditsAPI.getAll()).catch(() => ({ data: [] })),
        Promise.resolve(ticketsAPI.getAll()).catch(() => ({ data: [] })),
      ]);

      analyticsAPI.getInsights('dashboard')
        .then((r) => {
          const digest = r.data?.digest ?? null;
          if (digest) setOpsDigest(digest);
        })
        .catch(() => {});

      if (summaryRes?.data) {
        setSummary(summaryRes.data);
      } else {
        setSummary({
          kpis: { open_faults: 0, high_priority_faults: 0, high_priority_jobs: 0, auto_drafts: 0 },
          risk_distribution: { veilig: 0, monitor: 0, vervang: 0 },
          faults_per_building: [],
          trend: { labels: ['Geen data'], faults_per_week: [0], jobs_completed_per_week: [0] },
          top_risk_assets: [],
          critical_stock_list: [],
          scope: 'all',
        });
      }

      const auditEntries = Array.isArray(auditResponse?.data) ? auditResponse.data : [];

      const activities = auditEntries
        .map((entry) => {
          const table = String(entry?.affectedtable || '').toLowerCase();
          const formattedTime = formatActivityTime(entry?.actiondatetime);
          let link = '/dashboard';
          if (table.includes('job')) link = '/work-orders';
          else if (table.includes('fault')) link = '/fault-tickets';
          else if (table.includes('asset')) link = '/assets';
          else if (table.includes('room')) link = '/rooms';
          else if (table.includes('stock')) link = '/stock';
          else if (table.includes('user')) link = '/users';
          else if (table.includes('quote')) link = '/quotes';
          return {
            id: entry?.auditlog_id || `${table}-${entry?.action}-${formattedTime}`,
            time: formattedTime,
            description: buildActivityDescription(entry),
            link,
            type: table,
          };
        })
        .sort((a, b) => new Date(b.time) - new Date(a.time))
        .slice(0, 5);
      setActivityItems(activities);
    } catch (e) {
      console.error('Fout by laai van paneelbord-data:', e);
      setError(e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
    const interval = window.setInterval(fetchData, 3600000);
    const onFocus = () => fetchData();
    window.addEventListener('focus', onFocus);
    return () => {
      window.clearInterval(interval);
      window.removeEventListener('focus', onFocus);
    };
  }, [fetchData]);

  // ── Kalender hulppersone ──
  const applySelectedDateToForm = useCallback((date) => {
    const baseDate = new Date(date);
    setNewEvent((current) => ({
      ...current,
      startDate: formatDateInput(baseDate),
      endDate: formatDateInput(baseDate),
      startTime: '08:00',
      endTime: '09:00',
    }));
  }, []);

  const resetNewEvent = (date = selectedDate) => {
    const defaults = getDefaultEventTimes(date);
    setNewEvent({
      title: '',
      description: '',
      startDate: defaults.startDate,
      startTime: defaults.startTime,
      endDate: defaults.endDate,
      endTime: defaults.endTime,
      location: '',
      notify_email: false,
      reminder_minutes: 60,
    });
  };

  const handleQuickAddTask = async () => {
    const text = quickTaskText.trim();
    if (!text) {
      showToast({ type: 'warning', title: 'Tik die taak in die vinnige-byvoeg-balk.' });
      return;
    }

    const { cleanTitle, hours, minutes, endHours, endMinutes } = parseTimeFromText(text);
    if (!cleanTitle) {
      showToast({ type: 'warning', title: 'Vul asseblief ’n taak beskrywing in.' });
      return;
    }

    const start = new Date(selectedDate);
    start.setHours(hours, minutes, 0, 0);
    const end = new Date(start);
    if (endHours != null) {
      end.setHours(endHours, endMinutes ?? 0, 0, 0);
      if (end <= start) {
        end.setDate(end.getDate() + 1);
      }
    } else {
      end.setHours(end.getHours() + 1);
    }

    setIsSubmitting(true);
    try {
      const response = await calendarEventsAPI.create({
        title: cleanTitle,
        description: '',
        start_datetime: start.toISOString(),
        end_datetime: end.toISOString(),
        location: null,
        notify_email: false,
        reminder_minutes: null,
      });
      const created = response.data;
      setEvents((prev) => [...prev, {
        ...created,
        _start: new Date(created.start_datetime),
        _end: created.end_datetime ? new Date(created.end_datetime) : new Date(new Date(created.start_datetime).getTime() + 3600000),
        dateKey: formatDateKey(new Date(created.start_datetime)),
      }]);
      setQuickTaskText('');
      showToast({ type: 'success', title: 'Taak bygevoeg!' });
    } catch (err) {
      console.error('Vinnige byvoeg fout:', err);
      showToast({ type: 'error', title: 'Fout tydens byvoeg van taak.' });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleEditEvent = (event) => {
    const start = event._start || new Date(event.start_datetime);
    const end = event._end || new Date(new Date(event.start_datetime).getTime() + 3600000);
    setNewEvent({
      title: event.title || '',
      description: event.description || '',
      startDate: formatDateInput(start),
      startTime: formatTimeInput(start),
      endDate: formatDateInput(end),
      endTime: formatTimeInput(end),
      location: event.location || '',
      notify_email: !!event.notify_email,
      reminder_minutes: event.reminder_minutes || 60,
    });
    setEditingEvent(event);
    setShowEventModal(true);
  };

  const handleCancelEdit = () => {
    setEditingEvent(null);
    resetNewEvent();
    setShowEventModal(false);
  };

  const handleOpenCreateModal = () => {
    resetNewEvent();
    applySelectedDateToForm(selectedDate);
    setShowEventModal(true);
  };

  const getMicrosoftAccessToken = async () => {
    let msAccessToken = sessionStorage.getItem('ms_access_token');
    if (msAccessToken) return msAccessToken;

    const account = instance.getActiveAccount();
    if (!account) throw new Error('No active Microsoft account');

    const response = await instance.acquireTokenSilent({ ...loginRequest, account });
    msAccessToken = response.accessToken;
    sessionStorage.setItem('ms_access_token', msAccessToken);
    return msAccessToken;
  };

  const fetchLocalEvents = async (startISO, endISO) => {
    try {
      const response = await calendarEventsAPI.getRange(startISO, endISO);
      return response.data || [];
    } catch (err) {
      console.error("Lokale events laai fout:", err);
      return [];
    }
  };

  const fetchOutlookEvents = async (startISO, endISO) => {
    try {
      const msAccessToken = await getMicrosoftAccessToken();
      const response = await fetch(
        `https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=${encodeURIComponent(startISO)}&endDateTime=${encodeURIComponent(endISO)}&$top=100&$orderby=start/dateTime asc&$select=id,subject,bodyPreview,start,end,location,recurrence`,
        {
          headers: {
            Authorization: `Bearer ${msAccessToken}`,
            Prefer: 'outlook.timezone="South Africa Standard Time"'
          }
        }
      );
      if (!response.ok) throw new Error("Kon nie Outlook events ophaal nie");
      const data = await response.json();
      setHasMsToken(true);
      return (data.value || []).map((ev) => ({
        source: 'outlook',
        source_id: ev.id,
        title: ev.subject,
        description: ev.bodyPreview || '',
        start_datetime: ev.start?.dateTime || ev.start?.date,
        end_datetime: ev.end?.dateTime || ev.end?.date,
        all_day: !ev.start?.dateTime,
        location: ev.location?.displayName || '',
        color: '#0078D4',
        outlook_event_id: ev.id,
        _rawOutlook: ev,
      }));
    } catch (err) {
      console.error("Outlook events laai fout:", err);
      setHasMsToken(false);
      return [];
    }
  };

  useEffect(() => {
    if (!canViewCalendar) return;
    let mounted = true;
    (async () => {
      try {
        await authAPI.me();
        const range = getCalendarViewRange();
        const [localData] = await Promise.all([
          fetchLocalEvents(range.startDateTime, range.endDateTime),
        ]);

        if (!mounted) return;

        let merged = [...localData];

        try {
          const outlook = await fetchOutlookEvents(range.startDateTime, range.endDateTime);
          merged = [...merged, ...outlook];
        } catch (_) {}

        setEvents(merged);
        setCalendarLoading(false);
      } catch (err) {
        try { sessionStorage.clear(); localStorage.clear(); } catch(_) {}
        window.location.replace(window.location.origin + '/login');
      }
    })();
    return () => { mounted = false; };
  }, [selectedDate, viewMode, canViewCalendar]);

  const getCalendarViewRange = () => {
    const start = new Date(selectedDate);
    const end = new Date(selectedDate);

    if (viewMode === 'week') {
      const day = start.getDay();
      const diff = start.getDate() - day + (day === 0 ? -6 : 1);
      start.setDate(diff);
      start.setHours(0, 0, 0, 0);
      end.setDate(start.getDate() + 6);
      end.setHours(23, 59, 59, 999);
    } else {
      start.setDate(1);
      start.setHours(0, 0, 0, 0);
      end.setMonth(end.getMonth() + 1, 0);
      end.setHours(23, 59, 59, 999);
    }

    return {
      startDateTime: start.toISOString(),
      endDateTime: end.toISOString(),
    };
  };

  const calendarEvents = useMemo(() => {
    return events.map((event) => {
      const rawStart = event.start_datetime || event.start?.dateTime || event.start?.date;
      const rawEnd = event.end_datetime || event.end?.dateTime || event.end?.date;
      const start = rawStart ? new Date(rawStart) : new Date();
      const end = rawEnd ? new Date(rawEnd) : new Date(start.getTime() + 3600000);
      return {
        ...event,
        _start: start,
        _end: end,
        dateKey: formatDateKey(start),
      };
    });
  }, [events]);

  const selectedDayEvents = useMemo(() => {
    const targetKey = formatDateKey(selectedDate);
    return calendarEvents.filter((event) => event.dateKey === targetKey);
  }, [calendarEvents, selectedDate]);

  const calendarDays = useMemo(() => {
    if (viewMode === 'week') {
      const start = new Date(selectedDate);
      const day = start.getDay();
      const diff = start.getDate() - day + (day === 0 ? -6 : 1);
      const weekStart = new Date(start);
      weekStart.setDate(diff);
      return Array.from({ length: 7 }, (_, index) => {
        const dayDate = new Date(weekStart);
        dayDate.setDate(weekStart.getDate() + index);
        return dayDate;
      });
    }

    const year = selectedDate.getFullYear();
    const month = selectedDate.getMonth();
    const firstDay = new Date(year, month, 1);
    const startDay = new Date(firstDay);
    startDay.setDate(firstDay.getDate() - ((firstDay.getDay() + 6) % 7));
    const days = [];
    for (let i = 0; i < 42; i += 1) {
      const day = new Date(startDay);
      day.setDate(startDay.getDate() + i);
      days.push(day);
    }
    return days;
  }, [selectedDate, viewMode]);

  const syncEventToOutlook = async (eventId) => {
    let msAccessToken;
    try {
      msAccessToken = await getMicrosoftAccessToken();
    } catch {
      showToast({ type: 'warning', title: 'Meld asseblief eers aan met Microsoft om te sinkroniseer.' });
      return;
    }

    setSyncingEventId(eventId);
    try {
      const event = events.find((e) => e.source_id === eventId && e.source === 'calendar_event');
      if (!event) { showToast({ type: 'error', title: 'Event nie gevind nie' }); return; }

      const startDateTime = `${formatDateInput(new Date(event.start_datetime))}T${formatTimeInput(new Date(event.start_datetime))}`;
      const endMs = event.end_datetime ? new Date(event.end_datetime).getTime() : new Date(event.start_datetime).getTime() + 3600000;
      const endDateTime = `${formatDateInput(new Date(endMs))}T${formatTimeInput(new Date(endMs))}`;

      const graphPayload = {
        subject: event.title,
        body: { contentType: "HTML", content: event.description || '' },
        start: { dateTime: startDateTime, timeZone: "South Africa Standard Time" },
        end: { dateTime: endDateTime, timeZone: "South Africa Standard Time" },
        location: { displayName: event.location || '' },
      };

      const response = await fetch("https://graph.microsoft.com/v1.0/me/events", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${msAccessToken}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(graphPayload)
      });

      if (!response.ok) throw new Error("Kon nie na Outlook sinkroniseer nie");
      const outlookEvent = await response.json();

      await calendarEventsAPI.update(event.source_id, {
        outlook_event_id: outlookEvent.id,
        outlook_synced: true,
      });

      setEvents((prev) => prev.map((ev) =>
        ev.source_id === event.source_id && ev.source === 'calendar_event'
          ? { ...ev, outlook_synced: true, outlook_event_id: outlookEvent.id }
          : ev
      ));

      showToast({ type: 'success', title: 'Gesinkroniseer na Outlook!' });
    } catch (err) {
      console.error("Sync fout:", err);
      showToast({ type: 'error', title: 'Fout tydens sinkronisering na Outlook.' });
    } finally {
      setSyncingEventId(null);
    }
  };

  const handleDeleteEvent = async (eventId, source) => {
    if (source === 'outlook') {
      const confirmed = await confirm({ message: 'Verwyder hierdie Outlook afspraak? (Dit sal van Outlook verwyder word)', variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
      if (!confirmed) return;
      try {
        setDeletingEventId(eventId);
        const msAccessToken = await getMicrosoftAccessToken();
        await fetch(`https://graph.microsoft.com/v1.0/me/events/${eventId}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${msAccessToken}` },
        });
        setEvents((prev) => prev.filter((ev) => !(ev.source === 'outlook' && ev.source_id === eventId)));
        showToast({ type: 'success', title: 'Outlook afspraak verwyder.' });
      } catch (err) {
        console.error('Outlook DELETE Error:', err);
        showToast({ type: 'error', title: 'Fout tydens verwydering van Outlook afspraak.' });
      } finally {
        setDeletingEventId(null);
      }
    } else if (source === 'calendar_event') {
      const confirmed = await confirm({ message: 'Verwyder hierdie kalenderafspraak?', variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
      if (!confirmed) return;
      try {
        setDeletingEventId(eventId);
        await calendarEventsAPI.delete(eventId);
        setEvents((prev) => prev.filter((ev) => !(ev.source === 'calendar_event' && ev.source_id === eventId)));
        showToast({ type: 'success', title: 'Afspraak verwyder.' });
      } catch (err) {
        console.error('DELETE Error:', err);
        showToast({ type: 'error', title: 'Fout tydens verwydering.' });
      } finally {
        setDeletingEventId(null);
      }
    } else if (source === 'jobcard') {
      const confirmed = await confirm({ message: 'Verwyder slegs die skedulering van hierdie werksopdrag? (Die werksopdrag self bly behoue.)', variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
      if (!confirmed) return;
      try {
        setDeletingEventId(eventId);
        await workOrdersAPI.update(eventId, { job_scheduled_datetime: null, job_schedule_type: 'enkel', job_scheduled_end_datetime: null });
        setEvents((prev) => prev.filter((ev) => !(ev.source === 'jobcard' && ev.source_id === eventId)));
        showToast({ type: 'success', title: 'Skedulering van werksopdrag verwyder.' });
      } catch (err) {
        console.error('Verwyder skedulering Error:', err);
        showToast({ type: 'error', title: 'Fout tydens verwydering van skedulering.' });
      } finally {
        setDeletingEventId(null);
      }
    }
  };

  const handleCreateEvent = async (e) => {
    e.preventDefault();
    if (!newEvent.title || !newEvent.startDate || !newEvent.startTime) {
      showToast({ type: 'warning', title: 'Vul asseblief die verpligte velde in.' });
      return;
    }

    setIsSubmitting(true);
    try {
      const startDateTime = new Date(`${newEvent.startDate}T${newEvent.startTime}`);
      const endDateTime = newEvent.endDate && newEvent.endTime
        ? new Date(`${newEvent.endDate}T${newEvent.endTime}`)
        : new Date(startDateTime.getTime() + 3600000);

      const payload = {
        title: newEvent.title,
        description: newEvent.description,
        start_datetime: startDateTime.toISOString(),
        end_datetime: endDateTime.toISOString(),
        location: newEvent.location || null,
        notify_email: newEvent.notify_email,
        reminder_minutes: newEvent.notify_email ? newEvent.reminder_minutes : null,
      };

      if (editingEvent) {
        const response = await calendarEventsAPI.update(editingEvent.source_id, payload);
        const updated = response.data;
        setEvents((prev) => prev.map((ev) =>
          ev.source === 'calendar_event' && ev.source_id === updated.event_id
            ? {
                ...updated,
                _start: new Date(updated.start_datetime),
                _end: updated.end_datetime
                  ? new Date(updated.end_datetime)
                  : new Date(new Date(updated.start_datetime).getTime() + 3600000),
                dateKey: formatDateKey(new Date(updated.start_datetime)),
              }
            : ev
        ));
        showToast({ type: 'success', title: 'Wysigings gestoor!' });
      } else {
        const response = await calendarEventsAPI.create(payload);
        const created = response.data;
        setEvents((prev) => [...prev, {
          ...created,
          _start: new Date(created.start_datetime),
          _end: created.end_datetime ? new Date(created.end_datetime) : new Date(new Date(created.start_datetime).getTime() + 3600000),
          dateKey: formatDateKey(new Date(created.start_datetime)),
        }]);
        showToast({ type: 'success', title: 'Afspraak suksesvol geskep!' });
      }

      setEditingEvent(null);
      resetNewEvent();
      setShowEventModal(false);
    } catch (err) {
      console.error("HANDLE Error:", err);
      showToast({ type: 'error', title: editingEvent ? 'Fout tydens wysiging van afspraak.' : 'Fout tydens skep van afspraak.' });
    } finally {
      setIsSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="main"><div className="content"><p>Laai paneelbord...</p></div></div>
    );
  }

  const kpis = summary?.kpis || {};
  const isFkScoped = summary?.scope === 'fk';

  return (
    <div className="main">
      <div className="content">
        {isFkScoped && summary?.location_name && (
          <div style={{ background: '#fff7ed', border: '1px solid #e8d5c4', borderLeft: '4px solid #935e28', padding: '10px 14px', borderRadius: '8px', marginBottom: '16px', color: '#6b3f1d', fontSize: '13px' }}>
            Gefilter vir terrein: <strong>{summary.location_name}</strong> — jy sien slegs geboue/kamers/bates op jou kampus. Admin sien alles.
          </div>
        )}

        {/* ── RY 0: Kern-Oorsig — weeklikse kern-KPI's met skakels ── */}
        <h3 style={{ margin: '0 0 10px', color: '#935e28' }}>Kern-Oorsig</h3>
        <div className="stats-grid">
          <Link to="/fault-tickets?status=open" className="stat-card" style={{ borderLeft: '4px solid #b91c1c', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Oop Foutkaartjies</h4>
              <div className="stat-number" style={{ color: (kpis.open_faults || 0) > 0 ? '#b91c1c' : '#065f46' }}>{kpis.open_faults ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>Bekyk oop foutkaartjies →</div>
            </div>
          </Link>
          <Link to="/fault-tickets?priority=Hoog" className="stat-card" style={{ borderLeft: '4px solid #c97c3c', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Hoë-prioriteit Foute</h4>
              <div className="stat-number" style={{ color: (kpis.high_priority_faults || 0) > 0 ? '#c97c3c' : '#065f46' }}>{kpis.high_priority_faults ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>Bekyk hoë-prioriteit foute →</div>
            </div>
          </Link>
          <Link to="/work-orders?priority=Hoog" className="stat-card" style={{ borderLeft: '4px solid #3b82f6', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Hoë-prioriteit Werksopdragte</h4>
              <div className="stat-number" style={{ color: (kpis.high_priority_jobs || 0) > 0 ? '#3b82f6' : '#065f46' }}>{kpis.high_priority_jobs ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>Bekyk hoë-prioriteit werksopdragte →</div>
            </div>
          </Link>
          <Link to="/ai-drafts?source=auto" className="stat-card" style={{ borderLeft: '4px solid #7c3aed', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Gemma Auto-konsepte</h4>
              <div className="stat-number" style={{ color: (kpis.auto_drafts || 0) > 0 ? '#7c3aed' : '#065f46' }}>{kpis.auto_drafts ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>Bekyk outomatiese konsepte →</div>
            </div>
          </Link>
        </div>

        {opsDigest && (
          <div className="ops-digest" style={{ marginBottom: '20px', padding: '12px 16px', background: '#f5f0e6', borderRadius: '6px', borderLeft: '4px solid #935e28' }}>
            <h4 style={{ margin: '0 0 4px', color: '#935e28' }}>📋 Bedryfsopsomming</h4>
            <p style={{ margin: 0 }}>{opsDigest}</p>
          </div>
        )}

        {/* ── RY 3: Kalender (geskuif vanaf Kalender-blad) ── */}
        {hasRight('calendar.view') && (
          <>
            {calendarLoading ? (
              <div className="data-panel" style={{ marginBottom: '20px', textAlign: 'center', color: '#6b7280' }}>Laai kalender...</div>
            ) : (
              <div className="calendar-shell" style={{ marginBottom: '25px' }}>
                {calendarError && (
                  <div style={{ color: '#d9534f', padding: '10px', background: '#f9f2f2', borderRadius: '4px' }}>
                    {calendarError}
                  </div>
                )}
                <div className="calendar-toolbar">
                  <div>
                    <h4 style={{ margin: '0 0 6px' }}>Kalender</h4>
                    <p style={{ margin: 0, color: '#666' }}>
                      {SOURCE_ICONS.calendar_event} Lokaal &nbsp; {SOURCE_ICONS.jobcard} Werksopdrag &nbsp; {SOURCE_ICONS.outlook} Outlook
                    </p>
                  </div>
                  <div className="calendar-toolbar-actions">
                    <div className="calendar-view-toggle">
                      <button
                        type="button"
                        className={`calendar-view-btn ${viewMode === 'month' ? 'calendar-view-btn-active' : ''}`}
                        aria-pressed={viewMode === 'month'}
                        onClick={() => setViewMode('month')}
                      >
                        Maand
                      </button>
                      <button
                        type="button"
                        className={`calendar-view-btn ${viewMode === 'week' ? 'calendar-view-btn-active' : ''}`}
                        aria-pressed={viewMode === 'week'}
                        onClick={() => setViewMode('week')}
                      >
                        Week
                      </button>
                    </div>
                    <button
                      type="button"
                      className={`calendar-view-btn calendar-today-btn ${formatDateKey(selectedDate) === formatDateKey(new Date()) ? 'calendar-today-btn-active' : ''}`}
                      onClick={() => {
                        const today = new Date();
                        setSelectedDate(today);
                        applySelectedDateToForm(today);
                      }}
                    >
                      Vandag
                    </button>
                    {canManage && (
                      <button
                        type="button"
                        className="calendar-create-btn"
                        onClick={handleOpenCreateModal}
                      >
                        + Nuwe Afspraak
                      </button>
                    )}
                  </div>
                </div>

                <div className="calendar-main">
                  <div className="calendar-grid-card">
                    <div className="calendar-grid-header">
                      <button
                        type="button"
                        className="calendar-nav-btn"
                        onClick={() => {
                          const nextDate = new Date(selectedDate);
                          if (viewMode === 'month') {
                            nextDate.setMonth(nextDate.getMonth() - 1);
                          } else {
                            nextDate.setDate(nextDate.getDate() - 7);
                          }
                          setSelectedDate(nextDate);
                        }}
                      >
                        &lt;
                      </button>
                      <h5>
                        {viewMode === 'month'
                          ? selectedDate.toLocaleDateString('af-ZA', { month: 'long', year: 'numeric' })
                          : `${calendarDays[0].toLocaleDateString('af-ZA', { day: 'numeric', month: 'short' })} - ${calendarDays[calendarDays.length - 1].toLocaleDateString('af-ZA', { day: 'numeric', month: 'short' })}`}
                      </h5>
                      <button
                        type="button"
                        className="calendar-nav-btn"
                        onClick={() => {
                          const nextDate = new Date(selectedDate);
                          if (viewMode === 'month') {
                            nextDate.setMonth(nextDate.getMonth() + 1);
                          } else {
                            nextDate.setDate(nextDate.getDate() + 7);
                          }
                          setSelectedDate(nextDate);
                        }}
                      >
                        &gt;
                      </button>
                    </div>
                    {viewMode === 'month' ? (
                      <>
                        <div className="calendar-weekdays">
                          {['Ma','Di','Wo','Do','Vr','Sa','So'].map((day) => <div key={day}>{day}</div>)}
                        </div>
                        <div className="calendar-days-grid">
                          {calendarDays.map((day) => {
                            const isCurrentMonth = day.getMonth() === selectedDate.getMonth();
                            const isToday = formatDateKey(day) === formatDateKey(new Date());
                            const isSelected = formatDateKey(day) === formatDateKey(selectedDate);
                            const dayEvents = calendarEvents.filter((event) => event.dateKey === formatDateKey(day));
                            return (
                              <button
                                key={day.toISOString()}
                                type="button"
                                className={`calendar-day ${isCurrentMonth ? '' : 'calendar-day-muted'} ${isToday ? 'calendar-day-today' : ''} ${isSelected ? 'calendar-day-selected' : ''}`}
                                onClick={() => {
                                  setSelectedDate(day);
                                  applySelectedDateToForm(day);
                                }}
                              >
                                <span className="calendar-day-number">{day.getDate()}</span>
                                {dayEvents.slice(0, 2).map((event) => (
                                  <span key={`${event.source}-${event.source_id}`} className="calendar-event-pill">
                                    {SOURCE_ICONS[event.source] || '📌'} {event.title}
                                  </span>
                                ))}
                              </button>
                            );
                          })}
                        </div>
                      </>
                    ) : (
                      <div className="calendar-week-view">
                        {calendarDays.map((day) => {
                          const dayEvents = calendarEvents.filter((event) => event.dateKey === formatDateKey(day));
                          return (
                            <button
                              key={day.toISOString()}
                              type="button"
                              className={`calendar-week-day ${formatDateKey(day) === formatDateKey(selectedDate) ? 'calendar-day-selected' : ''}`}
                              onClick={() => {
                                setSelectedDate(day);
                                applySelectedDateToForm(day);
                              }}
                            >
                              <div className="calendar-week-day-name">{day.toLocaleDateString('af-ZA', { weekday: 'short' })}</div>
                              <div className="calendar-week-day-number">{day.getDate()}</div>
                              {dayEvents.slice(0, 2).map((event) => (
                                <span key={`${event.source}-${event.source_id}`} className="calendar-event-pill">
                                  {SOURCE_ICONS[event.source] || '📌'}
                                </span>
                              ))}
                            </button>
                          );
                        })}
                      </div>
                    )}
                  </div>

                  <div className="calendar-side-card">
                    <div className="calendar-side-header">
                      <h5>{selectedDate.toLocaleDateString('af-ZA', { weekday: 'long', day: 'numeric', month: 'long' })}</h5>
                      <span>{viewMode === 'month' ? 'Maand' : 'Week'}-beskou</span>
                    </div>
                    {selectedDayEvents.length === 0 ? (
                      <div className="calendar-empty-state">Geen afsprake vir hierdie dag nie.</div>
                    ) : (
                      <div className="calendar-event-list">
                        {selectedDayEvents.map((event) => (
                          <div key={`${event.source}-${event.source_id}`} className="calendar-event-card" style={{ borderLeft: `4px solid ${event.color || '#935E28'}` }}>
                            <div className="calendar-event-time">
                              {SOURCE_ICONS[event.source] || '📌'} {SOURCE_LABELS[event.source] || event.source}
                              &nbsp;—&nbsp;
                              {event._start.toLocaleTimeString('af-ZA', { hour: '2-digit', minute: '2-digit' })} - {event._end.toLocaleTimeString('af-ZA', { hour: '2-digit', minute: '2-digit' })}
                            </div>
                            <div className="calendar-event-title">{event.title}</div>
                            <div className="calendar-event-meta">{event.location || 'Geen plek'}</div>
                            <div className="calendar-event-body">{event.description || 'Geen beskrywing.'}</div>
                            <div style={{ display: 'flex', gap: '8px', marginTop: '8px', flexWrap: 'wrap' }}>
                              {event.source === 'calendar_event' && (
                                <button
                                  type="button"
                                  className="calendar-edit-btn"
                                  onClick={() => handleEditEvent(event)}
                                  title="Wysig"
                                  aria-label="Wysig"
                                >
                                  <IoPencil size={16} />
                                </button>
                              )}
                              <button
                                type="button"
                                className="calendar-delete-btn"
                                title="Verwyder"
                                aria-label="Verwyder"
                                onClick={() => handleDeleteEvent(event.source_id, event.source)}
                                disabled={deletingEventId === event.source_id}
                              >
                                <IoTrashOutline size={16} />
                              </button>
                              {event.source === 'calendar_event' && !event.outlook_synced && hasMsToken && (
                                <button
                                  type="button"
                                  className="btn-add"
                                  onClick={() => syncEventToOutlook(event.source_id)}
                                  disabled={syncingEventId === event.source_id}
                                  style={{ background: '#0078D4', fontSize: '12px', padding: '4px 10px' }}
                                >
                                  {syncingEventId === event.source_id ? 'Besig...' : 'Sinkroniseer na Outlook'}
                                </button>
                              )}
                              {event.source === 'calendar_event' && event.outlook_synced && (
                                <span style={{ fontSize: '11px', color: '#28a745', alignSelf: 'center' }}>✅ Gesinkroniseer</span>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                    {canManage && (
                      <div className="calendar-quick-add">
                        <input
                          type="text"
                          value={quickTaskText}
                          onChange={(e) => setQuickTaskText(e.target.value)}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                              e.preventDefault();
                              handleQuickAddTask();
                            }
                          }}
                          placeholder="Taak + tyd... bv. 'E-pos bestuurder om 18:00 tot 19:00'"
                          disabled={isSubmitting}
                          aria-label="Vinnige taak byvoeg"
                        />
                        <button
                          type="button"
                          className="calendar-quick-add-btn"
                          onClick={handleQuickAddTask}
                          disabled={isSubmitting || !quickTaskText.trim()}
                          title="Voeg taak by"
                        >
                          +
                        </button>
                      </div>
                    )}
                  </div>
                </div>

                {canManage && (
                  <Modal
                    isOpen={showEventModal}
                    onClose={handleCancelEdit}
                    title={editingEvent ? 'Wysig Kalenderafspraak' : 'Nuwe Kalenderafspraak'}
                    size="md"
                  >
                    <form onSubmit={handleCreateEvent} className="calendar-form-grid">
                      <div>
                        <label>Onderwerp *</label>
                        <input type="text" value={newEvent.title} onChange={(e) => setNewEvent({...newEvent, title: e.target.value})} placeholder="bv. Onderhoud op Lokaal 4" />
                      </div>
                      <div>
                        <label>Lokaal / Plek</label>
                        <input type="text" value={newEvent.location} onChange={(e) => setNewEvent({...newEvent, location: e.target.value})} placeholder="bv. Pretoria Kampus" />
                      </div>
                      <div>
                        <label>Begin Datum *</label>
                        <input type="date" value={newEvent.startDate} onChange={(e) => {
                          const next = { ...newEvent, startDate: e.target.value };
                          const start = new Date(`${e.target.value}T${newEvent.startTime}`);
                          const end = new Date(start);
                          end.setHours(end.getHours() + 1);
                          next.endDate = formatDateInput(end);
                          next.endTime = formatTimeInput(end);
                          setNewEvent(next);
                        }} />
                      </div>
                      <div>
                        <label>Begin Tyd *</label>
                        <input type="time" value={newEvent.startTime} onChange={(e) => {
                          const next = { ...newEvent, startTime: e.target.value };
                          const start = new Date(`${newEvent.startDate}T${e.target.value}`);
                          const end = new Date(start);
                          end.setHours(end.getHours() + 1);
                          next.endDate = formatDateInput(end);
                          next.endTime = formatTimeInput(end);
                          setNewEvent(next);
                        }} />
                      </div>
                      <div>
                        <label>Einde Datum</label>
                        <input type="date" value={newEvent.endDate} onChange={(e) => setNewEvent({ ...newEvent, endDate: e.target.value })} />
                      </div>
                      <div>
                        <label>Einde Tyd</label>
                        <input type="time" value={newEvent.endTime} onChange={(e) => setNewEvent({ ...newEvent, endTime: e.target.value })} />
                      </div>
                      <div style={{ gridColumn: 'span 2', display: 'flex', gap: '20px', alignItems: 'center' }}>
                        <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
                          <input
                            type="checkbox"
                            checked={newEvent.notify_email}
                            onChange={(e) => setNewEvent({...newEvent, notify_email: e.target.checked})}
                          />
                          Stuur e-pos herinnering
                        </label>
                        {newEvent.notify_email && (
                          <select
                            value={newEvent.reminder_minutes}
                            onChange={(e) => setNewEvent({...newEvent, reminder_minutes: Number(e.target.value)})}
                            style={{ padding: '6px', borderRadius: '4px', border: '1px solid #ccc' }}
                          >
                            <option value={30}>30 minute voor tyd</option>
                            <option value={60}>1 uur voor tyd</option>
                            <option value={120}>2 ure voor tyd</option>
                            <option value={1440}>24 ure voor tyd</option>
                          </select>
                        )}
                      </div>
                      <div className="calendar-form-full">
                        <label>Beskrywing</label>
                        <textarea value={newEvent.description} onChange={(e) => setNewEvent({...newEvent, description: e.target.value})} placeholder="Voeg ekstra besonderhede hier by..." />
                      </div>
                      <div className="calendar-form-full calendar-form-submit">
                        <button
                          type="button"
                          className="btn-delete"
                          onClick={handleCancelEdit}
                          disabled={isSubmitting}
                          style={{ marginTop: 0, marginRight: '10px' }}
                        >
                          Kanselleer
                        </button>
                        <button type="submit" className="btn-add" disabled={isSubmitting}>
                          {isSubmitting ? 'Besig om te stoor...' : editingEvent ? 'Stoor Wysigings' : 'Skep Afspraak'}
                        </button>
                      </div>
                    </form>
                  </Modal>
                )}
              </div>
            )}
          </>
        )}

        {/* ── RY 4: Aktiwiteit log ── */}
        <div className="data-panel">
          <h3>Aktiwiteit Log</h3>
          <div className="activity-list">
            {activityItems.length === 0 ? (
              <div className="activity-item">
                <div className="activity-time">-</div>
                <div className="activity-desc">Geen aktiwiteite om te vertoon nie.</div>
              </div>
            ) : (
              activityItems.map((item) => (
                <div className="activity-item" key={`${item.type}-${item.id}`}>
                  <div className="activity-time">{item.time}</div>
                  <div className="activity-desc">
                    <Link to={item.link} style={{ color: '#935e28', fontWeight: 600, display: 'block' }}>
                      {item.description}
                    </Link>
                    <div style={{ fontSize: '0.85rem', color: '#6b7280', marginTop: '0.2rem' }}>{item.type || 'audit'}</div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {error && (
          <div style={{ marginTop: '16px', background: '#fee2e2', color: '#b91c1c', padding: '10px 14px', borderRadius: '8px' }}>
            Kon paneelbord-data nie laai nie: {String(error?.message || error)}
          </div>
        )}
      </div>
      {confirmDialog}
    </div>
  );
};

export default DashboardPage;