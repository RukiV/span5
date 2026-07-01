import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { authAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import '../styles/Analysis.css';
import { useLogout } from './Page.jsx';

function AnalysisPage() {
  const { isAdmin, user } = useCurrentUser();
  const logout = useLogout();
  const [loading, setLoading] = useState(true);

  // Valideer token met backend op mount — as dit ongeldig is, dwing uitlog
  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await authAPI.me();
        if (mounted) setLoading(false);
      } catch (err) {
        try { sessionStorage.clear(); localStorage.clear(); } catch(_) {}
        window.location.replace(window.location.origin + '/login');
      }
    })();
    return () => { mounted = false; };
  }, []);

  if (loading) {
    return (
      <div style={{ display: "flex" }}>
        <div className="main">
          <div className="content">Laai...</div>
        </div>
      </div>
    );
  }

  return (
    <div>
      {/* LINKERBAAD - Navigasie-menu */}
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li className="dropdown">
            <div className="dropdown-trigger">
              <span>Bates & Voorraad</span>
            </div>
            <div className="dropdown-content">
              <Link to="/assets">Bates</Link>
              <Link to="/stock">Voorraad</Link>
            </div>
          </li>
          <li className="dropdown">
            <div className="dropdown-trigger">
              <span>Lokale & Terreine</span>
            </div>
            <div className="dropdown-content">
              <Link to="/rooms">Lokale</Link>
              <Link to="/terrains">Terreine</Link>
            </div>
          </li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          <li><Link to="/contractors">Kontrakteurs</Link></li>
          <li><Link to="/calendar" >Kalender</Link></li>
          <li><Link to="/analysis" style={{ background: '#935e28' }}>Analise</Link></li>
          <li><Link to="/reports">Verslae</Link></li>  
          {isAdmin && <li><Link to="/users">Gebruikers</Link></li>}
        </ul>
        <div className="logout-container">
          <button type="button" className="btn-logout-sidebar" onClick={() => logout()}>
            Teken Uit
          </button>
        </div>
      </div>

      {/* HOOFINHOUD */}
      <div className="main">
        {/* Top balk met titel en gebruiker-info */}
        <div className="navbar">
          <h3>Analise</h3>
          
          {/* VERTOON NOU ROL, NAAM EN EMAIL REGS BO */}
          <div className="user-profile-box" style={{ textAlign: 'right', fontSize: '14px', lineHeight: '1.3' }}>
            {user ? (
              <>
                <div className="user-name" style={{ fontWeight: 'bold' }}>
                  {user.user_name} {user.user_surname}
                </div>
                <div className="user-role" style={{ fontSize: '12px', color: '#935e28', fontWeight: '600' }}>
                  {user.role_id === 3 ? "Administrateur" : user.role_id === 2 ? "Personeel" : "Student"}
                </div>
                <div className="user-email" style={{ fontSize: '11px', color: '#666' }}>
                  {user.user_email}
                </div>
              </>
            ) : (
              <div className="user-loading" style={{ color: '#999' }}>Laai profiel...</div>
            )}
          </div>
        </div>

        <div className="content">
          {/* Hoofstatistieke met sleutelmetrieke */}
          <div className="stats-grid">
            <div className="stat-card">
              <h4>Totale Bates</h4>
              <p className="stat-number">1,248</p>
              <span className="stat-change positive">+4.5% nuwe bates</span>
            </div>
            <div className="stat-card">
              <h4>Bates Tans Uitgeleen</h4>
              <p className="stat-number">56</p>
              <span className="stat-change">Tans in gebruik deur personeel</span>
            </div>
            <div className="stat-card">
              <h4>Onderhoud Benodig</h4>
              <p className="stat-number">12</p>
              <span className="stat-change negative">3 Kritieke herstelwerk</span>
            </div>
            <div className="stat-card">
              <h4>Beskikbaarheidskoers</h4>
              <p className="stat-number">92%</p>
              <span className="stat-change positive">Bates gereed vir gebruik</span>
            </div>
          </div>

          {/* Grafieke vir visuele analise */}
          <div className="charts-container">
            <div className="chart-box">
              <h3>Bate-benutting per Maand</h3>
              <div style={{ height: '250px', background: '#f0f0f0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                Grafiek Plekganger
              </div>
            </div>
            <div className="chart-box">
              <h3>Bates per Kategorie</h3>
              <div style={{ height: '250px', background: '#f0f0f0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                Grafiek Plekganger
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default AnalysisPage;