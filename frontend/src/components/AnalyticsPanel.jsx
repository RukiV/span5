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
import { IoStatsChartOutline, IoBulbOutline, IoRocketOutline, IoCalendarOutline, IoRefreshOutline } from 'react-icons/io5';
import '../styles/AnalyticsPanel.css';
import { analyticsAPI } from '../services/analyticsAPI';
import { invalidateOpsDigestCache } from '../services/opsDigestCache';
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
  '/predictions': 'predictions',
};

// Resolve the analytics page key for a pathname: exact match first,
// then prefix match for the /ai-drafts detail/new routes.
const resolvePageKey = (pathname) => {
  if (PAGE_MAP[pathname]) return PAGE_MAP[pathname];
  if (pathname === '/ai-drafts' || pathname.startsWith('/ai-drafts/')) return 'ai-drafts';
  return null;
};

const defaultChartOpts = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { display: false } },
  scales: {
    x: { grid: { display: false }, ticks: { font: { size: 11, family: "'Segoe UI', Arial, sans-serif" } } },
    y: { grid: { color: '#f0e6d8' }, ticks: { font: { size: 11, family: "'Segoe UI', Arial, sans-serif" } }, beginAtZero: true },
  },
};

const COLORS = ['#935e28', '#b8863c', '#d4a357', '#e8c49a', '#f0dcc8'];

function SkeletonBlock({ lines = 3 }) {
  return (
    <div className="ap-skeleton">
      {Array.from({ length: lines }).map((_, i) => (
        <div key={i} className="ap-skeleton-line" style={{ width: `${70 + Math.random() * 30}%` }} />
      ))}
    </div>
  );
}

function SectionHeader({ icon: Icon, title }) {
  return (
    <div className="ap-section-header">
      {Icon && <Icon className="ap-section-icon" />}
      <span>{title}</span>
    </div>
  );
}

function AnalyticsPanel() {
  const location = useLocation();
  const { isOpen, close } = useAnalytics();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [executingIds, setExecutingIds] = useState({});
  const [executeMsg, setExecuteMsg] = useState(null);
  const abortControllerRef = useRef(null);

  const page = resolvePageKey(location.pathname);

  const fetchInsights = useCallback(async (signal) => {
    if (!page) return;
    setLoading(true);
    setError(null);
    try {
      const res = await analyticsAPI.getInsights(page, dateFrom || undefined, dateTo || undefined, signal);
      if (signal?.aborted) return;
      setData(res.data);
    } catch (err) {
      if (err.name === 'AbortError' || signal?.aborted) return;
      setError('Kon nie insigte laai nie.');
    } finally {
      setLoading(false);
    }
  }, [page, dateFrom, dateTo]);

  useEffect(() => {
    const controller = new AbortController();
    abortControllerRef.current?.abort();
    abortControllerRef.current = controller;
    fetchInsights(controller.signal);
    return () => {
      controller.abort();
    };
  }, [fetchInsights]);

  const handleExecuteSuggestion = useCallback(async (suggestion, idx) => {
    setExecutingIds((prev) => ({ ...prev, [idx]: true }));
    setExecuteMsg(null);
    try {
      const res = await analyticsAPI.executeSuggestion(suggestion);
      setExecuteMsg({ type: 'success', text: res.data?.message || 'Aksie uitgevoer' });
      invalidateOpsDigestCache();
      fetchInsights();
    } catch {
      setExecuteMsg({ type: 'error', text: 'Kon nie aksie uitvoer nie' });
    } finally {
      setExecutingIds((prev) => ({ ...prev, [idx]: false }));
    }
  }, [fetchInsights]);

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
      <div className="ap-header">
        <div className="ap-header-left">
          <IoStatsChartOutline className="ap-header-icon" />
          <h3>Analitiese Paneel</h3>
        </div>
        <button className="ap-close" onClick={close} title="Maak toe">✕</button>
      </div>

      <div className="ap-body">
        {!page && (
          <div className="ap-empty">
            <IoRocketOutline className="ap-empty-icon" />
            <p>Kies 'n bladsy om insigte te sien</p>
          </div>
        )}

        {page && (
          <div className="ap-date-card">
            <div className="ap-date-icon"><IoCalendarOutline /></div>
            <div className="ap-date-fields">
              <label>
                <span>Van</span>
                <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} />
              </label>
              <label>
                <span>Tot</span>
                <input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} />
              </label>
            </div>
          </div>
        )}

        {loading && (
          <div className="ap-loading">
            <SkeletonBlock lines={5} />
          </div>
        )}

        {error && !loading && (
          <div className="ap-error-block">
            <p className="ap-error">{error}</p>
            <button className="ap-btn" onClick={fetchInsights}>
              Probeer weer
            </button>
          </div>
        )}

        {data && !loading && (
          <>
            {data.summary && (
              <div className="ap-summary">
                <p>{data.summary}</p>
              </div>
            )}

            {data.metrics?.length > 0 && (
              <div className="ap-section">
                <SectionHeader icon={IoStatsChartOutline} title="Sleutelmetrieke" />
                <div className="ap-metrics-grid">
                  {data.metrics.map((m) => (
                    <div className="ap-metric-card" key={m.label}>
                      <span className="ap-metric-value">{m.value}</span>
                      <span className="ap-metric-label">{m.label}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {chartData && (
              <div className="ap-section">
                <SectionHeader icon={IoStatsChartOutline} title="Visuele Ontleding" />
                <div className="ap-chart-container">
                  {data.chart.type === 'doughnut' ? (
                    <Doughnut data={chartData} options={{ ...defaultChartOpts, scales: undefined }} />
                  ) : (
                    <Bar data={chartData} options={defaultChartOpts} />
                  )}
                </div>
              </div>
            )}

            {data.insights?.length > 0 && (
              <div className="ap-section">
                <SectionHeader icon={IoBulbOutline} title="Insigte" />
                <ul className="ap-insights">
                  {data.insights.map((insight, i) => (
                    <li key={i}>{insight}</li>
                  ))}
                </ul>
              </div>
            )}

            {data.suggestions?.length > 0 && (
              <div className="ap-section">
                <SectionHeader icon={IoRocketOutline} title="Aanbevole Aksies" />
                {executeMsg && (
                  <p className={`ap-msg ap-msg--${executeMsg.type}`}>{executeMsg.text}</p>
                )}
                <div className="ap-suggestions">
                  {data.suggestions.map((s, i) => (
                    <div className="ap-suggestion-card" key={i}>
                      <div className="ap-suggestion-body">
                        <strong>{s.label}</strong>
                        <p>{s.description}</p>
                      </div>
                      <button
                        className="ap-suggestion-btn"
                        onClick={() => handleExecuteSuggestion(s, i)}
                        disabled={executingIds[i]}
                      >
                        {executingIds[i] ? 'Besig...' : 'Uitvoer'}
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="ap-actions">
              <button className="ap-btn ap-btn--outline" onClick={fetchInsights}>
                <IoRefreshOutline /> Verfris
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export default AnalyticsPanel;
