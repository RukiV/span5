import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { authAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import '../styles/Reports.css';
import { useLogout } from './Page.jsx';

function ReportsPage() {
  const { isAdmin, user } = useCurrentUser();
  const logout = useLogout();
  const [loading, setLoading] = useState(true);

  // Validate token with backend on mount — if invalid, force logout
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
          <li><Link to="/calendar" >Kalender</Link></li>
          <li><Link to="/analysis">Analise</Link></li>
          <li><Link to="/reports" style={{ background: '#935e28' }}>Verslae</Link></li>  
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
          <h3>Verslae</h3>
          
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

        {/* Verslae-inhoud */}
        <div className="content">
          <p>Verslae bladsy - Hier sal die verslae komponent wees.</p>
        </div>
      </div>
    </div>
  );
}

export default ReportsPage;