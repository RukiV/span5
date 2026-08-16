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
import ForgotPasswordPage from './pages/ForgotPasswordPage';
import ResetPasswordPage from './pages/ResetPasswordPage';
import DashboardPage from './pages/DashboardPage';
import TicketPage from './pages/TicketPage';
import WorkOrderPage from './pages/WorkOrderPage';
import PredictionsPage from './pages/PredictionsPage';
import CalendarPage from './pages/CalendarPage';
import ReportsPage from './pages/ReportsPage';
import AssetPage from './pages/AssetPage';
import StockPage from './pages/StockPage';
import RoomsPage from './pages/RoomsPage';
import BuildingsPage from './pages/BuildingsPage';
import TerrainsPage from './pages/TerrainsPage';
import UsersPage from './pages/UsersPage';
import RolesPage from './pages/RolesPage';
import RightsPage from './pages/RightsPage';
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

  const hideAnalytics = ['/users/roles', '/users/rights', '/reports'].some(
    p => location.pathname === p || location.pathname === p + '/'
  );

  useEffect(() => {
    if (hideAnalytics && isOpen) close();
  }, [hideAnalytics, isOpen, close, location.pathname]);

  return (
    <div className="app-body">
      <Sidebar currentPath={location.pathname} onLogout={logout} />
      <div className={`app-content${isOpen && !hideAnalytics ? ' panel-open' : ''}`}>
        <Navbar />
        <div className="main">
          <Routes>
            <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
            <Route path="/assets" element={<RightProtectedRoute requiredRight="assets.view"><AssetPage /></RightProtectedRoute>} />
            <Route path="/stock" element={<RightProtectedRoute requiredRight="stock.view"><StockPage /></RightProtectedRoute>} />
            <Route path="/rooms" element={<RightProtectedRoute requiredRight="rooms.view"><RoomsPage /></RightProtectedRoute>} />
            <Route path="/buildings" element={<RightProtectedRoute requiredRight="buildings.view"><BuildingsPage /></RightProtectedRoute>} />
            <Route path="/terrains" element={<RightProtectedRoute requiredRight="locations.view"><TerrainsPage /></RightProtectedRoute>} />
            <Route path="/fault-tickets" element={<RightProtectedRoute requiredRight="faults.view"><TicketPage /></RightProtectedRoute>} />
            <Route path="/work-orders" element={<RightProtectedRoute requiredRight="jobs.view"><WorkOrderPage /></RightProtectedRoute>} />
            <Route path="/users" element={<RightProtectedRoute requiredRight="users.view"><UsersPage /></RightProtectedRoute>} />
            <Route path="/users/roles" element={<RightProtectedRoute requiredRight="roles.manage"><RolesPage /></RightProtectedRoute>} />
            <Route path="/users/rights" element={<RightProtectedRoute requiredRight="rights.manage"><RightsPage /></RightProtectedRoute>} />
            <Route path="/predictions" element={<RightProtectedRoute requiredRight="predictions.view"><PredictionsPage /></RightProtectedRoute>} />
            <Route path="/calendar" element={<RightProtectedRoute requiredRight="calendar.view"><CalendarPage /></RightProtectedRoute>} />
            <Route path="/reports" element={<RightProtectedRoute requiredRight="reports.view"><ReportsPage /></RightProtectedRoute>} />
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
          <Route path="/forgot-password" element={<ForgotPasswordPage />} />
          <Route path="/reset-password" element={<ResetPasswordPage />} />
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