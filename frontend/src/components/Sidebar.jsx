import React from 'react';
import { Link } from 'react-router-dom';
import { useCurrentUser } from '../hooks/useCurrentUser';
import {
  IoGridOutline, IoBusinessOutline, IoCubeOutline, IoConstructOutline,
  IoMapOutline, IoLocationOutline, IoWarningOutline, IoDocumentTextOutline,
  IoCalendarOutline, IoBarChartOutline, IoDocumentsOutline, IoPeopleOutline,
  IoShieldOutline, IoKeyOutline, IoLogOutOutline,
} from "react-icons/io5";

function Sidebar({ currentPath, onLogout }) {
  const { rights } = useCurrentUser();
  const can = (right) => (rights || []).includes(right);

  const isActive = (path) => currentPath === path ? 'active-link' : '';
  const isInGroup = (paths) => (paths.includes(currentPath) || paths.some(p => currentPath.startsWith(p + '/'))) ? 'active-link' : '';

  const ic = { marginRight: 8, verticalAlign: 'middle' };

  const showAssets = can('assets.view');
  const showStock = can('stock.view');
  const showRooms = can('rooms.view');
  const showBuildings = can('buildings.view');
  const showTerrains = can('locations.view');
  const showFacilities = showAssets || showStock || showRooms || showBuildings || showTerrains;
  const firstFacilityPath = showAssets ? '/assets'
    : showStock ? '/stock'
    : showRooms ? '/rooms'
    : showBuildings ? '/buildings'
    : '/terrains';

  const canUsers = can('users.view');
  const canRoles = can('roles.manage');
  const canRights = can('rights.manage');
  const showUsersGroup = canUsers || canRoles || canRights;
  const firstUsersPath = canUsers ? '/users' : canRoles ? '/users/roles' : '/users/rights';

  return (
    <div className="sidebar">
      <h2>FBS</h2>
      <ul>
        <li><Link to="/dashboard" className={isActive('/dashboard')}><IoGridOutline style={ic} />Paneelbord</Link></li>

        {showFacilities && (
          <li className="dropdown">
            <Link to={firstFacilityPath} className={`dropdown-trigger ${isInGroup(['/assets', '/stock', '/rooms', '/buildings', '/terrains'])}`}>
              <span><IoBusinessOutline style={ic} />Fasiliteite</span>
            </Link>
            <div className="dropdown-content2">
              {showAssets && <li><Link to="/assets" className={isActive('/assets')}><IoCubeOutline style={ic} />Bates</Link></li>}
              {showStock && <li><Link to="/stock" className={isActive('/stock')}><IoConstructOutline style={ic} />Voorraad</Link></li>}
              {showRooms && <li><Link to="/rooms" className={isActive('/rooms')}><IoLocationOutline style={ic} />Lokale</Link></li>}
              {showBuildings && <li><Link to="/buildings" className={isActive('/buildings')}><IoBusinessOutline style={ic} />Geboue</Link></li>}
              {showTerrains && <li><Link to="/terrains" className={isActive('/terrains')}><IoMapOutline style={ic} />Terreine</Link></li>}
            </div>
          </li>
        )}

        {can('faults.view') && <li><Link to="/fault-tickets" className={isActive('/fault-tickets')}><IoWarningOutline style={ic} />Foutkaartjies</Link></li>}
        {can('jobs.view') && <li><Link to="/work-orders" className={isActive('/work-orders')}><IoDocumentTextOutline style={ic} />Werksopdragte</Link></li>}
        {can('calendar.view') && <li><Link to="/calendar" className={isActive('/calendar')}><IoCalendarOutline style={ic} />Kalender</Link></li>}
        {can('predictions.view') && <li><Link to="/predictions" className={isActive('/predictions')}><IoBarChartOutline style={ic} />Voorspellings</Link></li>}
        {can('reports.view') && <li><Link to="/reports" className={isActive('/reports')}><IoDocumentsOutline style={ic} />Verslae</Link></li>}
        {showUsersGroup && (
          <li className="dropdown">
            <Link to={firstUsersPath} className={`dropdown-trigger ${isInGroup(['/users', '/users/roles', '/users/rights'])}`}>
              <span><IoPeopleOutline style={ic} />Gebruikers</span>
            </Link>
            <div className="dropdown-content">
              {canUsers && <li><Link to="/users" className={isActive('/users')}><IoPeopleOutline style={ic} />Gebruikers</Link></li>}
              {canRoles && <li><Link to="/users/roles" className={isActive('/users/roles')}><IoShieldOutline style={ic} />Rolle</Link></li>}
              {canRights && <li><Link to="/users/rights" className={isActive('/users/rights')}><IoKeyOutline style={ic} />Regte</Link></li>}
            </div>
          </li>
        )}
      </ul>
      <div className="logout-container">
        <button type="button" className="btn-logout-sidebar" onClick={() => onLogout()}><IoLogOutOutline style={{ marginRight: 8, verticalAlign: 'middle' }} />Teken Uit</button>
      </div>
    </div>
  );
}

export default Sidebar;