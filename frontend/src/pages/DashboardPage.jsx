import React from 'react';
import { Link } from 'react-router-dom';
import { Line, Doughnut } from 'react-chartjs-2';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, ArcElement } from 'chart.js';
import { useCurrentUser } from '../hooks/useCurrentUser';
import '../styles/Dashboard.css';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, ArcElement);

const DashboardPage = () => {
  const { isAdmin } = useCurrentUser();

  const repairTrendData = {
    labels: ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Sa', 'So'],
    datasets: [{
      label: 'Voltooide Take',
      data: [2, 5, 3, 8, 4, 1, 2],
      borderColor: '#10b981',
      backgroundColor: 'rgba(16, 185, 129, 0.1)',
      fill: true,
      tension: 0.3
    }]
  };

  const statusDistData = {
    labels: ['In Gebruik', 'Beskikbaar', 'Onderhoud'],
    datasets: [{
      data: [65, 40, 15],
      backgroundColor: ['#3b82f6', '#10b981', '#ef4444'],
      borderWidth: 0
    }]
  };

  return (
    <div style={{ display: 'flex' }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard" style={{ background: '#935e28' }}>Paneelbord</Link></li>
          <li><Link to="/assets">Bates</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          {isAdmin && <li><Link to="/users">Gebruikers</Link></li>}
        </ul>
        <div className="logout-container">
          <Link to="/login" className="btn-logout-sidebar">Logout</Link>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Paneelbord</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
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

          <div className="dashboard-grid">
            <div className="data-panel">
              <h3>Onlangse Herstelwerk</h3>
              <table className="repair-table">
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
                <Doughnut data={statusDistData} options={{ responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }} />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DashboardPage;