import React from 'react';
import { Link } from 'react-router-dom';
import '../styles/App.css';
import '../styles/Reports.css';
import { useLogout } from './Page.jsx';
import UserProfileHeader from '../components/UserProfileHeader';

function ReportsPage() {
  const logout = useLogout();
  return (
    <div style={{ display: 'flex' }}>
      {/* LINKERBAAD - Navigasie-menu */}
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li><Link to="/assets">Bates</Link></li>
          <li><Link to="/stock">Voorraad</Link></li>
          <li><Link to="/terrains">Terreine</Link></li>
          <li><Link to="/calendar">Kalender</Link></li>
          {/* Opmerking: Typo in oorspronklike kode - Lk in plaas van Link */}
          <li><Link to="/analysis">Analise</Link></li>
          {/* Markeer huidige blad as aktief met bruin agtergrond */}
          <li><Link to="/reports" style={{ background: '#935e28' }}>Verslae</Link></li>
          <li><Link to="/reporting">Rapportering</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
        </ul>
        <div className="logout-container">
          <button type="button" className="btn-logout-sidebar" onClick={() => logout()}>Teken Uit</button>
        </div>
      </div>

      {/* HOOFINHOUD */}
      <div className="main">
        {/* Top balk met titel en gebruiker-info */}
        <div className="navbar">
          <h3>Verslae</h3>
          <UserProfileHeader />
        </div>

        {/* Verslae-inhoud */}
        <div className="content">
          {/* Plekganger - Verslae-komponent sal hier vervang word */}
          <p>Verslae bladsy - Hier sal die verslae komponent wees.</p>
        </div>
      </div>
    </div>
  );
}

export default ReportsPage;