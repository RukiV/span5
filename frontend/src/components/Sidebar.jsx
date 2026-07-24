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
  const isInGroup = (paths) => (paths.includes(currentPath) || paths.some(p => currentPath.startsWith(p + '/'))) ? { background: '#935e28' } : undefined;

  const showAssets = can('assets.manage');
  const showStock = can('stock.manage');
  const showRooms = can('rooms.manage');
  const showBuildings = can('buildings.manage');
  const showTerrains = can('locations.manage');
  const showFacilities = showAssets || showStock || showRooms || showBuildings || showTerrains;

  return (
    <div className="sidebar">
      <h2>FBS</h2>
      <ul>
        <li><Link to="/dashboard" style={isActive('/dashboard')}>Paneelbord</Link></li>

        {showFacilities && (
          <li className="dropdown" style={isInGroup(['/facilities'])}>
            <div className="dropdown-trigger">
              <span>Fasiliteite</span>
            </div>
            <div className="dropdown-content2">
              {showAssets && <li><Link to="/facilities/assets" style={isActive('/facilities/assets')}>Bates</Link></li>}
              {showStock && <li><Link to="/facilities/stock" style={isActive('/facilities/stock')}>Voorraad</Link></li>}
              {showRooms && <li><Link to="/facilities/rooms" style={isActive('/facilities/rooms')}>Lokale</Link></li>}
              {showBuildings && <li><Link to="/facilities/buildings" style={isActive('/facilities/buildings')}>Geboue</Link></li>}
              {showTerrains && <li><Link to="/facilities/terrains" style={isActive('/facilities/terrains')}>Terreine</Link></li>}
            </div>
          </li>
        )}

        {can('faults.manage_all') && <li><Link to="/fault-tickets" style={isActive('/fault-tickets')}>Foutkaartjies</Link></li>}
        {can('jobs.manage') && <li><Link to="/work-orders" style={isActive('/work-orders')}>Werksopdragte</Link></li>}
        {can('calendar.view') && <li><Link to="/calendar" style={isActive('/calendar')}>Kalender</Link></li>}
        {can('predictions.view') && <li><Link to="/predictions" style={isActive('/predictions')}>Voorspellings</Link></li>}
        {can('reports.view') && <li><Link to="/reports" style={isActive('/reports')}>Verslae</Link></li>}
        {can('users.manage') && (
          <li className="dropdown" style={isInGroup(['/users'])}>
            <div className="dropdown-trigger">
              <span>Gebruikers</span>
            </div>
            <div className="dropdown-content">
              <li><Link to="/users/users" style={isActive('/users/users')}>Gebruikers</Link></li>
              <li><Link to="/users/roles" style={isActive('/users/roles')}>Rolle</Link></li>
              <li><Link to="/users/rights" style={isActive('/users/rights')}>Regte</Link></li>
            </div>
          </li>
        )}
      </ul>
      <div className="logout-container">
        <button type="button" className="btn-logout-sidebar" onClick={() => onLogout()}>Teken Uit</button>
      </div>
    </div>
  );
}

export default Sidebar;
