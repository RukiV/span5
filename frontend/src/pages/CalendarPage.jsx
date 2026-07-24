import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useMsal } from '@azure/msal-react';
import { authAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import '../styles/Calendar.css';
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import { loginRequest } from '../services/msalConfig';

function CalendarPage() {
  const { isAdmin, user } = useCurrentUser();
  const logout = useLogout();
  const { instance } = useMsal();
  const [loading, setLoading] = useState(true);
  const [events, setEvents] = useState([]);
  const [calendarError, setCalendarError] = useState(null);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [viewMode, setViewMode] = useState('month');

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

  const applySelectedDateToForm = (date) => {
    const baseDate = new Date(date);
    setNewEvent((current) => ({
      ...current,
      startDate: formatDateInput(baseDate),
      endDate: formatDateInput(baseDate)
    }));
  };

  const getMicrosoftAccessToken = async () => {
    let msAccessToken = sessionStorage.getItem('ms_access_token');

    if (msAccessToken) {
      return msAccessToken;
    }

    const account = instance.getActiveAccount();
    if (!account) {
      throw new Error('No active Microsoft account');
    }

    const response = await instance.acquireTokenSilent({ ...loginRequest, account });
    msAccessToken = response.accessToken;
    sessionStorage.setItem('ms_access_token', msAccessToken);
    return msAccessToken;
  };
  
  // State vir nuwe kalender-inskrywing
  const [newEvent, setNewEvent] = useState({
    subject: '',
    description: '',
    startDate: getDefaultEventTimes().startDate,
    startTime: getDefaultEventTimes().startTime,
    endDate: getDefaultEventTimes().endDate,
    endTime: getDefaultEventTimes().endTime,
    location: ''
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [deletingEventId, setDeletingEventId] = useState(null);

  // 1. Valideer sessie en laai Microsoft Kalender-data op mount
  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await authAPI.me();
        if (mounted) {
          setLoading(false);
          fetchMicrosoftCalendarEvents();
        }
      } catch (err) {
        try { sessionStorage.clear(); localStorage.clear(); } catch(_) {}
        window.location.replace(window.location.origin + '/login');
      }
    })();
    return () => { mounted = false; };
  }, [selectedDate, viewMode]);

  const formatDateKey = (date) => {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  const calendarEvents = useMemo(() => {
    return events.map((event) => {
      const start = event.start?.dateTime ? new Date(event.start.dateTime) : new Date(event.start?.date || Date.now());
      const end = event.end?.dateTime ? new Date(event.end.dateTime) : new Date(event.end?.date || Date.now());
      return {
        ...event,
        start,
        end,
        dateKey: formatDateKey(start)
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

  // 2. Haal bestaande kalenderitems van Microsoft af (Read)
  const fetchMicrosoftCalendarEvents = async () => {
    let msAccessToken;

    try {
      msAccessToken = await getMicrosoftAccessToken();
    } catch (tokenError) {
      console.error("Microsoft token reacquisition failed:", tokenError);
      setCalendarError("Geen Microsoft-rekening gekoppel nie. Meld asseblief eers aan met Microsoft.");
      return;
    }

    try {
      const { startDateTime, endDateTime } = getCalendarViewRange();
      const response = await fetch(
        `https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=${encodeURIComponent(startDateTime)}&endDateTime=${encodeURIComponent(endDateTime)}&$top=100&$orderby=start/dateTime asc&$select=id,subject,bodyPreview,start,end,location,recurrence`,
        {
          headers: {
            Authorization: `Bearer ${msAccessToken}`,
            Prefer: 'outlook.timezone="South Africa Standard Time"'
          }
        }
      );

      if (!response.ok) throw new Error("Kon nie kalenderdata ophaal nie.");

      const data = await response.json();
      setEvents(data.value || []);
      setCalendarError(null);
    } catch (err) {
      console.error("Microsoft Graph GET Error:", err);
      setCalendarError("Fout met die laai van Microsoft Kalender items.");
    }
  };

  // 3. Stuur 'n nuwe kalenderitem na Microsoft (Write)
  const handleDeleteEvent = async (eventId) => {
    if (!eventId) return;

    const confirmed = window.confirm('Verwyder hierdie kalenderafspraak?');
    if (!confirmed) return;

    try {
      setDeletingEventId(eventId);
      const msAccessToken = await getMicrosoftAccessToken();

      const response = await fetch(`https://graph.microsoft.com/v1.0/me/events/${eventId}`, {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${msAccessToken}`,
        },
      });

      if (!response.ok) {
        throw new Error('Kon die afspraak nie verwyder nie.');
      }

      await fetchMicrosoftCalendarEvents();
      alert('Afspraak suksesvol verwyder.');
    } catch (err) {
      console.error('Microsoft Graph DELETE Error:', err);
      alert('Fout tydens die verwydering van die afspraak.');
    } finally {
      setDeletingEventId(null);
    }
  };

  const handleCreateEvent = async (e) => {
    e.preventDefault();

    if (!newEvent.subject || !newEvent.startDate || !newEvent.startTime || !newEvent.endDate || !newEvent.endTime) {
      alert("Vul asseblief al die verpligte velde in.");
      return;
    }

    let msAccessToken;

    try {
      msAccessToken = await getMicrosoftAccessToken();
    } catch (tokenError) {
      console.error("Microsoft token reacquisition failed:", tokenError);
      alert("Kon nie 'n Microsoft-toegangstoken kry nie. Meld asseblief weer aan.");
      return;
    }

    setIsSubmitting(true);

    // Die korrekte JSON-struktuur wat Microsoft Graph verwag
    const startDateTime = `${newEvent.startDate}T${newEvent.startTime}`;
    const endDateTime = `${newEvent.endDate}T${newEvent.endTime}`;

    const graphEventPayload = {
      subject: newEvent.subject,
      body: {
        contentType: "HTML",
        content: newEvent.description
      },
      start: {
        dateTime: startDateTime,
        timeZone: "South Africa Standard Time"
      },
      end: {
        dateTime: endDateTime,
        timeZone: "South Africa Standard Time"
      },
      location: {
        displayName: newEvent.location
      }
    };

    try {
      const response = await fetch("https://graph.microsoft.com/v1.0/me/events", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${msAccessToken}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(graphEventPayload)
      });

      if (!response.ok) {
        throw new Error("Kon nie die nuwe item op Microsoft skep nie.");
      }

      alert("Afspraak suksesvol by jou Outlook-kalender gevoeg!");
      
      const defaults = getDefaultEventTimes(selectedDate);
      // Maak die vorm skoon en herlaai die nuwe kalenderlys
      setNewEvent({
        subject: '',
        description: '',
        startDate: defaults.startDate,
        startTime: defaults.startTime,
        endDate: defaults.endDate,
        endTime: defaults.endTime,
        location: ''
      });
      await fetchMicrosoftCalendarEvents();
    } catch (err) {
      console.error("Microsoft Graph POST Error:", err);
      alert("Fout tydens die skep van die afspraak.");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div style={{ display: "flex" }}>
        <div className="main"><div className="content">Laai...</div></div>
      </div>
    );
  }

  return (
    <div>
      {/* LINKERBAAD - Navigasie-menu */}
      <Sidebar currentPath="/calendar" isAdmin={isAdmin} onLogout={logout} />

      {/* HOOFINHOUD */}
      <div className="main">
        <div className="navbar">
          <h3>Microsoft Kalender ({user?.role_id === 3 ? "Admin" : "Personeel"})</h3>
          <div className="user-profile-box" style={{ textAlign: 'right', fontSize: '14px', lineHeight: '1.3' }}>
            {user ? (
              <>
                <div className="user-name" style={{ fontWeight: 'bold' }}>{user.user_name} {user.user_surname}</div>
                <div className="user-role" style={{ fontSize: '12px', color: '#935e28', fontWeight: '600' }}>
                  {user.role_id === 3 ? "Administrateur" : user.role_id === 2 ? "Personeel" : "Student"}
                </div>
                <div className="user-email" style={{ fontSize: '11px', color: '#666' }}>{user.user_email}</div>
              </>
            ) : (
              <div className="user-loading" style={{ color: '#999' }}>Laai profiel...</div>
            )}
          </div>
        </div>

        <div className="content" style={{ display: 'flex', flexDirection: 'column', gap: '30px' }}>
          {calendarError && (
            <div style={{ color: '#d9534f', padding: '10px', background: '#f9f2f2', borderRadius: '4px' }}>
              {calendarError}
            </div>
          )}

          {!calendarError && (
            <div className="calendar-shell">
              <div className="calendar-toolbar">
                <div>
                  <h4 style={{ margin: '0 0 6px' }}>Outlook-kalender</h4>
                  <p style={{ margin: 0, color: '#666' }}>Jou Microsoft Outlook-afsprake in 'n werklike kalender-uitsig.</p>
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
                                <span key={event.id} className="calendar-event-pill">{event.subject}</span>
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
                              <span key={event.id} className="calendar-event-pill">{event.subject}</span>
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
                    <span>{viewMode === 'month' ? 'Kies ' : 'Week'}-beskou</span>
                  </div>
                  {selectedDayEvents.length === 0 ? (
                    <div className="calendar-empty-state">Geen afsprake vir hierdie dag nie.</div>
                  ) : (
                    <div className="calendar-event-list">
                      {selectedDayEvents.map((event) => (
                        <div key={event.id} className="calendar-event-card">
                          <div className="calendar-event-time">{event.start.toLocaleTimeString('af-ZA', { hour: '2-digit', minute: '2-digit' })} - {event.end.toLocaleTimeString('af-ZA', { hour: '2-digit', minute: '2-digit' })}</div>
                          <div className="calendar-event-title">{event.subject}</div>
                          <div className="calendar-event-meta">{event.location?.displayName || 'Geen plek'}</div>
                          <div className="calendar-event-body">{event.bodyPreview || 'Geen beskrywing.'}</div>
                          <button
                            type="button"
                            className="btn-delete"
                            onClick={() => handleDeleteEvent(event.id)}
                            disabled={deletingEventId === event.id}
                          >
                            {deletingEventId === event.id ? 'Besig...' : 'Verwyder'}
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>

              <div className="calendar-form-card">
                <h4>+ Nuwe Kalenderafspraak Skep</h4>
                <form onSubmit={handleCreateEvent} className="calendar-form-grid">
                  <div>
                    <label>Onderwerp *</label>
                    <input type="text" value={newEvent.subject} onChange={(e) => setNewEvent({...newEvent, subject: e.target.value})} placeholder="bv. Onderhoud op Lokaal 4" />
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
                    <label>Einde Datum *</label>
                    <input type="date" value={newEvent.endDate} onChange={(e) => setNewEvent({ ...newEvent, endDate: e.target.value })} />
                  </div>
                  <div>
                    <label>Einde Tyd *</label>
                    <input type="time" value={newEvent.endTime} onChange={(e) => setNewEvent({ ...newEvent, endTime: e.target.value })} />
                  </div>
                  <div className="calendar-form-full">
                    <label>Beskrywing</label>
                    <textarea value={newEvent.description} onChange={(e) => setNewEvent({...newEvent, description: e.target.value})} placeholder="Voeg ekstra besonderhede hier by..." />
                  </div>
                  <div className="calendar-form-full calendar-form-submit">
                    <button type="submit" className="btn-add" disabled={isSubmitting}>{isSubmitting ? 'Besig om te stoor...' : 'Sinkroniseer na Outlook'}</button>
                  </div>
                </form>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default CalendarPage;