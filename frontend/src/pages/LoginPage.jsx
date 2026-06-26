import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useMsal } from "@azure/msal-react";
import { authAPI } from '../services/api';
import { loginRequest } from '../services/msalConfig';
import '../styles/App.css';
import '../styles/Login.css';

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

    try {
      // Stuur aanmeldingsversoek na backend met gebruikersin-voer
      const response = await authAPI.login(username, password);
      const token = response.data?.access_token;

      // As token ontvang is, stoor dit en navigeer na dashboard
      if (token) {
        localStorage.setItem('token', token);
        navigate('/dashboard', { replace: true });
        // Haal huidige gebruiker se inligting op en stoor dit
        try {
          const userResponse = await authAPI.me();
          localStorage.setItem('user', JSON.stringify(userResponse.data));
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

    try {
      // Vertoon Microsoft-login popup vir gebruiker
      const response = await instance.loginPopup(loginRequest);
      const microsoftToken = response.accessToken;

      // Stuur Microsoft-token na backend vir validasie en uitruiling vir app-token
      const appTokenResponse = await authAPI.validateMicrosoftToken(microsoftToken);
      const appToken = appTokenResponse.data?.access_token;

      // As app-token ontvang is, stoor en navigeer
      if (appToken) {
        localStorage.setItem('token', appToken);
        navigate('/dashboard', { replace: true });
        // Haal en stoor gebruiker se inligting
        try {
          const userResponse = await authAPI.me();
          localStorage.setItem('user', JSON.stringify(userResponse.data));
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
    <div className="page">
      <h1>Teken In</h1>
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
          <a href="/forgot-password" className="forgot-password-link">Vergeet wagwoord?</a>
        </div>
        <button type="submit" className="btn-primary" disabled={loading}>
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
  );
}

export default LoginPage;