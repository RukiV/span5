import React from 'react';
import { Routes, Route, Link, useLocation } from 'react-router-dom';
import { useCurrentUser } from '../hooks/useCurrentUser';
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import UserProfileHeader from '../components/UserProfileHeader';
import AssetPage from './AssetPage';
import StockPage from './StockPage';
import RoomsPage from './RoomsPage';
import BuildingsPage from './BuildingsPage';
import TerrainsPage from './TerrainsPage';

const tabs = [
  { path: '/facilities/assets', label: 'Bates' },
  { path: '/facilities/stock', label: 'Voorraad' },
  { path: '/facilities/rooms', label: 'Lokale' },
  { path: '/facilities/buildings', label: 'Geboue' },
  { path: '/facilities/terrains', label: 'Terreine' },
];

function FacilitiesPage() {
  const location = useLocation();
  const { user, loading } = useCurrentUser();
  const isAdmin = user?.role_id === 3;
  const logout = useLogout();

  const activeTab = (path) => location.pathname === path ? ' facility-tab active' : '';

  return (
    <div>
      <Sidebar currentPath={location.pathname} isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Fasiliteite</h3>

          {loading ? (
            <div className="user-profile-box" style={{ textAlign: 'right', fontSize: '14px', lineHeight: '1.3' }}>
              <div className="user-loading" style={{ color: '#999' }}>Laai profiel...</div>
            </div>
          ) : user ? (
            <UserProfileHeader />
          ) : null}
        </div>

        <div className="facility-tab-bar">
          {tabs.map((tab) => (
            <Link
              key={tab.path}
              to={tab.path}
              className={'facility-tab' + activeTab(tab.path)}
            >
              {tab.label}
            </Link>
          ))}
        </div>

        <div className="content">
          <Routes>
            <Route path="assets" element={<AssetPage embedded />} />
            <Route path="stock" element={<StockPage embedded />} />
            <Route path="rooms" element={<RoomsPage embedded />} />
            <Route path="buildings" element={<BuildingsPage embedded />} />
            <Route path="terrains" element={<TerrainsPage embedded />} />
            <Route path="*" element={<AssetPage embedded />} />
          </Routes>
        </div>
      </div>
    </div>
  );
}

export default FacilitiesPage;
