import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { authAPI, ticketsAPI, workOrdersAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import '../styles/Analysis.css';
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  ArcElement,
  Tooltip,
  Legend,
} from 'chart.js';
import { Bar, Doughnut, Line } from 'react-chartjs-2';

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  ArcElement,
  Tooltip,
  Legend
);

const normalizeValue = (value) => String(value ?? '').trim().toLowerCase();

const formatDurationHours = (hours) => {
  if (hours == null || Number.isNaN(hours)) {
    return 'N/A';
  }

  const totalMinutes = Math.round(hours * 60);
  const days = Math.floor(totalMinutes / (24 * 60));
  const hoursLeft = Math.floor((totalMinutes % (24 * 60)) / 60);
  const minutes = totalMinutes % 60;

  if (days > 0) {
    return `${days}d ${hoursLeft}u`;
  }

  if (hoursLeft > 0) {
    return `${hoursLeft}u ${minutes}m`;
  }

  return `${minutes}m`;
};

const buildMonthlyTrend = (jobs) => {
  const months = [];
  const counts = [];
  const now = new Date();

  for (let index = 5; index >= 0; index -= 1) {
    const date = new Date(now.getFullYear(), now.getMonth() - index, 1);
    const label = date.toLocaleDateString('en-US', { month: 'short' });
    months.push(label);
    counts.push(0);
  }

  jobs.forEach((job) => {
    const created = job.job_createddatetime ? new Date(job.job_createddatetime) : null;
    if (!created || Number.isNaN(created.getTime())) {
      return;
    }

    const monthIndex = (created.getFullYear() - now.getFullYear()) * 12 + (created.getMonth() - now.getMonth());
    if (monthIndex >= -5 && monthIndex <= 0) {
      const targetIndex = 5 + monthIndex;
      counts[targetIndex] += 1;
    }
  });

  return { labels: months, data: counts };
};

const buildMetrics = (jobs, faults) => {
  const safeJobs = Array.isArray(jobs) ? jobs : [];
  const safeFaults = Array.isArray(faults) ? faults : [];

  const activeWorkOrders = safeJobs.filter((job) => ['open', 'besig'].includes(normalizeValue(job.job_status))).length;
  const completedWorkOrders = safeJobs.filter((job) => normalizeValue(job.job_status) === 'voltooid').length;
  const backlogWorkOrders = safeJobs.filter((job) => normalizeValue(job.job_status) === 'wag').length;

  const closedFaults = safeFaults.filter((fault) => ['opgelos', 'verwerp'].includes(normalizeValue(fault.fault_status)));
  const mttrHours = closedFaults
    .map((fault) => {
      if (!fault.fault_reportdatetime || !fault.fault_updatedatetime) {
        return null;
      }

      const start = new Date(fault.fault_reportdatetime);
      const end = new Date(fault.fault_updatedatetime);
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
        return null;
      }

      const diff = end.getTime() - start.getTime();
      return diff > 0 ? diff / (1000 * 60 * 60) : null;
    })
    .filter((value) => value != null);

  const avgMttrHours = mttrHours.length > 0
    ? mttrHours.reduce((sum, value) => sum + value, 0) / mttrHours.length
    : null;

  const jobsByFaultId = safeJobs.reduce((acc, job) => {
    if (job.fault_id != null) {
      if (!acc[job.fault_id]) {
        acc[job.fault_id] = [];
      }
      acc[job.fault_id].push(job);
    }
    return acc;
  }, {});

  const firstTimeFixes = closedFaults.filter((fault) => {
    const relatedJobs = jobsByFaultId[fault.fault_id] || [];
    const completedJobs = relatedJobs.filter((job) => normalizeValue(job.job_status) === 'voltooid');
    return completedJobs.length > 0 && relatedJobs.length <= 2;
  }).length;

  const plannedMaintenance = safeFaults.filter((fault) => normalizeValue(fault.fault_type) === 'maintenance').length;
  const urgentRepairs = safeFaults.filter((fault) => normalizeValue(fault.fault_type) === 'repair').length;
  const firstTimeFixRate = closedFaults.length > 0 ? Math.round((firstTimeFixes / closedFaults.length) * 100) : 0;
  const monthlyTrend = buildMonthlyTrend(safeJobs);

  return {
    workOrderVolume: {
      total: safeJobs.length,
      active: activeWorkOrders,
      completed: completedWorkOrders,
      backlog: backlogWorkOrders,
    },
    mttrHours: avgMttrHours,
    mttrLabel: avgMttrHours != null ? formatDurationHours(avgMttrHours) : 'N/A',
    firstTimeFixRate,
    maintenanceRatio: {
      planned: plannedMaintenance,
      urgent: urgentRepairs,
    },
    monthlyTrend,
  };
};

