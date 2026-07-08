import React from 'react';
import { Link } from 'react-router-dom';

function Sidebar({ currentPath, isAdmin, onLogout }) {
  const isActive = (path) => currentPath === path ? { background: '#935e28' } : undefined;

  const isInGroup = (paths) => paths.includes(currentPath) ? { background: '#935e28' } : undefined;

  return (
    <div className="sidebar">
      <h2>FBS</h2>
      <ul>
        <li><Link to="/dashboard" style={isActive('/dashboard')}>Paneelbord</Link></li>
        <li className="dropdown" style={isInGroup(['/assets', '/stock'])}>
          <div className="dropdown-trigger">
            <span>Bates & Voorraad</span>
          </div>
          <div className="dropdown-content">
            <li><Link to="/assets" style={isActive('/assets')}>Bates</Link></li>
            <li><Link to="/stock" style={isActive('/stock')}>Voorraad</Link></li>
          </div>
        </li>
        <li className="dropdown" style={isInGroup(['/rooms', '/buildings', '/terrains'])}>
          <div className="dropdown-trigger">
            <span>Lokale, Geboue & Terreine</span>
          </div>
          <div className="dropdown-content">
            <li><Link to="/rooms" style={isActive('/rooms')}>Lokale</Link></li>
            <li><Link to="/buildings" style={isActive('/buildings')}>Geboue</Link></li>
            <li><Link to="/terrains" style={isActive('/terrains')}>Terreine</Link></li>
          </div>
        </li>
        <li><Link to="/fault-tickets" style={isActive('/fault-tickets')}>Foutkaartjies</Link></li>
        <li><Link to="/work-orders" style={isActive('/work-orders')}>Werksopdragte</Link></li>
        <li><Link to="/contractors" style={isActive('/contractors')}>Kontrakteurs</Link></li>
        <li><Link to="/calendar" style={isActive('/calendar')}>Kalender</Link></li>
        <li><Link to="/predictions" style={isActive('/predictions')}>Voorspellings</Link></li>
        <li><Link to="/reports" style={isActive('/reports')}>Verslae</Link></li>
        {isAdmin && <li><Link to="/users" style={isActive('/users')}>Gebruikers</Link></li>}
      </ul>
      <div className="logout-container">
        <button type="button" className="btn-logout-sidebar" onClick={() => onLogout()}>Teken Uit</button>
      </div>
    </div>
  );
}

export default Sidebar;
