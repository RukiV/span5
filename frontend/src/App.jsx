import React, { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import './styles/App.css';
import './logoutInterceptor';
import { clearAuthSession, isSessionExpired, markUserActivity } from './authSession';
import { useCurrentUser } from './hooks/useCurrentUser';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import TicketPage from './pages/TicketPage';
import WorkOrderPage from './pages/WorkOrderPage';
import UsersPage from './pages/UsersPage';
import PredictionsPage from './pages/PredictionsPage';
import CalendarPage from './pages/CalendarPage';
import ContractorsPage from './pages/ContractorsPage';
import ReportsPage from './pages/ReportsPage';
// Bates/Voorraad/Lokale/Geboue/Terreine word nou binne FacilitiesPage gehanteer.
import FacilitiesPage from './pages/FacilitiesPage';

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
      <Routes>
        {/* Openbare roete (Geen beskerming nodig nie) */}
        <Route path="/login" element={<LoginPage />} />

        {/* Beskermde roetes.
            Paneelbord is toeganklik vir enige web-gemagtigde gebruiker (net
            Admin/FK kan by die web aanmeld). Elke ander bladsy vereis sy
            spesifieke reg via <RightProtectedRoute>. FK het alles behalwe
            users.manage, so FK sien alles behalwe /users. */}
        <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
        {/* Bates/Voorraad/Lokale/Geboue/Terreine is nou een geneste bladsy
            (FacilitiesPage). Granulêre regte word deur die agterkant
            (require_right op elke roete) en die regte-gedrewe Sidebar afgedwing,
            so vereis hierdie roete net 'n geldige web-sessie. Ou skakels herlei. */}
        <Route path="/facilities/*" element={<ProtectedRoute><FacilitiesPage /></ProtectedRoute>} />
        <Route path="/assets" element={<Navigate to="/facilities/assets" replace />} />
        <Route path="/stock" element={<Navigate to="/facilities/stock" replace />} />
        <Route path="/rooms" element={<Navigate to="/facilities/rooms" replace />} />
        <Route path="/buildings" element={<Navigate to="/facilities/buildings" replace />} />
        <Route path="/terrains" element={<Navigate to="/facilities/terrains" replace />} />

        {/* Losstaande bladsye behou hul granulêre reg-kontrole. */}
        <Route path="/fault-tickets" element={<RightProtectedRoute requiredRight="faults.manage_all"><TicketPage /></RightProtectedRoute>} />
        <Route path="/work-orders" element={<RightProtectedRoute requiredRight="jobs.manage"><WorkOrderPage /></RightProtectedRoute>} />
        <Route path="/contractors" element={<RightProtectedRoute requiredRight="contractors.manage"><ContractorsPage /></RightProtectedRoute>} />
        <Route path="/users" element={<RightProtectedRoute requiredRight="users.manage"><UsersPage /></RightProtectedRoute>} />
        <Route path="/predictions" element={<RightProtectedRoute requiredRight="predictions.view"><PredictionsPage /></RightProtectedRoute>} />
        <Route path="/calendar" element={<RightProtectedRoute requiredRight="calendar.view"><CalendarPage /></RightProtectedRoute>} />
        <Route path="/reports" element={<RightProtectedRoute requiredRight="reports.view"><ReportsPage /></RightProtectedRoute>} />


        {/* As die gebruiker op "/" land, stuur hulle outomaties na die dashboard via ProtectedRoute */}
        <Route path="/" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />

        {/* Wildcard: As 'n URL nie bestaan nie, stuur hulle altyd terug na login */}
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </Router>
  );
}

export default App;