import React from 'react';
import { Link } from 'react-router-dom';
import '../styles/Analysis.css';

function AnalysisPage() {
  return (
    <div style={{ display: 'flex' }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li><Link to="/assets">Bates</Link></li>
          <li><Link to="/calendar">Kalender</Link></li>
          <li><Link to="/analysis" style={{ background: '#935e28' }}>Analise</Link></li>
          <li><Link to="/reports">Verslae</Link></li>
          <li><Link to="/reporting">Rapportering</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
        </ul>
        <div className="logout-container">
          <Link to="/login" className="btn-logout-sidebar">Logout</Link>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Analise</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
          <div className="stats-grid">
            <div className="stat-card">
              <h4>Totale Bates</h4>
              <p className="stat-number">1,248</p>
              <span className="stat-change positive">+4.5% nuwe bates</span>
            </div>
            <div className="stat-card">
              <h4>Bates Tans Uitgeleen</h4>
              <p className="stat-number">56</p>
              <span className="stat-change">Tans in gebruik deur personeel</span>
            </div>
            <div className="stat-card">
              <h4>Onderhoud Benodig</h4>
              <p className="stat-number">12</p>
              <span className="stat-change negative">3 Kritieke herstelwerk</span>
            </div>
            <div className="stat-card">
              <h4>Beskikbaarheidskoers</h4>
              <p className="stat-number">92%</p>
              <span className="stat-change positive">Bates gereed vir gebruik</span>
            </div>
          </div>

          <div className="charts-container">
            <div className="chart-box">
              <h3>Bate-benutting per Maand</h3>
              <div style={{ height: '250px', background: '#f0f0f0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                Grafiek Plekganger
              </div>
            </div>
            <div className="chart-box">
              <h3>Bates per Kategorie</h3>
              <div style={{ height: '250px', background: '#f0f0f0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                Grafiek Plekganger
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default AnalysisPage;