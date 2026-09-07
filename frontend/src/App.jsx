import React, { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import './styles/App.css';
import './logoutInterceptor';
import { clearAuthSession, isSessionExpired, markUserActivity } from './authSession';
import { useCurrentUser } from './hooks/useCurrentUser';
import { AnalyticsProvider, useAnalytics } from './context/AnalyticsContext';
import { IoEyeOutline, IoEyeOffOutline } from 'react-icons/io5';
import Navbar from './components/Navbar';
import Sidebar from './components/Sidebar';
import DragHandle from './components/DragHandle';
import AnalyticsPanel from './components/AnalyticsPanel';
import { useLogout } from './pages/Page';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import TicketPage from './pages/TicketPage';
import JobTabs from './components/JobTabs';
import WorkOrderPage from './pages/WorkOrderPage';
import PredictionsPage from './pages/PredictionsPage';
import CalendarPage from './pages/CalendarPage';
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
   Sidebar + Navbar + (Content || Content + AnalyticsPanel).
   ========================================================= */
function AppContent() {
  const location = useLocation();
  const logout = useLogout();
  const { isOpen, toggle, close } = useAnalytics();

  const hideAnalytics = ['/users/roles', '/users/rights'].some(
    p => location.pathname === p || location.pathname === p + '/'
  );

  useEffect(() => {
    if (hideAnalytics && isOpen) close();
  }, [hideAnalytics, isOpen, close, location.pathname]);

  // Position the analytics panel below the navbar + controls so the
  // controls bar never moves/shifts when the panel toggles. Only the
  // panel's top offset is updated — controls CSS stays untouched.
  useEffect(() => {
    const updatePanelTop = () => {
      const navbar = document.querySelector('.navbar');
      const navbarH = navbar ? navbar.offsetHeight : 0;
      // Controls is the first sticky bar inside .main; may be absent on /dashboard etc.
      const controls = document.querySelector('.main .controls--sticky');
      const tabs = document.querySelector('.main .fault-tabs');
      let headerH = navbarH;
      if (tabs && controls) {
        // When both exist, tabs sits above controls (tabs top 0, controls top 42px)
        // Combined height is tabs + controls. Use bounding rect bottom of controls.
        const controlsBottom = controls.getBoundingClientRect().bottom;
        const navbarTop = navbar ? navbar.getBoundingClientRect().top : 0;
        headerH = Math.round(controlsBottom - navbarTop);
      } else if (controls) {
        const controlsBottom = controls.getBoundingClientRect().bottom;
        const navbarTop = navbar ? navbar.getBoundingClientRect().top : 0;
        // If controls is visible, its bottom relative to viewport top gives total header
        // but when scrolled it may be sticky; use offsetHeight fallback if bottom is too large
        // Prefer measuring offsetHeight + navbarH for initial load
        if (controlsBottom > 0 && controlsBottom < 400) {
          headerH = Math.round(controlsBottom - navbarTop);
        } else {
          headerH = navbarH + controls.offsetHeight + 16; // 16 = margin-bottom
        }
      } else if (tabs) {
        headerH = navbarH + tabs.offsetHeight;
      } else {
        headerH = navbarH + 8; // small gap when no controls
      }
      // Clamp to sensible range
      headerH = Math.max(navbarH, Math.min(headerH, 300));
      document.documentElement.style.setProperty('--analytics-panel-top', `${headerH}px`);
    };

    updatePanelTop();
    // Re-measure on route change, resize, and when main content mutates (controls mounts late)
    window.addEventListener('resize', updatePanelTop);
    const ro = new ResizeObserver(updatePanelTop);
    const navbarEl = document.querySelector('.navbar');
    const mainEl = document.querySelector('.main');
    if (navbarEl) ro.observe(navbarEl);
    if (mainEl) ro.observe(mainEl);
    // Also observe controls if it exists now; poll for late mount
    const interval = setInterval(updatePanelTop, 500);
    const timeout = setTimeout(() => clearInterval(interval), 5000);

    return () => {
      window.removeEventListener('resize', updatePanelTop);
      ro.disconnect();
      clearInterval(interval);
      clearTimeout(timeout);
    };
  }, [location.pathname, isOpen]);

  return (
    <div className="app-body">
      <Sidebar currentPath={location.pathname} onLogout={logout} />
      <div className={`app-content${isOpen && !hideAnalytics ? ' panel-open' : ''}`}>
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
            <Route path="/predictions" element={<RightProtectedRoute requiredRight="predictions.view"><PredictionsPage /></RightProtectedRoute>} />
            <Route path="/calendar" element={<RightProtectedRoute requiredRight="calendar.view"><CalendarPage /></RightProtectedRoute>} />
            <Route path="/ai-drafts" element={<RightProtectedRoute requiredRight="ai.approve"><JobTabs><AIDraftQueuePage /></JobTabs></RightProtectedRoute>} />
            <Route path="/ai-drafts/new" element={<RightProtectedRoute requiredRight="ai.use"><JobTabs><AIDraftNewPage /></JobTabs></RightProtectedRoute>} />
            <Route path="/ai-drafts/:id" element={<RightProtectedRoute requiredRight="ai.approve"><JobTabs><AIDraftDetailPage /></JobTabs></RightProtectedRoute>} />
            <Route path="/" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
            <Route path="*" element={<Navigate to="/login" replace />} />
          </Routes>
        </div>
        {!hideAnalytics && <DragHandle />}
        {!hideAnalytics && <AnalyticsPanel />}
        </div>
        {!hideAnalytics && (
          <button className="analytics-fab" onClick={toggle} title="Analitiese Paneel">
            {isOpen ? <IoEyeOffOutline size={22} /> : <IoEyeOutline size={22} />}
          </button>
        )}
      </div>
  );
}

/* =========================================================
   2. JOU OPGBEDATEERDE APP-ROETES EN DOCKER KONTROLE
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
      <div className="app">
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/*" element={
            <AnalyticsProvider>
              <ToastProvider>
                <NotificationProvider>
                  <AppContent />
                </NotificationProvider>
              </ToastProvider>
            </AnalyticsProvider>
          } />
        </Routes>
      </div>
    </Router>
  );
}

export default App;