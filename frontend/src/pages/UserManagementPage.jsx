import React from 'react';
import { Routes, Route, Link, useLocation } from 'react-router-dom';
import { useCurrentUser } from '../hooks/useCurrentUser';
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import UserProfileHeader from '../components/UserProfileHeader';
import UsersPage from './UsersPage';
import RolesPage from './RolesPage';
import RightsPage from './RightsPage';

const tabs = [
  { path: '/users/users', label: 'Gebruikers' },
  { path: '/users/roles', label: 'Rolle' },
  { path: '/users/rights', label: 'Regte' },
];

function UserManagementPage() {
  const location = useLocation();
  const { user, loading } = useCurrentUser();
  const logout = useLogout();

  const activeTab = (path) => location.pathname === path ? ' facility-tab active' : '';

  return (
    <div>
      <Sidebar currentPath={location.pathname} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Gebruikers</h3>

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
            <Route path="users" element={<UsersPage embedded />} />
            <Route path="roles" element={<RolesPage embedded />} />
            <Route path="rights" element={<RightsPage embedded />} />
            <Route path="*" element={<UsersPage embedded />} />
          </Routes>
        </div>
      </div>
    </div>
  );
}

export default UserManagementPage;
