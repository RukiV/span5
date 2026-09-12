import React, { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import './styles/App.css';
import './logoutInterceptor';
import { clearAuthSession, isSessionExpired, markUserActivity } from './authSession';
import { useCurrentUser } from './hooks/useCurrentUser';
import Navbar from './components/Navbar';
import Sidebar from './components/Sidebar';
import { useLogout } from './pages/Page';
import LoginPage from './pages/LoginPage';
import DownloadPage from './pages/DownloadPage';
import DashboardPage from './pages/DashboardPage';
import TicketPage from './pages/TicketPage';
import JobTabs from './components/JobTabs';
import WorkOrderPage from './pages/WorkOrderPage';
import AssetPage from './pages/AssetPage';
import StockPage from './pages/StockPage';
import RoomsPage from './pages/RoomsPage';
import RoomCheckSessionsPage from './pages/RoomCheckSessionsPage';
import BuildingsPage from './pages/BuildingsPage';
import TerrainsPage from './pages/TerrainsPage';
import UsersPage from './pages/UsersPage';
import RolesPage from './pages/RolesPage';
import RightsPage from './pages/RightsPage';
import AIDraftQueuePage from './pages/AIDraftQueuePage';
import AIDraftNewPage from './pages/AIDraftNewPage';
import AIDraftDetailPage from './pages/AIDraftDetailPage';
import { ToastProvider } from './components/Toast/ToastContext';
import { NotificationProvider } from './components/Notifications/NotificationContext';

// Voorspellings-blad word net gelaai wanneer die gebruiker dit oopmaak
// (grafieke/Chart.js word apart gebundel en nie by die hoofkelder gevoeg nie).
const PredictionsPage = React.lazy(() => import('./pages/PredictionsPage'));

/* =========================================================
    1. DIE BESKERMDE ROETE-MEGANISME
   ========================================================= */
function ProtectedRoute({ children }) {
  const token = sessionStorage.getItem('token');
  const isLoggingOut = sessionStorage.getItem('isLoggingOut');

  if (!token || isLoggingOut || isSessionExpired()) {
    sessionStorage.removeItem('isLoggingOut');
    clearAuthSession();
    return <Navigate to="/login" replace />;
  }

  // As daar 'n token is, laai die bladsy normaalweg
  return children;
}

/* =========================================================
   1b. REGTE-GEBASEERDE ROETE-BESKERMING
   Draai die token-kontrole (ProtectedRoute) in EN kontroleer boonop
   dat die gebruiker die vereiste reg het (gelees vanaf /auth/me se
   `rights`-lys). Nie-gemagtigde rolle word na die paneelbord gestuur.
   ========================================================= */
function RightProtectedRoute({ requiredRight, children }) {
  const token = sessionStorage.getItem('token');
  const isLoggingOut = sessionStorage.getItem('isLoggingOut');
  const { loading, error, rights } = useCurrentUser();

  // Eers dieselfde token-kontrole as ProtectedRoute
  if (!token || isLoggingOut || isSessionExpired()) {
    sessionStorage.removeItem('isLoggingOut');
    clearAuthSession();
    return <Navigate to="/login" replace />;
  }

  // Wag totdat /auth/me klaar gelaai het voordat ons besluit
  if (loading) return null;
  if (error) return <Navigate to="/login" replace />;

  // Regte-kontrole: geen reg -> terug na paneelbord
  if (requiredRight && !rights.includes(requiredRight)) {
    return <Navigate to="/dashboard" replace />;
  }

  return children;
}

/* =========================================================
   1c. LAYOUT-VERPAKKER
   Wrappies elke beskermde bladsy in die nuwe layout:
   Sidebar + Navbar + Content.
   ========================================================= */
function AppContent() {
  const location = useLocation();
  const logout = useLogout();

  return (
    <div className="app-body">
      <Sidebar currentPath={location.pathname} onLogout={logout} />
      <div className="app-content">
        <Navbar />
        <div className="main">
          <Routes>
            <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
            <Route path="/assets" element={<RightProtectedRoute requiredRight="assets.manage"><AssetPage /></RightProtectedRoute>} />
            <Route path="/stock" element={<RightProtectedRoute requiredRight="stock.manage"><StockPage /></RightProtectedRoute>} />
            <Route path="/rooms" element={<RightProtectedRoute requiredRight="rooms.manage"><RoomsPage /></RightProtectedRoute>} />
            <Route path="/room-checks-schedules" element={<RightProtectedRoute requiredRight="room_checks.manage"><RoomCheckSessionsPage /></RightProtectedRoute>} />
            <Route path="/buildings" element={<RightProtectedRoute requiredRight="buildings.manage"><BuildingsPage /></RightProtectedRoute>} />
            <Route path="/terrains" element={<RightProtectedRoute requiredRight="locations.manage"><TerrainsPage /></RightProtectedRoute>} />
            <Route path="/fault-tickets" element={<RightProtectedRoute requiredRight="faults.view"><TicketPage /></RightProtectedRoute>} />
            <Route path="/work-orders" element={<RightProtectedRoute requiredRight="jobs.manage"><JobTabs><WorkOrderPage /></JobTabs></RightProtectedRoute>} />
            <Route path="/users" element={<RightProtectedRoute requiredRight="users.manage"><UsersPage /></RightProtectedRoute>} />
            <Route path="/users/roles" element={<RightProtectedRoute requiredRight="users.manage"><RolesPage /></RightProtectedRoute>} />
            <Route path="/users/rights" element={<RightProtectedRoute requiredRight="users.manage"><RightsPage /></RightProtectedRoute>} />
            <Route path="/predictions" element={<RightProtectedRoute requiredRight="predictions.view"><React.Suspense fallback={<div className="main"><div className="content">Laai voorspellings...</div></div>}><PredictionsPage /></React.Suspense></RightProtectedRoute>} />
            <Route path="/ai-drafts" element={<RightProtectedRoute requiredRight="ai.approve"><JobTabs><AIDraftQueuePage /></JobTabs></RightProtectedRoute>} />
            <Route path="/ai-drafts/new" element={<RightProtectedRoute requiredRight="ai.use"><JobTabs><AIDraftNewPage /></JobTabs></RightProtectedRoute>} />
            <Route path="/ai-drafts/:id" element={<RightProtectedRoute requiredRight="ai.approve"><JobTabs><AIDraftDetailPage /></JobTabs></RightProtectedRoute>} />
            <Route path="/" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
            <Route path="*" element={<Navigate to="/login" replace />} />
          </Routes>
        </div>
      </div>
    </div>
  );
}

/* =========================================================
   2. APP-DOP MET LOGIN-AGTERGROND
   Die agtergrond sit op .app-vlak (nie op die login-blad self nie),
   sodat dit die hele bladsy vul. Slegs op /login aktief.
   ========================================================= */
function AppShell() {
  const location = useLocation();
  const isLogin = location.pathname === '/login';
  return (
    <div className={isLogin ? 'app app-login' : 'app'}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/download" element={<DownloadPage />} />
        <Route path="/*" element={
          <ToastProvider>
            <NotificationProvider>
              <AppContent />
            </NotificationProvider>
          </ToastProvider>
        } />
      </Routes>
    </div>
  );
}

/* =========================================================
   3. JOU OPGBEDATEERDE APP-ROETES EN DOCKER KONTROLE
   ========================================================= */
function App() {
  useEffect(() => {
    markUserActivity();

    const timeout = window.setTimeout(() => {
      if (sessionStorage.getItem('token')) {
        clearAuthSession();
        window.location.replace(window.location.origin + '/login');
      }
    }, 30 * 60 * 1000);

    return () => window.clearTimeout(timeout);
  }, []);

  // KONTROLEER OF DOCKER HERSTART HET
  useEffect(() => {
    // 1. Gryp die Build ID wat Docker ingespuit het (val terug op versteknaam in dev)
    const currentBuildId = process.env.REACT_APP_BUILD_ID || "development_build";
    
    // 2. Gryp die Build ID van die blaaier se vorige aktiewe sessie
    const savedBuildId = localStorage.getItem('active_build_id');

    // 3. As daar 'n ou ID gestoor is, maar dit pas nie by die nuwe een nie -> Omgewing het herbegin!
    if (savedBuildId && savedBuildId !== currentBuildId) {
      console.warn("Docker-omgewing het herbegin. Ou sessies en tokens word skoongemaak...");
      
      // Vee alle vorige sessie data, Microsoft- en App-tokens uit
      sessionStorage.clear();
      localStorage.clear();
      
      // Stoor die nuwe ID sodat hy nie weer in 'n lus bly uitlog nie
      localStorage.setItem('active_build_id', currentBuildId);
      
      // Dwing die blaaier om die Login-skerm skoon te laai
      window.location.replace('/login');
    } else {
      // As dit die eerste keer laai of die ID ooreenstem, stoor net die huidige een
      localStorage.setItem('active_build_id', currentBuildId);
    }
  }, []);

  return (
    <Router>
      <AppShell />
    </Router>
  );
}

export default App;