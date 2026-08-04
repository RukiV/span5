import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useLocation } from 'react-router-dom';
import { Bar, Doughnut } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  ArcElement,
  Tooltip,
  Legend,
} from 'chart.js';
import { IoPaperPlane } from 'react-icons/io5';
import { analyticsAPI } from '../services/analyticsAPI';
import { useAnalytics } from '../context/AnalyticsContext';

ChartJS.register(CategoryScale, LinearScale, BarElement, ArcElement, Tooltip, Legend);

const PAGE_MAP = {
  '/dashboard': 'dashboard',
  '/assets': 'assets',
  '/stock': 'stock',
  '/rooms': 'rooms',
  '/buildings': 'buildings',
  '/terrains': 'terrains',
  '/fault-tickets': 'fault-tickets',
  '/work-orders': 'work-orders',
  '/users': 'users',
  '/calendar': 'calendar',
};

const defaultChartOpts = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { display: false } },
  scales: {
    x: { grid: { display: false }, ticks: { font: { size: 11 } } },
    y: { grid: { color: '#f1f5f9' }, ticks: { font: { size: 11 } }, beginAtZero: true },
  },
};

const COLORS = ['#935e28', '#b8863c', '#d4a357', '#e8c49a', '#f0dcc8'];

const RETRY_DELAY = 3000;

function SkeletonBlock({ lines = 3 }) {
  return (
    <div className="analytics-skeleton">
      {Array.from({ length: lines }).map((_, i) => (
        <div key={i} className="skeleton-line" style={{ width: `${70 + Math.random() * 30}%` }} />
      ))}
    </div>
  );
}

