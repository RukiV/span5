import React from 'react';
import { Link } from 'react-router-dom';
import '../styles/App.css';
import '../styles/Calendar.css';

function CalendarPage() {
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
          {/* Markeer huidige blad as aktief met bruin agtergrond */}
          <li><Link to="/calendar" style={{ background: '#935e28' }}>Kalender</Link></li>
          <li><Link to="/analysis">Analise</Link></li>
          <li><Link to="/reports">Verslae</Link></li>
          <li><Link to="/reporting">Rapportering</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
        </ul>
        <div className="logout-container">
          <Link to="/login" className="btn-logout-sidebar">Logout</Link>
        </div>
      </div>

      {/* HOOFINHOUD */}
      <div className="main">
        {/* Top balk met titel en gebruiker-info */}
        <div className="navbar">
          <h3>Kalender</h3>
          <div className="user">Admin</div>
        </div>

        {/* Kalender-inhoud */}
        <div className="content">
          {/* Plekganger - Kalender-komponent sal hier vervang word */}
          <p>Kalender bladsy - Hier sal die kalender komponent wees.</p>
        </div>
      </div>
    </div>
  );
}

export default CalendarPage;