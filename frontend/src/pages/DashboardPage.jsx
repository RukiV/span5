<<<<<<< HEAD
import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Line, Doughnut } from 'react-chartjs-2';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, ArcElement } from 'chart.js';
import '../styles/App.css';
import '../styles/Dashboard.css';
import { auditsAPI, workOrdersAPI, assetsAPI, ticketsAPI } from '../services/api';
import { apiClient } from '../services/api';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, ArcElement);

const mapAssetStatusLabel = (status) => {
  switch (status?.toLowerCase()) {
    case 'active':
      return 'In Gebruik';
    case 'maintenance':
      return 'Onderhoud';
    case 'inactive':
      return 'Nie Aktief';
    case 'decommissioned':
      return 'Afgeskakel';
    default:
      return status || 'Onbekend';
  }
};

const calcChange = (current, previous) => {
  if (previous === 0) return current > 0 ? '+Nuut' : '';
  const diff = ((current - previous) / previous) * 100;
  return `${diff >= 0 ? '+' : ''}${Math.round(diff)}% van verlede maand`;
};

const DashboardPage = () => {
  const [recentRepairs, setRecentRepairs] = useState([]);
  const [activityItems, setActivityItems] = useState([]);
  const [predictionSummary, setPredictionSummary] = useState({ total: 0, attention: 0, replacement: 0, overdue: 0 });
  const [statsData, setStatsData] = useState({
    totalAssets: 0,
    activeRepairs: 0,
    completedTickets: 0,
    newTickets: 0,
    assetChange: '',
    repairChange: '',
    completedChange: '',
    newChange: '',
  });
  const [repairTrendData, setRepairTrendData] = useState({
    labels: ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Sa', 'So'],
    datasets: [{
      label: 'Voltooide Take',
      data: [0, 0, 0, 0, 0, 0, 0],
      borderColor: '#10b981',
      backgroundColor: 'rgba(16, 185, 129, 0.1)',
      fill: true,
      tension: 0.3
    }]
  });

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
          if (source?.[key] != null && source[key] !== '') {
            return source[key];
          }
        }
      }
      return null;
    };

    const entityName = getFirstValue([
      'asset_name', 'room_name', 'stock_name', 'user_name', 'job_desc', 'fault_description', 'quote_id', 'location_name', 'report_name', 'name', 'title'
    ]);
    const actionLabel = action === 'delete' ? 'Verwyder' : action === 'update' ? 'Werk' : 'Skep';

    const labels = {
      asset: 'Bate',
      assettype: 'Bate-tipe',
      job: 'Werksopdrag',
      jobcard: 'Werksopdrag',
      fault: 'Foutkaartjie',
      faultcard: 'Foutkaartjie',
      room: 'Kamer',
      stock: 'Voorraaditem',
      user: 'Gebruiker',
      quote: 'Kwotasie',
      location: 'Ligging/Terrrein',
      report: 'Verslag',
    };

    const label = labels[table] || table || 'Item';
    const nameText = entityName ? `: ${entityName}` : '';

    return `${actionLabel} ${label}${nameText}`;
  };

  const getMonthRange = (year, month) => {
    const start = new Date(year, month, 1);
    const end = new Date(year, month + 1, 1);
    return { start, end };
  };

  useEffect(() => {
    const fetchRecentData = async () => {
      try {
        const [assetsResponse, workOrdersResponse, ticketsResponse, auditResponse, predictionsResponse] = await Promise.all([
          assetsAPI.getAll(),
          workOrdersAPI.getAll(),
          ticketsAPI.getAll(),
          auditsAPI.getAll(),
          apiClient.get('/predictions'),
        ]);

        const assets = Array.isArray(assetsResponse?.data) ? assetsResponse.data : [];
        const orders = Array.isArray(workOrdersResponse?.data) ? workOrdersResponse.data : [];
        const tickets = Array.isArray(ticketsResponse?.data) ? ticketsResponse.data : [];
        const auditEntries = Array.isArray(auditResponse?.data) ? auditResponse.data : [];

        const now = new Date();
        const thisMonth = now.getMonth();
        const thisYear = now.getFullYear();
        const lastMonth = thisMonth === 0 ? 11 : thisMonth - 1;
        const lastMonthYear = thisMonth === 0 ? thisYear - 1 : thisYear;

        const { start: thisStart, end: thisEnd } = getMonthRange(thisYear, thisMonth);
        const { start: lastStart, end: lastEnd } = getMonthRange(lastMonthYear, lastMonth);

        // Stat: Totale Bates
        const totalAssets = assets.length;

        // Stat: Aktiewe Herstelwerk
        const activeRepairs = orders.filter(o => o.job_status === 'Besig' || o.job_status === 'Geskeduleer').length;
        const lastActiveRepairs = orders.filter(o => {
          const d = new Date(o.job_createddatetime);
          return (o.job_status === 'Besig' || o.job_status === 'Geskeduleer') && d >= lastStart && d < lastEnd;
        }).length;

        // Stat: Voltooide Foutkaartjies
        const completedTickets = tickets.filter(t => t.fault_status === 'Gesluit' || t.fault_status === 'Opgelos').length;
        const lastCompletedTickets = tickets.filter(t => {
          const d = new Date(t.fault_reportdatetime);
          return (t.fault_status === 'Gesluit' || t.fault_status === 'Opgelos') && d >= lastStart && d < lastEnd;
        }).length;

        // Stat: Nuwe Foutkaartjies (dié maand)
        const newTickets = tickets.filter(t => {
          const d = new Date(t.fault_reportdatetime);
          return d >= thisStart && d < thisEnd;
        }).length;
        const lastNewTickets = tickets.filter(t => {
          const d = new Date(t.fault_reportdatetime);
          return d >= lastStart && d < lastEnd;
        }).length;

        setStatsData({
          totalAssets,
          activeRepairs,
          completedTickets,
          newTickets,
          assetChange: calcChange(totalAssets, assets.filter(a => {
            const d = new Date(a.asset_created_datetime);
            return d >= lastStart && d < lastEnd;
          }).length),
          repairChange: calcChange(activeRepairs, lastActiveRepairs),
          completedChange: calcChange(completedTickets, lastCompletedTickets),
          newChange: calcChange(newTickets, lastNewTickets),
        });

        // Repair trend (voltooide take per dag van week)
        const dayNames = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Sa', 'So'];
        const dayCounts = [0, 0, 0, 0, 0, 0, 0];
        const completedOrders = orders.filter(o => o.job_status === 'Voltooid' && o.job_finisheddatetime);
        completedOrders.forEach(o => {
          const d = new Date(o.job_finisheddatetime);
          const dayIdx = d.getDay();
          const adjustedIdx = dayIdx === 0 ? 6 : dayIdx - 1;
          dayCounts[adjustedIdx]++;
        });

        setRepairTrendData({
          labels: dayNames,
          datasets: [{
            label: 'Voltooide Take',
            data: dayCounts,
            borderColor: '#10b981',
            backgroundColor: 'rgba(16, 185, 129, 0.1)',
            fill: true,
            tension: 0.3
          }]
        });

        // Recent repairs
        const repairOrders = orders
          .filter((order) => order?.job_type && String(order.job_type).toLowerCase() !== 'inspection')
          .sort((a, b) => {
            const dateA = new Date(a?.job_createddatetime || 0).getTime();
            const dateB = new Date(b?.job_createddatetime || 0).getTime();
            return dateB - dateA;
          })
          .slice(0, 3);

        setRecentRepairs(repairOrders);

        // Activity log
        const activities = auditEntries
          .map((entry) => {
            const action = String(entry?.action || '').toLowerCase();
            const table = String(entry?.affectedtable || '').toLowerCase();
            const formattedTime = formatActivityTime(entry?.actiondatetime);

            let description = buildActivityDescription(entry);
            let link = '/dashboard';

            if (table.includes('job')) {
              link = '/work-orders';
            } else if (table.includes('fault')) {
              link = '/fault-tickets';
            } else if (table.includes('asset')) {
              link = '/assets';
            } else if (table.includes('room')) {
              link = '/rooms';
            } else if (table.includes('stock')) {
              link = '/stock';
            } else if (table.includes('user')) {
              link = '/users';
            } else if (table.includes('quote')) {
              link = '/quotes';
            }

            return {
              id: entry?.auditlog_id || `${table}-${action}-${formattedTime}`,
              time: formattedTime,
              description,
              link,
              type: table,
            };
          })
          .sort((a, b) => {
            const dateA = new Date(a.time).getTime();
            const dateB = new Date(b.time).getTime();
            return dateB - dateA;
          })
          .slice(0, 5);

        setActivityItems(activities);

        // Predictions
        const preds = Array.isArray(predictionsResponse?.data) ? predictionsResponse.data : [];
        setPredictionSummary({
          total: preds.length,
          attention: preds.filter(p => p.maintenance_overdue || p.lifespan_exceeded || p.replacement_suggested).length,
          replacement: preds.filter(p => p.replacement_suggested).length,
          overdue: preds.filter(p => p.maintenance_overdue).length,
        });
      } catch (error) {
        console.error('Fout by laai van paneelbord-data:', error);
        setRecentRepairs([]);
        setActivityItems([]);
      }
    };

    fetchRecentData();

    const refreshInterval = window.setInterval(() => {
      fetchRecentData();
    }, 10000);

    const handleFocus = () => {
      fetchRecentData();
    };

    window.addEventListener('focus', handleFocus);

    return () => {
      window.clearInterval(refreshInterval);
      window.removeEventListener('focus', handleFocus);
    };
  }, []);
  const [assetStatusChartData, setAssetStatusChartData] = useState({
    labels: [],
    datasets: [{ data: [], backgroundColor: [], borderWidth: 0 }]
  });
  const [assetStatusLoading, setAssetStatusLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;

    const loadAssetStatus = async () => {
      try {
        const response = await apiClient.assets.getStatusSummary();
        if (!isMounted) return;

        const summary = response?.data || [];
        const labels = summary.map((item) => mapAssetStatusLabel(item.status));
        const counts = summary.map((item) => item.count || 0);
        const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444'];

        setAssetStatusChartData({
          labels,
          datasets: [{
            data: counts,
            backgroundColor: colors.slice(0, labels.length),
            borderWidth: 0
          }]
        });
      } catch (error) {
        console.error('Kon bate-status data nie laai nie:', error);
        if (isMounted) {
          setAssetStatusChartData({
            labels: ['Geen data'],
            datasets: [{ data: [1], backgroundColor: ['#94a3b8'], borderWidth: 0 }]
          });
        }
      } finally {
        if (isMounted) {
          setAssetStatusLoading(false);
        }
      }
    };

    loadAssetStatus();

    return () => {
      isMounted = false;
    };
  }, []);

  return (
    <div className="main">
      <div className="content">
          <div className="stats-grid">
            <div className="stat-card">
              <h4>Totale Bates</h4>
              <div className="stat-number">{statsData.totalAssets}</div>
              <div className="stat-change positive">{statsData.assetChange}</div>
            </div>
            <div className="stat-card">
              <h4>Aktiewe Herstelwerk</h4>
              <div className="stat-number">{statsData.activeRepairs}</div>
              <div className="stat-change negative">{statsData.repairChange}</div>
            </div>
            <div className="stat-card">
              <h4>Voltooide Foutkaartjies</h4>
              <div className="stat-number">{statsData.completedTickets}</div>
              <div className="stat-change positive">{statsData.completedChange}</div>
            </div>
            <div className="stat-card">
              <h4>Nuwe Foutkaartjies</h4>
              <div className="stat-number">{statsData.newTickets}</div>
              <div className="stat-change negative">{statsData.newChange}</div>
            </div>
          </div>

          <div className="stats-grid" style={{ marginBottom: '20px' }}>
            <div className="stat-card" style={{ borderLeft: '4px solid #c97c3c' }}>
              <h4>Bate Voorspellings</h4>
              <div className="stat-number">{predictionSummary.total}</div>
              <div className="stat-change" style={{ color: predictionSummary.attention > 0 ? '#b91c1c' : '#065f46' }}>
                {predictionSummary.attention} benodig aandag
              </div>
            </div>
            <div className="stat-card" style={{ borderLeft: '4px solid #b91c1c' }}>
              <h4>Vervanging Voorgestel</h4>
              <div className="stat-number">{predictionSummary.replacement}</div>
              <Link to="/predictions" className="stat-change" style={{ color: '#935e28', fontWeight: 600 }}>
                Bekyk voorspellings →
              </Link>
            </div>
            <div className="stat-card" style={{ borderLeft: '4px solid #b91c1c' }}>
              <h4>Onderhoud Agterstallig</h4>
              <div className="stat-number">{predictionSummary.overdue}</div>
              <Link to="/predictions" className="stat-change" style={{ color: '#935e28', fontWeight: 600 }}>
                Bekyk besonderhede →
              </Link>
            </div>
          </div>

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
                      <tr key={order.job_id || order.id}>
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
                        <div style={{ fontSize: '0.85rem', color: '#6b7280', marginTop: '0.2rem' }}>
                          {item.type || 'audit'}
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>

          <div className="charts-container">
            <div className="data-panel">
              <h3>Herstelwerk Tendens (7 Dae)</h3>
              <div className="chart-container">
                <Line data={repairTrendData} options={{ responsive: true, maintainAspectRatio: false }} />
              </div>
            </div>
            <div className="data-panel">
              <h3>Bate Status Verspreiding</h3>
              <div className="chart-container">
                {assetStatusLoading ? (
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%' }}>Laai bate-status...</div>
                ) : (
                  <Doughnut data={assetStatusChartData} options={{ responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }} />
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
  );
};

export default DashboardPage;
=======
import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Line, Doughnut } from 'react-chartjs-2';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, ArcElement } from 'chart.js';
import { useCurrentUser } from '../hooks/useCurrentUser';
import '../styles/App.css';
import '../styles/Dashboard.css';
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import UserProfileHeader from '../components/UserProfileHeader';
import { auditsAPI, workOrdersAPI } from '../services/api';
import { apiClient } from '../services/api';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, ArcElement);

