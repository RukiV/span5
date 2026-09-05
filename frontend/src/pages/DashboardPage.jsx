import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Line, Bar } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
} from 'chart.js';
import '../styles/App.css';
import '../styles/Dashboard.css';
import { auditsAPI, workOrdersAPI } from '../services/api';
import { apiClient } from '../services/api';
ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, BarElement, Title, Tooltip, Legend, ArcElement);

const DashboardPage = () => {
  const [recentRepairs, setRecentRepairs] = useState([]);
  const [activityItems, setActivityItems] = useState([]);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

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

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const [summaryRes, workOrdersResponse, auditResponse] = await Promise.all([
          Promise.resolve(apiClient.get('/analytics/dashboard-summary')).catch((e) => {
            console.warn('dashboard-summary failed, using fallback', e?.response?.status);
            return null;
          }),
          Promise.resolve(workOrdersAPI.getAll()).catch(() => ({ data: [] })),
          Promise.resolve(auditsAPI.getAll()).catch(() => ({ data: [] })),
        ]);

        if (summaryRes?.data) {
          setSummary(summaryRes.data);
        } else {
          // Fallback: minimal empty structure so UI still renders
          setSummary({
            kpis: { overdue_maintenance: 0, unassigned_high_faults: 0, overdue_jobs: 0, critical_stock: 0, replacement_suggested: 0, high_risk: 0 },
            risk_distribution: { veilig: 0, monitor: 0, vervang: 0 },
            faults_per_building: [],
            trend: { labels: ['Geen data'], faults_per_week: [0], jobs_completed_per_week: [0] },
            top_risk_assets: [],
            critical_stock_list: [],
            scope: 'all',
          });
        }

        const orders = Array.isArray(workOrdersResponse?.data) ? workOrdersResponse.data : [];
        const auditEntries = Array.isArray(auditResponse?.data) ? auditResponse.data : [];

        const repairOrders = orders
          .filter((order) => order?.job_type && String(order.job_type).toLowerCase() !== 'inspection')
          .sort((a, b) => new Date(b?.job_createddatetime || 0) - new Date(a?.job_createddatetime || 0))
          .slice(0, 3);
        setRecentRepairs(repairOrders);

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
    };

    fetchData();
    const interval = window.setInterval(fetchData, 30000);
    const onFocus = () => fetchData();
    window.addEventListener('focus', onFocus);
    return () => {
      window.clearInterval(interval);
      window.removeEventListener('focus', onFocus);
    };
  }, []);

  if (loading) {
    return (
      <div className="main"><div className="content"><p>Laai paneelbord...</p></div></div>
    );
  }

  const kpis = summary?.kpis || {};
  const risk = summary?.risk_distribution || { veilig: 0, monitor: 0, vervang: 0 };
  const faultsPerBuilding = summary?.faults_per_building || [];
  const trend = summary?.trend || { labels: [], faults_per_week: [], jobs_completed_per_week: [] };
  const topRisk = summary?.top_risk_assets || [];
  const criticalStockList = summary?.critical_stock_list || [];
  const isFkScoped = summary?.scope === 'fk';

  const faultsPerBuildingData = {
    labels: faultsPerBuilding.length ? faultsPerBuilding.map((x) => x.building) : ['Geen foute 30d'],
    datasets: [
      {
        label: 'Foute 30 dae',
        data: faultsPerBuilding.length ? faultsPerBuilding.map((x) => x.count) : [0],
        backgroundColor: '#c97c3c',
        borderColor: '#935e28',
        borderWidth: 1,
      },
    ],
  };

  const riskData = {
    labels: ['Veilig', 'Monitor', 'Vervang'],
    datasets: [
      {
        label: 'Bates',
        data: [risk.veilig || 0, risk.monitor || 0, risk.vervang || 0],
        backgroundColor: ['#10b981', '#f59e0b', '#ef4444'],
        borderWidth: 0,
      },
    ],
  };

  const trendData = {
    labels: trend.labels || [],
    datasets: [
      {
        label: 'Foute geskep',
        data: trend.faults_per_week || [],
        borderColor: '#b91c1c',
        backgroundColor: 'rgba(185,28,28,0.08)',
        fill: false,
        tension: 0.3,
      },
      {
        label: 'Werksopdragte voltooi',
        data: trend.jobs_completed_per_week || [],
        borderColor: '#10b981',
        backgroundColor: 'rgba(16,185,129,0.12)',
        fill: true,
        tension: 0.3,
      },
    ],
  };

  const stockData = {
    labels: criticalStockList.length ? criticalStockList.map((s) => s.stock_name) : ['Geen kritieke voorraad'],
    datasets: [
      {
        label: 'Hoeveelheid',
        data: criticalStockList.length ? criticalStockList.map((s) => s.amount) : [0],
        backgroundColor: criticalStockList.length ? criticalStockList.map((s) => (s.amount < s.minimum ? '#ef4444' : '#d4a357')) : ['#94a3b8'],
        borderWidth: 0,
      },
      {
        label: 'Minimum',
        data: criticalStockList.length ? criticalStockList.map((s) => s.minimum) : [0],
        backgroundColor: 'rgba(148,163,184,0.35)',
        borderColor: '#64748b',
        borderWidth: 1,
        type: 'bar',
      },
    ],
  };

  const hasData = (arr) => arr && arr.some((v) => v > 0);

  return (
    <div className="main">
      <div className="content">
        {isFkScoped && summary?.location_name && (
          <div style={{ background: '#fff7ed', border: '1px solid #e8d5c4', borderLeft: '4px solid #935e28', padding: '10px 14px', borderRadius: '8px', marginBottom: '16px', color: '#6b3f1d', fontSize: '13px' }}>
            Gefilter vir terrein: <strong>{summary.location_name}</strong> — jy sien slegs geboue/kamers/bates op jou kampus. Admin sien alles.
          </div>
        )}

        {/* ── Aksie-KPI's ── */}
        <div className="stats-grid">
          <Link to="/predictions" className="stat-card" style={{ borderLeft: '5px solid #b91c1c', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Onderhoud Agterstallig</h4>
              <div className="stat-number" style={{ color: (kpis.overdue_maintenance || 0) > 0 ? '#b91c1c' : '#065f46' }}>{kpis.overdue_maintenance ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>{kpis.overdue_maintenance > 0 ? 'Benodig skedulering' : 'Geen agterstallig'}</div>
            </div>
          </Link>
          <Link to="/fault-tickets?priority=Hoog" className="stat-card" style={{ borderLeft: '5px solid #c97c3c', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Hoë-prioriteit Foute &gt;2d</h4>
              <div className="stat-number" style={{ color: (kpis.unassigned_high_faults || 0) > 0 ? '#c97c3c' : '#065f46' }}>{kpis.unassigned_high_faults ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>{kpis.unassigned_high_faults > 0 ? 'Wag vir toewysing' : 'Geen oop hoë-pri'}</div>
            </div>
          </Link>
          <Link to="/work-orders" className="stat-card" style={{ borderLeft: '5px solid #b91c1c', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Werksopdragte Oortyd</h4>
              <div className="stat-number" style={{ color: (kpis.overdue_jobs || 0) > 0 ? '#b91c1c' : '#065f46' }}>{kpis.overdue_jobs ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>{kpis.overdue_jobs > 0 ? 'Oor skedule' : 'Geen oortyd'}</div>
            </div>
          </Link>
          <Link to="/stock" className="stat-card" style={{ borderLeft: '5px solid #f59e0b', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Kritieke Voorraad</h4>
              <div className="stat-number" style={{ color: (kpis.critical_stock || 0) > 0 ? '#b91c1c' : '#065f46' }}>{kpis.critical_stock ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>{kpis.critical_stock > 0 ? 'Onder minimum' : 'Voorraad OK'}</div>
            </div>
          </Link>
        </div>

        {/* ── Sekondêre KPI (vervanging / risiko) ── */}
        <div className="stats-grid" style={{ marginBottom: '20px' }}>
          <div className="stat-card" style={{ borderLeft: '4px solid #935e28' }}>
            <div style={{ flex: 1 }}>
              <h4>Vervanging Voorgestel</h4>
              <div className="stat-number">{kpis.replacement_suggested ?? 0}</div>
              <Link to="/predictions" className="stat-change" style={{ color: '#935e28', fontWeight: 600 }}>Bekyk voorspellings →</Link>
            </div>
          </div>
          <div className="stat-card" style={{ borderLeft: '4px solid #b91c1c' }}>
            <div style={{ flex: 1 }}>
              <h4>ML Hoë Risiko (&gt;50% 12md)</h4>
              <div className="stat-number" style={{ color: (kpis.high_risk || 0) > 0 ? '#b91c1c' : '#065f46' }}>{kpis.high_risk ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>{kpis.high_risk > 0 ? 'Faalkans binne jaar' : 'Geen hoë ML-risiko'}</div>
            </div>
          </div>
          <div className="stat-card" style={{ borderLeft: '4px solid #3b82f6' }}>
            <div style={{ flex: 1 }}>
              <h4>Hangende vs Voltooi</h4>
              <div className="stat-number" style={{ fontSize: '1.4rem' }}>{kpis.pending_jobs ?? 0} / {kpis.completed_jobs ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>Hangende / Voltooi (totaal)</div>
            </div>
          </div>
        </div>

        {/* ── Charts ry 1 ── */}
        <div className="charts-container">
          <div className="data-panel">
            <div className="panel-header">
              <h3>Foute per Gebou (30 dae)</h3>
              <Link to="/fault-tickets" className="view-all">Bekyk foute →</Link>
            </div>
            <div className="chart-container" style={{ height: '260px' }}>
              <Bar
                data={faultsPerBuildingData}
                options={{
                  responsive: true,
                  maintainAspectRatio: false,
                  plugins: { legend: { display: false } },
                  scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                }}
              />
            </div>
            {!hasData(faultsPerBuildingData.datasets[0].data) && (
              <div style={{ textAlign: 'center', color: '#94a3b8', fontSize: '13px', marginTop: '6px' }}>Geen foute laaste 30 dae — stabiele terrein.</div>
            )}
          </div>
          <div className="data-panel">
            <div className="panel-header">
              <h3>Bate Risiko-verdeling</h3>
              <Link to="/predictions" className="view-all">Bekyk besonderhede →</Link>
            </div>
            <div className="chart-container" style={{ height: '260px' }}>
              <Bar
                data={riskData}
                options={{
                  responsive: true,
                  maintainAspectRatio: false,
                  indexAxis: 'y',
                  plugins: { legend: { display: false } },
                  scales: { x: { beginAtZero: true, ticks: { precision: 0 } } },
                }}
              />
            </div>
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center', marginTop: '8px', fontSize: '12px', color: '#6b7280' }}>
              <span><span style={{ display: 'inline-block', width: '10px', height: '10px', background: '#10b981', borderRadius: '2px', marginRight: '4px' }}></span>Veilig &lt;80%</span>
              <span><span style={{ display: 'inline-block', width: '10px', height: '10px', background: '#f59e0b', borderRadius: '2px', marginRight: '4px' }}></span>Monitor 80-99%</span>
              <span><span style={{ display: 'inline-block', width: '10px', height: '10px', background: '#ef4444', borderRadius: '2px', marginRight: '4px' }}></span>Vervang ≥100%/ML</span>
            </div>
          </div>
        </div>

        {/* ── Charts ry 2 ── */}
        <div className="charts-container" style={{ marginTop: '20px' }}>
          <div className="data-panel">
            <div className="panel-header">
              <h3>Tendens 8 Weke — Foute vs Herstel</h3>
            </div>
            <div className="chart-container" style={{ height: '260px' }}>
              <Line
                data={trendData}
                options={{
                  responsive: true,
                  maintainAspectRatio: false,
                  plugins: { legend: { position: 'bottom' } },
                  scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                }}
              />
            </div>
            <div style={{ color: '#6b7280', fontSize: '12px', textAlign: 'center', marginTop: '6px' }}>
              Gap groei = agterstand neem toe. Geskep vs voltooi per week.
            </div>
          </div>
          <div className="data-panel">
            <div className="panel-header">
              <h3>Kritieke Voorraad — Hoeveelheid vs Minimum</h3>
              <Link to="/stock" className="view-all">Bestuur voorraad →</Link>
            </div>
            <div className="chart-container" style={{ height: '260px' }}>
              <Bar
                data={stockData}
                options={{
                  responsive: true,
                  maintainAspectRatio: false,
                  plugins: { legend: { position: 'bottom' } },
                  scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                }}
              />
            </div>
            {criticalStockList.length === 0 && (
              <div style={{ textAlign: 'center', color: '#10b981', fontSize: '13px', marginTop: '6px' }}>Geen kritieke items — voorraad OK.</div>
            )}
          </div>
        </div>

        {/* ── Top risiko tabel ── */}
        <div className="data-panel" style={{ marginTop: '20px' }}>
          <div className="panel-header">
            <h3>Top 5 Vervangings-kandidate (aksie benodig)</h3>
            <Link to="/predictions" className="view-all">Alle voorspellings →</Link>
          </div>
          {topRisk.length === 0 ? (
            <p style={{ color: '#6b7280', padding: '12px 0' }}>Geen hoë-risiko bates — alle bates binne lewensduur en ML lae risiko.</p>
          ) : (
            <table className="standard-table">
              <thead>
                <tr>
                  <th>Bate</th>
                  <th>Gebou</th>
                  <th>Lewensduur</th>
                  <th>ML Faalkans 12m</th>
                  <th>Rede</th>
                </tr>
              </thead>
              <tbody>
                {topRisk.map((p) => (
                  <tr key={p.asset_id}>
                    <td>
                      <Link to={`/assets?search=${encodeURIComponent(p.asset_serial || p.asset_name)}`} style={{ color: '#935e28', fontWeight: 600 }}>
                        {p.asset_name}
                      </Link>
                      <div style={{ fontSize: '12px', color: '#6b7280' }}>{p.asset_serial}</div>
                    </td>
                    <td>{p.building || '-'}</td>
                    <td>
                      {p.lifespan_pct_used != null ? (
                        <span style={{ padding: '3px 8px', borderRadius: '12px', fontSize: '12px', fontWeight: 700, background: p.lifespan_pct_used >= 100 ? '#fee2e2' : p.lifespan_pct_used >= 80 ? '#fef3c7' : '#dcfce7', color: p.lifespan_pct_used >= 100 ? '#b91c1c' : p.lifespan_pct_used >= 80 ? '#9a5a00' : '#065f46' }}>
                          {p.lifespan_pct_used}%
                        </span>
                      ) : (
                        '-'
                      )}
                    </td>
                    <td>
                      {p.failure_prob != null ? (
                        <span style={{ color: p.failure_prob >= 0.5 ? '#b91c1c' : '#6b7280', fontWeight: p.failure_prob >= 0.5 ? 700 : 400 }}>
                          {(p.failure_prob * 100).toFixed(0)}%
                        </span>
                      ) : (
                        '-'
                      )}
                    </td>
                    <td style={{ fontSize: '13px', color: '#4b5563', maxWidth: '320px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={p.reason}>
                      {p.reason || (p.replacement_suggested ? 'Vervanging voorgestel' : '-')}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* ── Onlangse werk + aktiwiteit ── */}
        <div className="dashboard-grid">
          <div className="data-panel">
            <h3>Onlangse Herstelwerk</h3>
            <table className="standard-table">
              <thead>
                <tr>
                  <th>Bate</th>
                  <th>Beskrywing</th>
                  <th>Status</th>
                  <th>Datum</th>
                </tr>
              </thead>
              <tbody>
                {recentRepairs.length === 0 ? (
                  <tr>
                    <td colSpan="4">Geen onlangse herstelwerk beskikbaar nie.</td>
                  </tr>
                ) : (
                  recentRepairs.map((order) => (
                    <tr key={order.jobcard_id || order.job_id || order.id}>
                      <td>{order.asset_id || '-'}</td>
                      <td>{order.job_desc || order.brief_description || 'Geen beskrywing'}</td>
                      <td>
                        <span className={`status ${order.job_status === 'Voltooid' ? 'completed' : order.job_status === 'Besig' ? 'in-progress' : 'pending'}`}>
                          {order.job_status || 'Onbekend'}
                        </span>
                      </td>
                      <td>{order.job_createddatetime ? new Date(order.job_createddatetime).toLocaleDateString('af-ZA') : '-'}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

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
        </div>

        {error && (
          <div style={{ marginTop: '16px', background: '#fee2e2', color: '#b91c1c', padding: '10px 14px', borderRadius: '8px' }}>
            Kon paneelbord-data nie laai nie: {String(error?.message || error)}
          </div>
        )}
      </div>
    </div>
  );
};

export default DashboardPage;
