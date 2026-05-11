import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import './styles/App.css';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import AssetPage from './pages/AssetPage';
import TicketPage from './pages/TicketPage';
import WorkOrderPage from './pages/WorkOrderPage';
import UsersPage from './pages/UsersPage';
import AnalysisPage from './pages/AnalysisPage';
import CalendarPage from './pages/CalendarPage';
import RoomsPage from './pages/RoomsPage';
import ReportsPage from './pages/ReportsPage';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/assets" element={<AssetPage />} />
        <Route path="/fault-tickets" element={<TicketPage />} />
        <Route path="/work-orders" element={<WorkOrderPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/analysis" element={<AnalysisPage />} />
        <Route path="/calendar" element={<CalendarPage />} />
        <Route path="/rooms" element={<RoomsPage />} />
        <Route path="/reports" element={<ReportsPage />} />
        <Route path="/" element={<DashboardPage />} />
      </Routes>
    </Router>
  );
}

export default App;