function AnalysisPage() {
  const { isAdmin, user } = useCurrentUser();
  const logout = useLogout();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [metrics, setMetrics] = useState({
    workOrderVolume: { total: 0, active: 0, completed: 0, backlog: 0 },
    mttrHours: null,
    mttrLabel: 'N/A',
    firstTimeFixRate: 0,
    maintenanceRatio: { planned: 0, urgent: 0 },
    monthlyTrend: { labels: [], data: [] },
  });

  useEffect(() => {
    let mounted = true;

    (async () => {
      try {
        await authAPI.me();
        const [jobsResponse, faultsResponse] = await Promise.all([
          workOrdersAPI.getAll(),
          ticketsAPI.getAll(),
        ]);

        if (!mounted) {
          return;
        }

        const jobs = jobsResponse?.data ?? [];
        const faults = faultsResponse?.data ?? [];
        setMetrics(buildMetrics(jobs, faults));
        setLoading(false);
      } catch (err) {
        if (!mounted) {
          return;
        }

        setError('Kon analise-data nie laai nie.');
        setLoading(false);
        try {
          sessionStorage.clear();
          localStorage.clear();
        } catch (_) {
          // ignore cleanup errors
        }
        window.location.replace(window.location.origin + '/login');
      }
    })();

    return () => { mounted = false; };
  }, []);

  if (loading) {
    return (
      <div style={{ display: 'flex' }}>
        <div className="main">
          <div className="content">Laai analise-data...</div>
        </div>
      </div>
    );
  }

  const workOrderChartData = {
    labels: ['Aktief', 'Voltooid', 'Agterstallig'],
    datasets: [
      {
        label: 'Werkopdragte',
        data: [metrics.workOrderVolume.active, metrics.workOrderVolume.completed, metrics.workOrderVolume.backlog],
        backgroundColor: ['#935e28', '#3d7a3d', '#c97c3c'],
        borderRadius: 8,
      },
    ],
  };

  const monthlyTrendChartData = {
    labels: metrics.monthlyTrend.labels,
    datasets: [
      {
        label: 'Nuwe werkopdragte',
        data: metrics.monthlyTrend.data,
        borderColor: '#935e28',
        backgroundColor: 'rgba(147, 94, 40, 0.2)',
        fill: true,
        tension: 0.35,
      },
    ],
  };

  const maintenanceRatioData = {
    labels: ['Beplande instandhouding', 'Dringende herstelwerk'],
    datasets: [
      {
        data: [metrics.maintenanceRatio.planned, metrics.maintenanceRatio.urgent],
        backgroundColor: ['#3d7a3d', '#c97c3c'],
        borderColor: ['#ffffff', '#ffffff'],
        borderWidth: 2,
      },
    ],
  };

  return (
    <div>
      <Sidebar currentPath="/analysis" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Analise</h3>
          <div className="user-profile-box" style={{ textAlign: 'right', fontSize: '14px', lineHeight: '1.3' }}>
            {user ? (
              <>
                <div className="user-name" style={{ fontWeight: 'bold' }}>
                  {user.user_name} {user.user_surname}
                </div>
                <div className="user-role" style={{ fontSize: '12px', color: '#935e28', fontWeight: '600' }}>
                  {user.role_id === 3 ? 'Administrateur' : user.role_id === 2 ? 'Personeel' : 'Student'}
                </div>
                <div className="user-email" style={{ fontSize: '11px', color: '#666' }}>
                  {user.user_email}
                </div>
              </>
            ) : (
              <div className="user-loading" style={{ color: '#999' }}>Laai profiel...</div>
            )}
          </div>
        </div>

        <div className="content">
          {error ? <div className="analysis-empty-state">{error}</div> : null}

          <div className="analysis-kpi-grid">
            <div className="analysis-kpi-card">
              <h4>Werkopdrag-volume</h4>
              <p className="analysis-kpi-value">{metrics.workOrderVolume.total}</p>
              <span className="analysis-kpi-caption">{metrics.workOrderVolume.active} aktief • {metrics.workOrderVolume.completed} voltooid • {metrics.workOrderVolume.backlog} agterstallig</span>
            </div>
            <div className="analysis-kpi-card">
              <h4>MTTR</h4>
              <p className="analysis-kpi-value">{metrics.mttrLabel}</p>
              <span className="analysis-kpi-caption">Gemiddelde tyd vanaf oop tot afsluiting</span>
            </div>
            <div className="analysis-kpi-card">
              <h4>First-time fix-rate</h4>
              <p className="analysis-kpi-value">{metrics.firstTimeFixRate}%</p>
              <span className="analysis-kpi-caption">Geïntegreer uit voltooi-de werkopdragte per foutkaartjie</span>
            </div>
            <div className="analysis-kpi-card">
              <h4>Onderhoudstipe-verhouding</h4>
              <p className="analysis-kpi-value">{metrics.maintenanceRatio.planned}/{metrics.maintenanceRatio.urgent}</p>
              <span className="analysis-kpi-caption">Beplanne instandhouding teen dringende herstelwerk</span>
            </div>
          </div>

          <div className="analysis-chart-grid">
            <div className="analysis-chart-card">
              <h3>Werkopdrag-volume oor tyd</h3>
              <div className="analysis-chart-area">
                <Line data={monthlyTrendChartData} options={{ responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, ticks: { precision: 0 } } } }} />
              </div>
            </div>
            <div className="analysis-chart-card">
              <h3>Werkstatus-opsplitsing</h3>
              <div className="analysis-chart-area">
                <Bar data={workOrderChartData} options={{ responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, ticks: { precision: 0 } } } }} />
              </div>
            </div>
          </div>

          <div className="analysis-chart-grid single">
            <div className="analysis-chart-card">
              <h3>Onderhoudstipe-verhouding</h3>
              <div className="analysis-chart-area analysis-chart-area-small">
                <Doughnut data={maintenanceRatioData} options={{ responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }} />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default AnalysisPage;