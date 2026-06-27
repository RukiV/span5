import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import './styles/App.css';
import './logoutInterceptor';
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
import ReportsPage from './pages/ReportsPage';

/* =========================================================
   1. DIE BESKERMDE ROETE-MEGANISME
   ========================================================= */
function ProtectedRoute({ children }) {
  // Kyk na token - elke keer wanneer hierdie komponent render, so dit is altyd up-to-date
  const token = sessionStorage.getItem('token');
  const isLoggingOut = sessionStorage.getItem('isLoggingOut');

  // As daar geen token is nie, of as logout flag gesit is, stuur die gebruiker dadelik terug na login
  // 'replace' sorg dat hulle nie met die "Back"-knoppie kan terugkom nie
  if (!token || isLoggingOut) {
    // Clear the logout flag so we don't get stuck
    sessionStorage.removeItem('isLoggingOut');
    return <Navigate to="/login" replace />;
  }

  // As daar 'n token is, laai die bladsy normaalweg
  return children;
}

/* =========================================================
   2. JOU OPGBEDATEERDE APP-ROETES
   ========================================================= */
function App() {
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