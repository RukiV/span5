import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

/**
 * MSAL-auth omskeiding/terugkeer-bladsy.
 *
 * Met die popup-aanmelding fluister Microsoft die popup-venster na
 * redirectUri (/auth/callback). MSAL-browser vang die hash in die popup op
 * en lewer die resultaat aan die opener. Hierdie bladsy word dus net "vlugtig"
 * gelaai; ons wys 'n kort laai-boodskap terwyl MSAL die terugkeer hanteer en
 * keer daarna terug na die login-skerm as die popup alleenstaande oopgemaak is.
 */
function AuthCallback() {
  const navigate = useNavigate();

  useEffect(() => {
    const isPopup = (() => {
      try {
        return window.self !== window.top;
      } catch (e) {
        return false;
      }
    })();

    // In 'n popup hanteer MSAL die terugkeer self en sluit die venster.
    // As dit die hoofvenster is (redirect-login), was daar waarskynlik 'n fout
    // of geen token nie — stuur terug na login.
    if (!isPopup) {
      const timer = setTimeout(() => {
        navigate('/login', { replace: true });
      }, 1000);
      return () => clearTimeout(timer);
    }
  }, [navigate]);

  return (
    <div className="page login-page">
      <div className="login-card">
        <h2>Teken In</h2>
        <p>{status}</p>
      </div>
    </div>
  );
}

export default AuthCallback;