const mapAssetStatusLabel = (status) => {
  switch (status?.toLowerCase()) {
    case 'active':
      return 'In Gebruik';
    case 'maintenance':
      return 'Onderhoud';
    case 'inactive':
      return 'Nie Aktief';
    case 'decommissioned':
      return 'Afgeskakel';
    default:
      return status || 'Onbekend';
  }
};

const DashboardPage = () => {
  // Haal huidige gebruiker se info en admin-status
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();
  const [recentRepairs, setRecentRepairs] = useState([]);
  const [activityItems, setActivityItems] = useState([]);

  const formatActivityTime = (value) => {
    if (!value) return 'Onlangs';

    const date = new Date(value); // Parse as UTC
    if (Number.isNaN(date.getTime())) return 'Onlangs';

    // Convert to UTC+2
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
          if (source?.[key] != null && source[key] !== '') {
            return source[key];
          }
        }
      }
      return null;
    };

    const entityName = getFirstValue([
      'asset_name', 'room_name', 'stock_name', 'contractor_name', 'user_name', 'job_desc', 'fault_description', 'quote_id', 'location_name', 'report_name', 'name', 'title'
    ]);
    const actionLabel = action === 'delete' ? 'Verwyder' : action === 'update' ? 'Werk' : 'Skep';

    const labels = {
      asset: 'Bate',
      assettype: 'Bate-tipe',
      job: 'Werksopdrag',
      jobcard: 'Werksopdrag',
      fault: 'Foutkaartjie',
      faultcard: 'Foutkaartjie',
      contractor: 'Kontrakteur',
      room: 'Kamer',
      stock: 'Voorraaditem',
      user: 'Gebruiker',
      quote: 'Kwotasie',
      location: 'Ligging/Terrrein',
      report: 'Verslag',
    };

    const label = labels[table] || table || 'Item';
    const nameText = entityName ? `: ${entityName}` : '';

    return `${actionLabel} ${label}${nameText}`;
  };

  useEffect(() => {
    const fetchRecentData = async () => {
      try {
        const [workOrdersResponse, auditResponse] = await Promise.all([
          workOrdersAPI.getAll(),
          auditsAPI.getAll(),
        ]);

        const orders = Array.isArray(workOrdersResponse?.data) ? workOrdersResponse.data : [];
        const auditEntries = Array.isArray(auditResponse?.data) ? auditResponse.data : [];

        const repairOrders = orders
          .filter((order) => order?.job_type && String(order.job_type).toLowerCase() !== 'inspection')
          .sort((a, b) => {
            const dateA = new Date(a?.job_createddatetime || 0).getTime();
            const dateB = new Date(b?.job_createddatetime || 0).getTime();
            return dateB - dateA;
          })
          .slice(0, 3);

        setRecentRepairs(repairOrders);

        const activities = auditEntries
          .map((entry) => {
            const action = String(entry?.action || '').toLowerCase();
            const table = String(entry?.affectedtable || '').toLowerCase();
            const formattedTime = formatActivityTime(entry?.actiondatetime);

            let description = buildActivityDescription(entry);
            let link = '/dashboard';

            if (table.includes('job')) {
              link = '/work-orders';
            } else if (table.includes('fault')) {
              link = '/fault-tickets';
            } else if (table.includes('contractor')) {
              link = '/contractors';
            } else if (table.includes('asset')) {
              link = '/assets';
            } else if (table.includes('room')) {
              link = '/rooms';
            } else if (table.includes('stock')) {
              link = '/stock';
            } else if (table.includes('user')) {
              link = '/users';
            } else if (table.includes('quote')) {
              link = '/quotes';
            }

            return {
              id: entry?.auditlog_id || `${table}-${action}-${formattedTime}`,
              time: formattedTime,
              description,
              link,
              type: table,
            };
          })
          .sort((a, b) => {
            const dateA = new Date(a.time).getTime();
            const dateB = new Date(b.time).getTime();
            return dateB - dateA;
          })
          .slice(0, 5);

        setActivityItems(activities);
      } catch (error) {
        console.error('Fout by laai van paneelbord-data:', error);
        setRecentRepairs([]);
        setActivityItems([]);
      }
    };

    fetchRecentData();

    const refreshInterval = window.setInterval(() => {
      fetchRecentData();
    }, 10000);

    const handleFocus = () => {
      fetchRecentData();
    };

    window.addEventListener('focus', handleFocus);

    return () => {
      window.clearInterval(refreshInterval);
      window.removeEventListener('focus', handleFocus);
    };
  }, []);
  const [assetStatusChartData, setAssetStatusChartData] = useState({
    labels: [],
    datasets: [{ data: [], backgroundColor: [], borderWidth: 0 }]
  });
  const [assetStatusLoading, setAssetStatusLoading] = useState(true);

  // Data vir trendlyn-grafiek (herstelwerk per dag van week)
  // Toon hoeveel take voltooide is, met groene kleur-skema
  const repairTrendData = {
    labels: ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Sa', 'So'],
    datasets: [{
      label: 'Voltooide Take',
      data: [2, 5, 3, 8, 4, 1, 2],
      borderColor: '#10b981',        // Groen lyn
      backgroundColor: 'rgba(16, 185, 129, 0.1)',  // Ligte groen vulling
      fill: true,
      tension: 0.3
    }]
  };

  useEffect(() => {
    let isMounted = true;

    const loadAssetStatus = async () => {
      try {
        const response = await apiClient.assets.getStatusSummary();
        if (!isMounted) return;

        const summary = response?.data || [];
        const labels = summary.map((item) => mapAssetStatusLabel(item.status));
        const counts = summary.map((item) => item.count || 0);
        const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444'];

        setAssetStatusChartData({
          labels,
          datasets: [{
            data: counts,
            backgroundColor: colors.slice(0, labels.length),
            borderWidth: 0
          }]
        });
      } catch (error) {
        console.error('Kon bate-status data nie laai nie:', error);
        if (isMounted) {
          setAssetStatusChartData({
            labels: ['Geen data'],
            datasets: [{ data: [1], backgroundColor: ['#94a3b8'], borderWidth: 0 }]
          });
        }
      } finally {
        if (isMounted) {
          setAssetStatusLoading(false);
        }
      }
    };

    loadAssetStatus();

    return () => {
      isMounted = false;
    };
  }, []);

  return (
    <div style={{ display: 'flex' }}>
      <Sidebar currentPath="/dashboard" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Paneelbord</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          {/* Hoofskakelstatistieke met tellings en maandeligse tendense */}
          <div className="stats-grid">
            <div className="stat-card">
              <h4>Totale Bates</h4>
              <div className="stat-number">150</div>
              <div className="stat-change positive">+5% van verlede maand</div>
            </div>
            <div className="stat-card">
              <h4>Aktiewe Herstelwerk</h4>
              <div className="stat-number">12</div>
              <div className="stat-change negative">-2% van verlede maand</div>
            </div>
            <div className="stat-card">
              <h4>Voltooide Foutkaartjies</h4>
              <div className="stat-number">45</div>
              <div className="stat-change positive">+10% van verlede maand</div>
            </div>
            <div className="stat-card">
              <h4>Nuwe Foutkaartjies</h4>
              <div className="stat-number">8</div>
              <div className="stat-change negative">-3% van verlede maand</div>
            </div>
          </div>

          {/* Tabel en aktiwiteit-log */}
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
                      <tr key={order.job_id || order.id}>
                        <td>{order.asset_id || '-'}</td>
                        <td>{order.job_desc || order.brief_description || 'Geen beskrywing'}</td>
                        <td>
                          <span className={`status ${order.job_status === 'completed' ? 'completed' : order.job_status === 'in_progress' ? 'in-progress' : 'pending'}`}>
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
                        <div style={{ fontSize: '0.85rem', color: '#6b7280', marginTop: '0.2rem' }}>
                          {item.type || 'audit'}
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>

          {/* Trendgrafieke en verspreidingsgrafieke vir visuele analise */}
          <div className="charts-container">
            <div className="data-panel">
              <h3>Herstelwerk Tendens (7 Dae)</h3>
              <div className="chart-container">
                {/* Trendlyn-grafiek toon herstelwerk oor week */}
                <Line data={repairTrendData} options={{ responsive: true, maintainAspectRatio: false }} />
              </div>
            </div>
            <div className="data-panel">
              <h3>Bate Status Verspreiding</h3>
              <div className="chart-container">
                {assetStatusLoading ? (
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%' }}>Laai bate-status...</div>
                ) : (
                  <Doughnut data={assetStatusChartData} options={{ responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }} />
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DashboardPage;
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
