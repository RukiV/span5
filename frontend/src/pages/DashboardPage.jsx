import React, { useEffect, useState, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { Line, Bar, Doughnut } from 'react-chartjs-2';
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
import { auditsAPI, workOrdersAPI, ticketsAPI } from '../services/api';
import { apiClient } from '../services/api';
import { analyticsAPI } from '../services/analyticsAPI';
import { useCurrentUser } from '../hooks/useCurrentUser';
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, BarElement, Title, Tooltip, Legend, ArcElement);

const DashboardPage = () => {
  const [recentRepairs, setRecentRepairs] = useState([]);
  const [allJobs, setAllJobs] = useState([]);
  const [allFaults, setAllFaults] = useState([]);
  const [activityItems, setActivityItems] = useState([]);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [executing, setExecuting] = useState({});

  const { rights, hasRight } = useCurrentUser();
  const { showToast } = useToast();
  const { confirm, dialog: confirmDialog } = useConfirmDialog();
  const can = (r) => (rights || []).includes(r);

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
      const [summaryRes, workOrdersResponse, auditResponse, faultsResponse] = await Promise.all([
        Promise.resolve(apiClient.get('/analytics/dashboard-summary')).catch((e) => {
          console.warn('dashboard-summary failed, using fallback', e?.response?.status);
          return null;
        }),
        Promise.resolve(workOrdersAPI.getAll()).catch(() => ({ data: [] })),
        Promise.resolve(auditsAPI.getAll()).catch(() => ({ data: [] })),
        Promise.resolve(ticketsAPI.getAll()).catch(() => ({ data: [] })),
      ]);

      if (summaryRes?.data) {
        setSummary(summaryRes.data);
      } else {
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
      const faults = Array.isArray(faultsResponse?.data) ? faultsResponse.data : [];
      setAllJobs(orders);
      setAllFaults(faults);

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

  const handleExecute = useCallback(async (suggestion, key) => {
    // regte-kontrole: wys disabled tooltip in UI, maar guard ook hier
    const needsStock = suggestion.type === 'reorder_stock';
    const requiredRight = needsStock ? 'stock.manage' : 'jobs.manage';
    if (!can(requiredRight)) {
      showToast({ type: 'error', title: 'Geen reg', message: 'Geen reg — vra Admin' });
      return;
    }
    const ok = await confirm({
      title: 'Bevestig aksie',
      message: `${suggestion.label}${suggestion.description ? ' — ' + suggestion.description : ''}`,
      confirmLabel: 'Uitvoer',
      cancelLabel: 'Kanselleer',
      variant: 'info',
    });
    if (!ok) return;
    setExecuting((prev) => ({ ...prev, [key]: true }));
    try {
      const res = await analyticsAPI.executeSuggestion(suggestion);
      showToast({ type: 'success', title: res.data?.message || 'Aksie uitgevoer' });
      await fetchData();
    } catch (err) {
      const msg = err?.response?.data?.detail || err?.message || 'Kon nie aksie uitvoer nie';
      showToast({ type: 'error', title: 'Fout', message: String(msg) });
    } finally {
      setExecuting((prev) => ({ ...prev, [key]: false }));
    }
  }, [can, confirm, showToast, fetchData]);

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

  const aiCharts = summary?.ai_charts || {};
  const aiOrder = [
    'criticality_matrix',
    'sla_compliance',
    'failure_pareto',
    'health_status',
    'ticket_volume_backlog',
    'mttr_mtbf',
    'technician_load',
    'lifecycle_age',
    'strategy_mix',
  ];

  // Helpers vir direkte aksies gebaseer op lewendige data
  const overdueJobs = allJobs.filter((j) => {
    const s = String(j.job_status || '').toLowerCase();
    if (['voltooid','gekanselleer','completed','cancelled'].includes(s)) return false;
    if (!j.job_scheduled_end_datetime) return false;
    return new Date(j.job_scheduled_end_datetime) < new Date();
  });
  const firstOverdueJob = overdueJobs[0] || null;
  const highFaults = allFaults.filter((f) => {
    const pri = String(f.fault_priority || '').toLowerCase();
    const stat = String(f.fault_status || '').toLowerCase();
    return (pri === 'hoog' || pri === 'high' || pri === 'dringend') && ['oop','open','wag','wait','bevestig'].includes(stat);
  });
  const firstHighFault = highFaults[0] || null;
  const firstCriticalStock = criticalStockList[0] || null;
  const firstTopRisk = topRisk[0] || null;
  // vir AI actions
  const unassignedJob = allJobs.find((j) => !j.assigned_to && String(j.job_status||'').toLowerCase() !== 'voltooid') || null;

  const aiLinkMap = {
    criticality_matrix: '/predictions',
    sla_compliance: '/fault-tickets',
    failure_pareto: '/assets',
    health_status: '/assets',
    ticket_volume_backlog: '/fault-tickets',
    mttr_mtbf: '/work-orders',
    technician_load: '/work-orders',
    lifecycle_age: '/predictions',
    strategy_mix: '/work-orders',
  };

  return (
    <div className="main">
      <div className="content">
        {isFkScoped && summary?.location_name && (
          <div style={{ background: '#fff7ed', border: '1px solid #e8d5c4', borderLeft: '4px solid #935e28', padding: '10px 14px', borderRadius: '8px', marginBottom: '16px', color: '#6b3f1d', fontSize: '13px' }}>
            Gefilter vir terrein: <strong>{summary.location_name}</strong> — jy sien slegs geboue/kamers/bates op jou kampus. Admin sien alles.
          </div>
        )}

        {/* ── RY 0: Kritieke Aksie-KPI's — direkte Uitvoer knoppies waar relevant ── */}
        <div className="stats-grid">
          {/* Werksopdragte Oortyd — direkte ken toe */}
          <div className="stat-card" style={{ borderLeft: '5px solid #b91c1c', flexDirection: 'column', alignItems: 'stretch', textAlign: 'center' }}>
            <Link to="/work-orders" style={{ textDecoration: 'none', color: 'inherit', flex: 1 }}>
              <h4>Werksopdragte Oortyd</h4>
              <div className="stat-number" style={{ color: (kpis.overdue_jobs || 0) > 0 ? '#b91c1c' : '#065f46' }}>{kpis.overdue_jobs ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>{kpis.overdue_jobs > 0 ? 'Oor skedule' : 'Geen oortyd'}</div>
            </Link>
            {firstOverdueJob ? (
              <button
                className="dash-action-btn"
                disabled={executing['overdue_job'] || !can('jobs.manage')}
                title={!can('jobs.manage') ? 'Geen reg — vra Admin' : `Ken WR #${firstOverdueJob.jobcard_id} aan my toe`}
                onClick={() => handleExecute({ type: 'assign_job', label: `Ken werksopdrag #${firstOverdueJob.jobcard_id} aan my toe`, description: String(firstOverdueJob.job_desc||'').slice(0,80), params: { jobcard_id: firstOverdueJob.jobcard_id } }, 'overdue_job')}
              >
                {executing['overdue_job'] ? 'Besig...' : 'Ken aan my toe'}
              </button>
            ) : (
              <Link to="/work-orders" className="dash-link-btn">Bekyk werksopdragte →</Link>
            )}
          </div>

          {/* Hoë-prioriteit Foute >2d — direkte Skep WO */}
          <div className="stat-card" style={{ borderLeft: '5px solid #c97c3c', flexDirection: 'column', alignItems: 'stretch', textAlign: 'center' }}>
            <Link to="/fault-tickets?priority=Hoog" style={{ textDecoration: 'none', color: 'inherit', flex: 1 }}>
              <h4>Hoë-prioriteit Foute &gt;2d</h4>
              <div className="stat-number" style={{ color: (kpis.unassigned_high_faults || 0) > 0 ? '#c97c3c' : '#065f46' }}>{kpis.unassigned_high_faults ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>{kpis.unassigned_high_faults > 0 ? 'Wag vir toewysing' : 'Geen oop hoë-pri'}</div>
            </Link>
            {firstHighFault ? (
              <button
                className="dash-action-btn"
                disabled={executing['high_fault'] || !can('jobs.manage')}
                title={!can('jobs.manage') ? 'Geen reg — vra Admin' : `Skep WO vir fout #${firstHighFault.fault_id}`}
                onClick={() => handleExecute({ type: 'create_work_order', label: `Werksopdrag vir fout #${firstHighFault.fault_id}`, description: String(firstHighFault.fault_description||'').slice(0,80), params: { fault_id: firstHighFault.fault_id, job_desc: String(firstHighFault.fault_description||''), room_id: firstHighFault.room_id, building_id: firstHighFault.building_id, location_id: firstHighFault.location_id, job_priority: 'Dringend' } }, 'high_fault')}
              >
                {executing['high_fault'] ? 'Besig...' : 'Skep werksopdrag'}
              </button>
            ) : (
              <Link to="/fault-tickets?priority=Hoog" className="dash-link-btn">Bekyk foute →</Link>
            )}
          </div>

          {/* Onderhoud Agterstallig — direkte Skep WO */}
          <div className="stat-card" style={{ borderLeft: '5px solid #b91c1c', flexDirection: 'column', alignItems: 'stretch', textAlign: 'center' }}>
            <Link to="/predictions" style={{ textDecoration: 'none', color: 'inherit', flex: 1 }}>
              <h4>Onderhoud Agterstallig</h4>
              <div className="stat-number" style={{ color: (kpis.overdue_maintenance || 0) > 0 ? '#b91c1c' : '#065f46' }}>{kpis.overdue_maintenance ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>{kpis.overdue_maintenance > 0 ? 'Benodig skedulering' : 'Geen agterstallig'}</div>
            </Link>
            {(kpis.overdue_maintenance || 0) > 0 && firstTopRisk ? (
              <button
                className="dash-action-btn"
                disabled={executing['overdue_maint'] || !can('jobs.manage')}
                title={!can('jobs.manage') ? 'Geen reg — vra Admin' : `Skeduleer onderhoud vir ${firstTopRisk.asset_name}`}
                onClick={() => handleExecute({ type: 'create_work_order', label: `Werksopdrag vir ${firstTopRisk.asset_name}`, description: `Onderhoud agterstallig: ${firstTopRisk.asset_name}`, params: { asset_id: firstTopRisk.asset_id, job_desc: `Onderhoud: ${firstTopRisk.asset_name}`, job_priority: 'Hoog' } }, 'overdue_maint')}
              >
                {executing['overdue_maint'] ? 'Besig...' : 'Skeduleer onderhoud'}
              </button>
            ) : (
              <Link to="/predictions" className="dash-link-btn">Bekyk voorspellings →</Link>
            )}
          </div>

          {/* Kritieke Voorraad — direkte Hervul */}
          <div className="stat-card" style={{ borderLeft: '5px solid #f59e0b', flexDirection: 'column', alignItems: 'stretch', textAlign: 'center' }}>
            <Link to="/stock" style={{ textDecoration: 'none', color: 'inherit', flex: 1 }}>
              <h4>Kritieke Voorraad</h4>
              <div className="stat-number" style={{ color: (kpis.critical_stock || 0) > 0 ? '#b91c1c' : '#065f46' }}>{kpis.critical_stock ?? 0}</div>
              <div className="stat-change" style={{ color: '#6b7280' }}>{kpis.critical_stock > 0 ? 'Onder minimum' : 'Voorraad OK'}</div>
            </Link>
            {firstCriticalStock ? (
              <button
                className="dash-action-btn"
                disabled={executing['critical_stock'] || !can('stock.manage')}
                title={!can('stock.manage') ? 'Geen reg — vra Admin' : `Hervul ${firstCriticalStock.stock_name}`}
                onClick={() => handleExecute({ type: 'reorder_stock', label: `Hervul ${firstCriticalStock.stock_name}`, description: `${firstCriticalStock.stock_name} is krities laag (${firstCriticalStock.amount}/${firstCriticalStock.minimum})`, params: { stock_id: firstCriticalStock.stock_id, name: firstCriticalStock.stock_name, amount: (firstCriticalStock.minimum || 10) * 2 } }, 'critical_stock')}
              >
                {executing['critical_stock'] ? 'Besig...' : `Hervul: ${firstCriticalStock.stock_name}`}
              </button>
            ) : (
              <Link to="/stock" className="dash-link-btn">Bestuur voorraad →</Link>
            )}
          </div>
        </div>

        {/* ── RY 1: Sekondêre risiko-KPI's — net skakels (aksie irrelevant) ── */}
        <div className="stats-grid" style={{ marginBottom: '20px' }}>
          <Link to="/predictions" className="stat-card" style={{ borderLeft: '4px solid #b91c1c', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>ML Hoë Risiko (&gt;50% 12md)</h4>
              <div className="stat-number" style={{ color: (kpis.high_risk || 0) > 0 ? '#b91c1c' : '#065f46' }}>{kpis.high_risk ?? 0}</div>
              <div className="stat-change" style={{ color: '#935e28', fontWeight: 600 }}>Bekyk besonderhede →</div>
            </div>
          </Link>
          <Link to="/predictions" className="stat-card" style={{ borderLeft: '4px solid #935e28', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Vervanging Voorgestel</h4>
              <div className="stat-number">{kpis.replacement_suggested ?? 0}</div>
              <div className="stat-change" style={{ color: '#935e28', fontWeight: 600 }}>Bekyk voorspellings →</div>
            </div>
          </Link>
          <Link to="/work-orders" className="stat-card" style={{ borderLeft: '4px solid #3b82f6', textDecoration: 'none', color: 'inherit' }}>
            <div style={{ flex: 1 }}>
              <h4>Hangende vs Voltooi</h4>
              <div className="stat-number" style={{ fontSize: '1.4rem' }}>{kpis.pending_jobs ?? 0} / {kpis.completed_jobs ?? 0}</div>
              <div className="stat-change" style={{ color: '#935e28', fontWeight: 600 }}>Bekyk werksopdragte →</div>
            </div>
          </Link>
        </div>

        {/* ── RY 2: Top risiko tabel — knoppie per ry (direkte Skep WO) ── */}
        <div className="data-panel" style={{ marginBottom: '20px' }}>
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
                  <th>Aksie</th>
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
                    <td style={{ fontSize: '13px', color: '#4b5563', maxWidth: '260px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={p.reason}>
                      {p.reason || (p.replacement_suggested ? 'Vervanging voorgestel' : '-')}
                    </td>
                    <td>
                      <button
                        className="dash-action-btn dash-action-btn--small"
                        disabled={!!executing[`toprisk-${p.asset_id}`] || !can('jobs.manage')}
                        title={!can('jobs.manage') ? 'Geen reg — vra Admin' : `Skep werksopdrag vir ${p.asset_name}`}
                        onClick={() => handleExecute({ type: 'create_work_order', label: `Werksopdrag vir ${p.asset_name}`, description: p.reason || 'Vervanging voorgestel', params: { asset_id: p.asset_id, job_desc: `Vervanging: ${p.asset_name} — ${p.reason || ''}`.slice(0,200), job_priority: 'Hoog' } }, `toprisk-${p.asset_id}`)}
                      >
                        {executing[`toprisk-${p.asset_id}`] ? 'Besig...' : 'Skep WO'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* ── RY 3: Hoof-grafieke — Risiko + Voorraad eerste (net skakels, aksie irrelevant behalwe voorraad wat bo reeds het) ── */}
        <div className="charts-container">
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
            {firstCriticalStock && (
              <div style={{ textAlign: 'center', marginTop: '10px' }}>
                <button
                  className="dash-action-btn"
                  disabled={executing['stock-chart'] || !can('stock.manage')}
                  title={!can('stock.manage') ? 'Geen reg — vra Admin' : `Hervul ${firstCriticalStock.stock_name}`}
                  onClick={() => handleExecute({ type: 'reorder_stock', label: `Hervul ${firstCriticalStock.stock_name}`, description: `${firstCriticalStock.stock_name} (${firstCriticalStock.amount}/${firstCriticalStock.minimum})`, params: { stock_id: firstCriticalStock.stock_id, amount: (firstCriticalStock.minimum||10)*2 } }, 'stock-chart')}
                >
                  {executing['stock-chart'] ? 'Besig...' : `Hervul ${firstCriticalStock.stock_name}`}
                </button>
              </div>
            )}
          </div>
        </div>

        {/* ── RY 4: Tendens + Foute per Gebou — net skakels (aksie irrelevant) ── */}
        <div className="charts-container" style={{ marginTop: '20px' }}>
          <div className="data-panel">
            <div className="panel-header">
              <h3>Tendens 8 Weke — Foute vs Herstel</h3>
              <Link to="/work-orders" className="view-all">Bekyk agterstand →</Link>
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
        </div>

        {/* ── RY 5: AI 9 Visuals — beide Bekyk + Uitvoer waar relevant, anders net Bekyk ── */}
        {Object.keys(aiCharts).length > 0 && (
          <>
            <div style={{ marginTop: '24px', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '10px' }}>
              <h2 style={{ margin: 0, color: '#0e1e3b', fontSize: '18px' }}>AI Asset & Werkopdrag Analise</h2>
              <span style={{ background: '#d4edda', color: '#155724', padding: '3px 8px', borderRadius: '12px', fontSize: '11px', fontWeight: 700 }}>AI gegenereer • elke run vars</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: '20px' }}>
              {aiOrder.filter((k) => aiCharts[k]).map((key) => {
                const chart = aiCharts[key];
                const labels = chart.labels || [];
                const datasets = (chart.datasets || []).map((ds, i) => ({
                  label: ds.label,
                  data: ds.data,
                  backgroundColor: chart.type === 'doughnut'
                    ? ['#935e28', '#b8863c', '#d4a357', '#e8c49a', '#f0dcc8', '#10b981', '#f59e0b', '#ef4444'].slice(0, (ds.data||[]).length)
                    : ds.backgroundColor || ['#935e28', '#b8863c', '#d4a357', '#10b981', '#f59e0b', '#ef4444'][i % 6],
                  borderColor: chart.type === 'line' ? '#935e28' : undefined,
                  borderWidth: chart.type === 'line' ? 2 : 0,
                  fill: chart.type === 'line' ? false : true,
                  tension: 0.3,
                }));
                const data = { labels, datasets };
                const opts = {
                  responsive: true,
                  maintainAspectRatio: false,
                  plugins: {
                    legend: { position: chart.type === 'doughnut' ? 'bottom' : 'bottom' },
                    title: { display: false },
                  },
                  scales: chart.type === 'doughnut' ? {} : { y: { beginAtZero: true, ticks: { precision: 0 } }, x: { ticks: { maxRotation: 45 } } },
                };
                const cards = chart.cards;
                // Besluit of hierdie AI kaart 'n direkte aksie het
                const hasDirectAction = ['criticality_matrix','sla_compliance','failure_pareto','technician_load'].includes(key);
                const aiSuggestion = (() => {
                  if (key === 'criticality_matrix' && firstTopRisk) return { type: 'create_work_order', label: `Werksopdrag vir ${firstTopRisk.asset_name} (Hoog/ Hoog)`, description: firstTopRisk.reason || 'Kritieke risiko/impak', params: { asset_id: firstTopRisk.asset_id, job_desc: `Kritiek: ${firstTopRisk.asset_name}`, job_priority: 'Dringend' } };
                  if (key === 'sla_compliance' && firstHighFault) return { type: 'create_work_order', label: `Werksopdrag vir SLA-oortreding fout #${firstHighFault.fault_id}`, description: String(firstHighFault.fault_description||'').slice(0,80), params: { fault_id: firstHighFault.fault_id, job_desc: String(firstHighFault.fault_description||''), room_id: firstHighFault.room_id, job_priority: 'Dringend' } };
                  if (key === 'failure_pareto' && firstTopRisk) return { type: 'create_work_order', label: `Werksopdrag vir pareto-bate ${firstTopRisk.asset_name}`, description: 'Top faling klas', params: { asset_id: firstTopRisk.asset_id, job_desc: `Pareto opvolg: ${firstTopRisk.asset_name}`, job_priority: 'Hoog' } };
                  if (key === 'technician_load' && unassignedJob) return { type: 'assign_job', label: `Ken werksopdrag #${unassignedJob.jobcard_id} aan my toe`, description: String(unassignedJob.job_desc||'').slice(0,80), params: { jobcard_id: unassignedJob.jobcard_id } };
                  return null;
                })();
                const viewLink = aiLinkMap[key] || '/dashboard';
                return (
                  <div key={key} className="data-panel">
                    <div className="panel-header">
                      <h3 style={{ fontSize: '14px' }}>{chart.title || key}</h3>
                      <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                        <Link to={viewLink} className="view-all">Bekyk →</Link>
                        {hasDirectAction && aiSuggestion && (
                          <button
                            className="dash-action-btn dash-action-btn--small"
                            disabled={!!executing[`ai-${key}`] || (aiSuggestion.type==='reorder_stock' ? !can('stock.manage') : !can('jobs.manage'))}
                            title={(aiSuggestion.type==='reorder_stock' ? !can('stock.manage') : !can('jobs.manage')) ? 'Geen reg — vra Admin' : aiSuggestion.label}
                            onClick={() => handleExecute(aiSuggestion, `ai-${key}`)}
                          >
                            {executing[`ai-${key}`] ? 'Besig...' : 'Uitvoer'}
                          </button>
                        )}
                        {hasDirectAction && !aiSuggestion && (
                          <button className="dash-action-btn dash-action-btn--small" disabled title="Geen aksie benodig tans" style={{ opacity: 0.45 }}>Uitvoer</button>
                        )}
                      </div>
                    </div>
                    {cards && (
                      <div style={{ display: 'flex', gap: '10px', marginBottom: '8px' }}>
                        <div style={{ flex: 1, background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px', padding: '8px', textAlign: 'center' }}>
                          <div style={{ fontSize: '11px', color: '#065f46' }}>MTTR</div>
                          <div style={{ fontSize: '18px', fontWeight: 800, color: '#065f46' }}>{cards.mttr}h</div>
                        </div>
                        <div style={{ flex: 1, background: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '8px', padding: '8px', textAlign: 'center' }}>
                          <div style={{ fontSize: '11px', color: '#1e40af' }}>MTBF</div>
                          <div style={{ fontSize: '18px', fontWeight: 800, color: '#1e40af' }}>{cards.mtbf_days}d</div>
                        </div>
                      </div>
                    )}
                    <div className="chart-container" style={{ height: '260px' }}>
                      {chart.type === 'line' ? <Line data={data} options={opts} /> : chart.type === 'doughnut' ? <Doughnut data={data} options={opts} /> : <Bar data={data} options={opts} />}
                    </div>
                    {chart.insights && chart.insights.length > 0 && (
                      <div style={{ fontSize: '12px', color: '#6b7280', marginTop: '8px' }}>
                        {chart.insights.slice(0, 2).map((ins, idx) => <div key={idx}>• {ins}</div>)}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </>
        )}

        {/* ── RY 6: Onlangse werk + aktiwiteit — skakels bygevoeg waar aksie irrelevant ── */}
        <div className="dashboard-grid">
          <div className="data-panel">
            <div className="panel-header">
              <h3>Onlangse Herstelwerk</h3>
              <Link to="/work-orders" className="view-all">Bekyk alle →</Link>
            </div>
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
                      <td>
                        {order.asset_id ? <Link to={`/assets?search=${encodeURIComponent(order.asset_id)}`} style={{ color: '#935e28', fontWeight: 600 }}>{order.asset_id}</Link> : '-'}
                      </td>
                      <td><Link to={`/work-orders?search=${encodeURIComponent(order.job_desc || order.brief_description || '')}`} style={{ color: '#0e1e3b' }}>{order.job_desc || order.brief_description || 'Geen beskrywing'}</Link></td>
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
      {confirmDialog}
    </div>
  );
};

export default DashboardPage;