function AnalyticsPanel() {
  const location = useLocation();
  const { isOpen, close } = useAnalytics();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [retryCount, setRetryCount] = useState(0);
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [executingIds, setExecutingIds] = useState({});
  const [executeMsg, setExecuteMsg] = useState(null);
  const [chatHistory, setChatHistory] = useState([]);
  const [chatQuery, setChatQuery] = useState('');
  const [chatLoading, setChatLoading] = useState(false);
  const chatEndRef = useRef(null);

  const page = PAGE_MAP[location.pathname] || null;

  const fetchInsights = useCallback(async () => {
    if (!page) return;
    setLoading(true);
    setError(null);
    try {
      const res = await analyticsAPI.getInsights(page, dateFrom || undefined, dateTo || undefined);
      setData(res.data);
      setRetryCount(0);
    } catch (err) {
      setError('Kon nie insigte laai nie');
      if (retryCount < 2) {
        setTimeout(() => setRetryCount((c) => c + 1), RETRY_DELAY);
      }
    } finally {
      setLoading(false);
    }
  }, [page, dateFrom, dateTo, retryCount]);

  useEffect(() => {
    fetchInsights();
  }, [fetchInsights]);

  useEffect(() => {
    if (retryCount > 0 && retryCount <= 2) {
      fetchInsights();
    }
  }, [retryCount, fetchInsights]);

  const handleExecuteSuggestion = useCallback(async (suggestion, idx) => {
    setExecutingIds((prev) => ({ ...prev, [idx]: true }));
    setExecuteMsg(null);
    try {
      const res = await analyticsAPI.executeSuggestion(suggestion);
      setExecuteMsg({ type: 'success', text: res.data?.message || 'Aksie uitgevoer' });
      fetchInsights();
    } catch {
      setExecuteMsg({ type: 'error', text: 'Kon nie aksie uitvoer nie' });
    } finally {
      setExecutingIds((prev) => ({ ...prev, [idx]: false }));
    }
  }, [fetchInsights]);

  const handleChatSubmit = useCallback(async () => {
    const q = chatQuery.trim();
    if (!q || !page || chatLoading) return;
    setChatQuery('');
    setChatLoading(true);
    const userMsg = { role: 'user', content: q };
    const updatedHistory = [...chatHistory, userMsg];
    setChatHistory(updatedHistory);
    try {
      const res = await analyticsAPI.chat(page, q, chatHistory);
      setChatHistory((prev) => [...prev, { role: 'assistant', content: res.data.answer }]);
    } catch {
      setChatHistory((prev) => [...prev, { role: 'assistant', content: 'Kon nie antwoord kry nie.' }]);
    } finally {
      setChatLoading(false);
    }
  }, [chatQuery, page, chatLoading, chatHistory]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatHistory]);

  const chartData = data?.chart
    ? {
        labels: data.chart.labels,
        datasets: data.chart.datasets.map((ds, i) => ({
          label: ds.label,
          data: ds.data,
          backgroundColor: ds.backgroundColor?.length ? ds.backgroundColor : COLORS,
          borderRadius: 4,
        })),
      }
    : null;

  if (!isOpen) return null;

  return (
    <div className="analytics-inline-panel">
      <div className="analytics-header">
        <h3>✨ KI Analise</h3>
        <button className="analytics-close" onClick={close}>✕</button>
      </div>

      {!page && (
        <p className="analytics-empty">Kies 'n bladsy om insigte te sien.</p>
      )}

      {page && (
        <div className="analytics-date-filters">
          <label>
            Van:
            <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} />
          </label>
          <label>
            Tot:
            <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} />
          </label>
        </div>
      )}

      {loading && (
        <div className="analytics-loading">
          {retryCount > 0 ? (
            <>
              <div className="analytics-spinner" />
              <p>Probeer weer ({retryCount}/2)...</p>
            </>
          ) : (
            <SkeletonBlock lines={5} />
          )}
        </div>
      )}

      {error && !loading && (
        <div className="analytics-error-block">
          <p className="analytics-error">{error}</p>
          <button className="analytics-retry-btn" onClick={() => { setRetryCount(1); fetchInsights(); }}>
            🔄 Probeer weer
          </button>
        </div>
      )}

      {data && !loading && (
        <>
          <p className="analytics-summary">{data.summary}</p>

          {data.metrics?.length > 0 && (
            <div className="analytics-metrics">
              {data.metrics.map((m) => (
                <div className="metric-card" key={m.label}>
                  <span className="metric-value">{m.value}</span>
                  <span className="metric-label">{m.label}</span>
                </div>
              ))}
            </div>
          )}

          {data.suggestions?.length > 0 && (
            <div className="analytics-suggestions">
              <h4>Aksie Voorstelle</h4>
              {executeMsg && (
                <p className={`suggestion-msg ${executeMsg.type}`}>{executeMsg.text}</p>
              )}
              {data.suggestions.map((s, i) => (
                <div className="suggestion-card" key={i}>
                  <div className="suggestion-info">
                    <strong>{s.label}</strong>
                    <p>{s.description}</p>
                  </div>
                  <button
                    className="suggestion-btn"
                    onClick={() => handleExecuteSuggestion(s, i)}
                    disabled={executingIds[i]}
                  >
                    {executingIds[i] ? 'Besig...' : 'Uitvoer'}
                  </button>
                </div>
              ))}
            </div>
          )}

          {chartData && (
            <div className="analytics-chart">
              {data.chart.type === 'doughnut' ? (
                <Doughnut data={chartData} options={{ ...defaultChartOpts, scales: undefined }} />
              ) : (
                <Bar data={chartData} options={defaultChartOpts} />
              )}
            </div>
          )}

          {data.insights?.length > 0 && (
            <ul className="analytics-insights">
              {data.insights.map((insight, i) => (
                <li key={i}>🔍 {insight}</li>
              ))}
            </ul>
          )}

          <button className="analytics-refresh" onClick={() => { setRetryCount(0); fetchInsights(); }}>
            🔄 Verfris
          </button>

          <div className="chat-section">
            <div className="chat-messages">
              {chatHistory.length === 0 && (
                <p className="chat-empty">Vra 'n vraag oor die data</p>
              )}
              {chatHistory.map((msg, i) => (
                <div key={i} className={`chat-msg ${msg.role}`}>
                  <div className="chat-bubble">{msg.content}</div>
                </div>
              ))}
              {chatLoading && (
                <div className="chat-msg assistant">
                  <div className="chat-bubble chat-thinking">Dink...</div>
                </div>
              )}
              <div ref={chatEndRef} />
            </div>
            <div className="chat-input-row">
              <input
                type="text"
                className="chat-input"
                placeholder="Vra die KI..."
                value={chatQuery}
                onChange={(e) => setChatQuery(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') handleChatSubmit(); }}
              />
              <button className="chat-send-btn" onClick={handleChatSubmit} disabled={chatLoading || !chatQuery.trim()}>
                <IoPaperPlane />
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

export default AnalyticsPanel;