import React from 'react';
import { Link } from 'react-router-dom';
import '../styles/Reports.css';

function ReportsPage() {
  return (
    <div style={{ display: 'flex' }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li><Link to="/assets">Bates</Link></li>
          <li><Link to="/calendar">Kalender</Link></li>
          <li><Link to="/analysis">Analise</Link></li>
          <li><Link to="/reports" style={{ background: '#935e28' }}>Verslae</Link></li>
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
          <h3>Verslae</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
          <p>Verslae bladsy - Hier sal die verslae komponent wees.</p>
        </div>
      </div>
    </div>
  );
}

export default ReportsPage;