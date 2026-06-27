import React from 'react';
import ReactDOM from 'react-dom/client';
import { MsalProvider } from "@azure/msal-react";
import { PublicClientApplication } from "@azure/msal-browser";
import './index.css';
import App from './App';
import { msalConfig } from './services/msalConfig';

const msalInstance = new PublicClientApplication(msalConfig);

const root = ReactDOM.createRoot(document.getElementById('root'));

// Global fallback logout used by pages that haven't imported the hook yet.
window.__logout = function() {
  try { sessionStorage.clear(); localStorage.clear(); } catch(_) {}
  window.location.replace(window.location.origin + '/login');
}

root.render(
  <React.StrictMode>
    <MsalProvider instance={msalInstance}>
      <App />
    </MsalProvider>
  </React.StrictMode>
);