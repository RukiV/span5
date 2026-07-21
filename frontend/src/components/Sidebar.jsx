import React from 'react';
import { Link } from 'react-router-dom';
import { useCurrentUser } from '../hooks/useCurrentUser';

// Sidebar filter menu-items op die gebruiker se regte (vanaf /auth/me), nie meer
// op 'n enkele hardgekodeerde isAdmin-boolean nie. So bepaal 'n
// permissie-verandering aan die agterkant onmiddellik wat sigbaar is, sonder 'n
// herbou. (Die `isAdmin`-prop word aanvaar maar geïgnoreer vir agteruit-
// verenigbaarheid met bladsye wat dit steeds deurgee.)
function Sidebar({ currentPath, onLogout }) {
  const { rights } = useCurrentUser();
  const can = (right) => (rights || []).includes(right);

  const isActive = (path) => currentPath === path ? { background: '#935e28' } : undefined;
  const isInGroup = (paths) => paths.includes(currentPath) ? { background: '#935e28' } : undefined;

  const showAssets = can('assets.manage');
  const showStock = can('stock.manage');
  const showRooms = can('rooms.manage');
  const showBuildings = can('buildings.manage');
  const showTerrains = can('locations.manage');

  return (
    <div className="sidebar">
      <h2>FBS</h2>
      <ul>
        <li><Link to="/dashboard" style={isActive('/dashboard')}>Paneelbord</Link></li>

        {(showAssets || showStock) && (
          <li className="dropdown" style={isInGroup(['/assets', '/stock'])}>
            <div className="dropdown-trigger">
              <span>Bates & Voorraad</span>
            </div>
            <div className="dropdown-content2">
              {showAssets && <li><Link to="/assets" style={isActive('/assets')}>Bates</Link></li>}
              {showStock && <li><Link to="/stock" style={isActive('/stock')}>Voorraad</Link></li>}
            </div>
          </li>
        )}

        {(showRooms || showBuildings || showTerrains) && (
          <li className="dropdown" style={isInGroup(['/rooms', '/buildings', '/terrains'])}>
            <div className="dropdown-trigger">
              <span>Lokale, Geboue & Terreine</span>
            </div>
            <div className="dropdown-content">
              {showRooms && <li><Link to="/rooms" style={isActive('/rooms')}>Lokale</Link></li>}
              {showBuildings && <li><Link to="/buildings" style={isActive('/buildings')}>Geboue</Link></li>}
              {showTerrains && <li><Link to="/terrains" style={isActive('/terrains')}>Terreine</Link></li>}
            </div>
          </li>
        )}

        {can('faults.manage_all') && <li><Link to="/fault-tickets" style={isActive('/fault-tickets')}>Foutkaartjies</Link></li>}
        {can('jobs.manage') && <li><Link to="/work-orders" style={isActive('/work-orders')}>Werksopdragte</Link></li>}
        {can('contractors.manage') && <li><Link to="/contractors" style={isActive('/contractors')}>Kontrakteurs</Link></li>}
        {can('calendar.view') && <li><Link to="/calendar" style={isActive('/calendar')}>Kalender</Link></li>}
        {can('predictions.view') && <li><Link to="/predictions" style={isActive('/predictions')}>Voorspellings</Link></li>}
        {can('reports.view') && <li><Link to="/reports" style={isActive('/reports')}>Verslae</Link></li>}
        {can('users.manage') && <li><Link to="/users" style={isActive('/users')}>Gebruikers</Link></li>}
      </ul>
      <div className="logout-container">
        <button type="button" className="btn-logout-sidebar" onClick={() => onLogout()}>Teken Uit</button>
      </div>
    </div>
  );
}

export default Sidebar;
