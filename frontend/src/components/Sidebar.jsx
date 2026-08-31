import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { useCurrentUser } from '../hooks/useCurrentUser';
import {
  IoGridOutline, IoBusinessOutline, IoCubeOutline, IoConstructOutline,
  IoMapOutline, IoLocationOutline, IoWarningOutline, IoDocumentTextOutline,
  IoCalendarOutline, IoBarChartOutline, IoPeopleOutline,
  IoShieldOutline, IoKeyOutline, IoLogOutOutline, IoCheckboxOutline,
} from "react-icons/io5";

function Sidebar({ currentPath, onLogout }) {
  const { rights } = useCurrentUser();
  const can = (right) => (rights || []).includes(right);
  const [openFacilities, setOpenFacilities] = useState(false);
  const [openUsers, setOpenUsers] = useState(false);

  const isActive = (path) => currentPath === path ? 'active-link' : '';
  const isInGroup = (paths) => (paths.includes(currentPath) || paths.some(p => currentPath.startsWith(p + '/'))) ? 'active-link' : '';

  const ic = { marginRight: 8, verticalAlign: 'middle' };

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
        <li><Link to="/dashboard" className={isActive('/dashboard')}><IoGridOutline style={ic} />Paneelbord</Link></li>

        {showFacilities && (
          <li className={`dropdown ${openFacilities ? 'open' : ''}`}>
            <span
              className={`dropdown-trigger ${isInGroup(['/assets', '/stock', '/rooms', '/buildings', '/terrains'])}`}
              onClick={() => setOpenFacilities((o) => !o)}
            >
              <span><IoBusinessOutline style={ic} />Fasiliteite</span>
            </span>
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
        {can('jobs.manage') && <li><Link to="/work-orders" className={isInGroup(['/work-orders', '/ai-drafts'])}><IoDocumentTextOutline style={ic} />Werksopdragte</Link></li>}
        {can('room_checks.manage') && <li><Link to="/room-checks-schedules" className={isActive('/room-checks-schedules')}><IoCheckboxOutline style={ic} />Kontrole Skedules</Link></li>}
        {can('calendar.view') && <li><Link to="/calendar" className={isActive('/calendar')}><IoCalendarOutline style={ic} />Kalender</Link></li>}
        {can('predictions.view') && <li><Link to="/predictions" className={isActive('/predictions')}><IoBarChartOutline style={ic} />Voorspellings</Link></li>}
        {can('users.manage') && (
          <li className={`dropdown ${openUsers ? 'open' : ''}`}>
            <span
              className={`dropdown-trigger ${isInGroup(['/users', '/users/roles', '/users/rights'])}`}
              onClick={() => setOpenUsers((o) => !o)}
            >
              <span><IoPeopleOutline style={ic} />Gebruikers</span>
            </span>
            <div className="dropdown-content">
              <li><Link to="/users" className={isActive('/users')}><IoPeopleOutline style={ic} />Gebruikers</Link></li>
              <li><Link to="/users/roles" className={isActive('/users/roles')}><IoShieldOutline style={ic} />Rolle</Link></li>
              <li><Link to="/users/rights" className={isActive('/users/rights')}><IoKeyOutline style={ic} />Regte</Link></li>
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
