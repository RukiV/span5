import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Line, Doughnut } from 'react-chartjs-2';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, ArcElement } from 'chart.js';
import { useCurrentUser } from '../hooks/useCurrentUser';
import '../styles/App.css';
import '../styles/Dashboard.css';
import { useLogout } from './Page.jsx';
import UserProfileHeader from '../components/UserProfileHeader';
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
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard" style={{ background: '#935e28' }}>Paneelbord</Link></li>
          <li class="dropdown" >
              <div className="dropdown-trigger">
                  <span>Bates & Voorraad</span>
              </div>
                  <div className="dropdown-content">
                  <Link to="/assets">Bates</Link>
                  <Link to="/stock">Voorraad</Link>
                  </div>
          </li>
              <li class="dropdown">
              <div className="dropdown-trigger">
                  <span>Lokale & Terreine</span>
              </div>
              <div className="dropdown-content">
                  <li><Link to="/rooms">Lokale</Link></li>
                  <li><Link to="/terrains">Terreine</Link></li>
              </div>
          </li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          <li><Link to="/contractors">Kontrakteurs</Link></li>
          <li><Link to="/calendar" >Kalender</Link></li>
          <li><Link to="/analysis">Analise</Link></li>
          <li><Link to="/reports" >Verslae</Link></li>  
          {/* Toon Gebruikers-skakel slegs vir Administrateure (role_id=3) */}
          {isAdmin && <li><Link to="/users">Gebruikers</Link></li>}
        </ul>
        <div className="logout-container">
          <button type="button" className="btn-logout-sidebar" onClick={() => logout()}>Teken Uit</button>
        </div>
      </div>

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
                  <tr>
                    <td>Lug versorger</td>
                    <td>Filter vervanging</td>
                    <td><span className="status completed">Voltooi</span></td>
                    <td>2023-10-01</td>
                  </tr>
                  <tr>
                    <td>Kragopwerker</td>
                    <td>Brandstof pomp herstel</td>
                    <td><span className="status in-progress">Besig</span></td>
                    <td>2023-10-02</td>
                  </tr>
                  <tr>
                    <td>Huisbak Hoof</td>
                    <td>Kabel inspeksie</td>
                    <td><span className="status pending">Hangende</span></td>
                    <td>2023-10-03</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div className="data-panel">
              <h3>Aktiwiteit Log</h3>
              <div className="activity-list">
                <div className="activity-item">
                  <div className="activity-time">10:30</div>
                  <div className="activity-desc">Nuwe foutkaartjie geskep vir HVAC stelsel</div>
                </div>
                <div className="activity-item">
                  <div className="activity-time">09:45</div>
                  <div className="activity-desc">Herstelwerk voltooi vir water pomp</div>
                </div>
                <div className="activity-item">
                  <div className="activity-time">08:20</div>
                  <div className="activity-desc">Onderhoud skedule opgedateer</div>
                </div>
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