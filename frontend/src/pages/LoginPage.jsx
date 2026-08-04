import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useMsal } from "@azure/msal-react";
import { authAPI } from '../services/api';
import { loginRequest } from '../services/msalConfig';
import '../styles/App.css';
import '../styles/Login.css';
import { clearAuthSession, markUserActivity } from '../authSession';

function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();
  const { instance } = useMsal();

  // Hanteer plaaslike aanmelding met e-pos en wagwoord
  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    clearAuthSession();

    try {
      // Stuur aanmeldingsversoek na backend met gebruikersin-voer
      const response = await authAPI.login(username, password);
      const token = response.data?.access_token;

      // As token ontvang is, stoor dit en navigeer na dashboard
      if (token) {
        sessionStorage.setItem('token', token);
        markUserActivity();
        navigate('/dashboard', { replace: true });
        // Haal huidige gebruiker se inligting op en stoor dit
        try {
          const userResponse = await authAPI.me();
          sessionStorage.setItem('user', JSON.stringify(userResponse.data));
        } catch (meError) {
          console.warn('Could not fetch user info after login:', meError);
        }
      } else {
        setError('Login failed. No access token returned.');
      }
    } catch (err) {
      // Hanteer 403-fout (geen toegang tot stelsel vir hierdie rol)
      if (err.response?.status === 403) {
        setError(err.response?.data?.detail || 'Jy het nie toegang tot die FBS stelsel nie. Kontak Administrasie asseblief: admin@akademia.co.za');
      } else {
        setError(err.response?.data?.detail || 'Login failed. Please try again.');
      }
      console.error('Login error:', err);
    } finally {
      setLoading(false);
    }
  };

  // Hanteer Azure/Microsoft-aanmelding
  const handleMicrosoftLogin = async () => {
    setError('');
    setLoading(true);
    clearAuthSession();

    try {
      // 1. Vertoon Microsoft-login popup vir gebruiker
      const response = await instance.loginPopup(loginRequest);
      const microsoftToken = response.accessToken;

      // 2. HAAL N GEWELDIGE TOKEN UIT EXPLISIET VIR MICROSOFT GRAPH (KALENDER)
      try {
        const graphTokenResponse = await instance.acquireTokenSilent({
          ...loginRequest,
          account: response.account
        });
        // Stoor hierdie token sodat CalendarPage dit direk kan gebruik om Microsoft API te bel
        sessionStorage.setItem("ms_access_token", graphTokenResponse.accessToken);
      } catch (tokenError) {
        console.warn("Silent token acquisition failed, trying popup...", tokenError);
        const graphTokenResponse = await instance.acquireTokenPopup(loginRequest);
        sessionStorage.setItem("ms_access_token", graphTokenResponse.accessToken);
      }

      // 3. Stuur Microsoft-token na backend vir validasie en uitruiling vir app-token
      const appTokenResponse = await authAPI.validateMicrosoftToken(microsoftToken);
      const appToken = appTokenResponse.data?.access_token;

      // As app-token ontvang is, stoor en navigeer
      if (appToken) {
        sessionStorage.setItem('token', appToken);
        markUserActivity();
        navigate('/dashboard', { replace: true });
        // Haal en stoor gebruiker se inligting
        try {
          const userResponse = await authAPI.me();
          sessionStorage.setItem('user', JSON.stringify(userResponse.data));
        } catch (meError) {
          console.warn('Could not fetch user info after login:', meError);
        }
      } else {
        setError('Microsoft login failed. No app token received.');
      }
    } catch (err) {
      // Hanteer verskillende Microsoft-fouttoestande
      if (err.errorCode === 'popup_window_blocked') {
        setError('Popup was blocked. Please allow popups and try again.');
      } else if (err.errorCode === 'AADB2C90118') {
        setError('Please complete the registration process.');
      } else {
        setError(err.errorDescription || 'Microsoft login failed. Please try again.');
      }
      console.error('Microsoft login error:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="page login-page">
      <div className="login-card">
        <h2>Teken In</h2>
        <form onSubmit={handleSubmit} className="login-form">
          {error && <div className="error-message">{error}</div>}
          <div className="form-group">
            <label htmlFor="username">Gebruikersnaam:</label>
            <input
              type="text"
              id="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
              disabled={loading}
            />
          </div>
          <div className="form-group">
            <label htmlFor="password">Wagwoord:</label>
            <input
              type="password"
              id="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={loading}
            />
            <Link to="/forgot-password" className="forgot-password-link">Vergeet wagwoord?</Link>
          </div>
          <button type="submit" className="btn-login" disabled={loading}>
            {loading ? 'Besig...' : 'Teken In'}
          </button>
        </form>
        <div className="divider">of</div>
        <button
          type="button"
          className="btn-microsoft"
          onClick={handleMicrosoftLogin}
          disabled={loading}
        >
          <svg viewBox="0 0 21 21" xmlns="http://www.w3.org/2000/svg">
            <path fill="currentColor" d="M11 11h9v9h-9zm-10 0h9v9H1zm10-10h9v9h-9zm-10 0h9v9H1z"/>
          </svg>
          Teken in met Microsoft
        </button>
      </div>
    </div>
  );
}

export default LoginPage;