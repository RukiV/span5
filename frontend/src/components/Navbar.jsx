import React from 'react';
import { useLocation } from 'react-router-dom';
import UserProfileHeader from './UserProfileHeader';
import NotificationBell from './Notifications/NotificationBell';
import '../styles/Navbar.css';

const PATH_TITLES = {
  '/dashboard': 'Paneelbord',
  '/assets': 'Bestuur Bates',
  '/stock': 'Bestuur Voorraad',
  '/rooms': 'Bestuur Lokale',
  '/room-checks-schedules': 'Kontrole Skedules',
  '/buildings': 'Bestuur Geboue',
  '/terrains': 'Bestuur Terreine',
  '/fault-tickets': 'Bestuur Foutkaartjies',
  '/work-orders': 'Bestuur Werksopdragte',
  '/users': 'Bestuur Gebruikers',
  '/users/roles': 'Bestuur Rolle',
  '/users/rights': 'Bestuur Regte',
  '/predictions': 'Voorspellings',
  '/calendar': 'Kalender',
  '/ai-drafts': 'AI-Foutkonsepte',
};

function Navbar() {
  const location = useLocation();

  const title = Object.entries(PATH_TITLES).reduce((acc, [path, label]) => {
    if (location.pathname === path || location.pathname.startsWith(path + '/')) return label;
    return acc;
  }, 'FBS');

  return (
    <div className="navbar">
      <h3>{title}</h3>
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <NotificationBell />
        <UserProfileHeader />
      </div>
    </div>
  );
}

export default Navbar;
