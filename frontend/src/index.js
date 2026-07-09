import React from 'react';
import ReactDOM from 'react-dom/client';
import { MsalProvider } from "@azure/msal-react";
import { PublicClientApplication } from "@azure/msal-browser";
import './index.css';
import App from './App';
import { msalConfig } from './services/msalConfig';
import { clearAuthSession, markUserActivity } from './authSession';

const msalInstance = new PublicClientApplication(msalConfig);

const root = ReactDOM.createRoot(document.getElementById('root'));

// Global fallback logout used by pages that haven't imported the hook yet.
window.__logout = function() {
  clearAuthSession();
  window.location.replace(window.location.origin + '/login');
}

window.addEventListener('mousemove', markUserActivity);
window.addEventListener('keydown', markUserActivity);
window.addEventListener('click', markUserActivity);
window.addEventListener('scroll', markUserActivity);
window.addEventListener('touchstart', markUserActivity);

root.render(
  <React.StrictMode>
    <MsalProvider instance={msalInstance}>
      <App />
    </MsalProvider>
  </React.StrictMode>
);