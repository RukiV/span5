import React, { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import './styles/App.css';
import './logoutInterceptor';
import { clearAuthSession, isSessionExpired, markUserActivity } from './authSession';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import AssetPage from './pages/AssetPage';
import StockPage from './pages/StockPage';
import TicketPage from './pages/TicketPage';
import WorkOrderPage from './pages/WorkOrderPage';
import UsersPage from './pages/UsersPage';
import AnalysisPage from './pages/AnalysisPage';
import CalendarPage from './pages/CalendarPage';
import RoomsPage from './pages/RoomsPage';
import TerrainsPage from './pages/TerrainsPage';
import ContractorsPage from './pages/ContractorsPage';
import ReportsPage from './pages/ReportsPage';

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

        {/* Beskermde roetes (Toegedraai in <ProtectedRoute>) */}
        <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
        <Route path="/assets" element={<ProtectedRoute><AssetPage /></ProtectedRoute>} />
        <Route path="/stock" element={<ProtectedRoute><StockPage /></ProtectedRoute>} />
        <Route path="/fault-tickets" element={<ProtectedRoute><TicketPage /></ProtectedRoute>} />
        <Route path="/work-orders" element={<ProtectedRoute><WorkOrderPage /></ProtectedRoute>} />
        <Route path="/contractors" element={<ProtectedRoute><ContractorsPage /></ProtectedRoute>} />
        <Route path="/users" element={<ProtectedRoute><UsersPage /></ProtectedRoute>} />
        <Route path="/analysis" element={<ProtectedRoute><AnalysisPage /></ProtectedRoute>} />
        <Route path="/calendar" element={<ProtectedRoute><CalendarPage /></ProtectedRoute>} />
        <Route path="/rooms" element={<ProtectedRoute><RoomsPage /></ProtectedRoute>} />
        <Route path="/terrains" element={<ProtectedRoute><TerrainsPage /></ProtectedRoute>} />
        <Route path="/reports" element={<ProtectedRoute><ReportsPage /></ProtectedRoute>} />
        
        {/* As die gebruiker op "/" land, stuur hulle outomaties na die dashboard via ProtectedRoute */}
        <Route path="/" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />

        {/* Wildcard: As 'n URL nie bestaan nie, stuur hulle altyd terug na login */}
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </Router>
  );
}

export default App;