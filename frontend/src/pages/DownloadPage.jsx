import React from 'react';
import { Link } from 'react-router-dom';

/* Android-app-aflaai-bladsy. Openbaar bereikbaar (geen aanmelding nodig) sodat
   enigeen wat na die publieke URL kom die Android-APK kan aflaai en installeer.
   Sodra die APK gebou is, plaas dit in frontend/public/fbs.apk en hierdie bladsy
   bedien dit outomaties. */
function DownloadPage() {
  const apkUrl = `${process.env.PUBLIC_URL || ''}/fbs.apk`;

  return (
    <div className="download-page">
      <div className="download-card">
        <h1>Akademia Fasiliteite App</h1>
        <p>
          Laai die Android-app af om foutkaartjies aan te meld, werksopdragte te
          sien en jou bates reg op jou foon te bestuur.
        </p>

        <a className="btn-add download-btn" href={apkUrl} download>
          ⬇ Laai die Android-app af (APK)
        </a>

        <div className="download-note">
          <strong>Installasie:</strong> tik op die aflaai-knoppie en laat jou foon
          toe om "bekende bronne" (install unknown apps) te gebruik vir hierdie
          webwerf. Sodra die APK afgelaai is, tik daarop om te installeer.
        </div>

        <div className="download-footer">
          <Link to="/dashboard">Terug na die webwerf</Link>
        </div>
      </div>
    </div>
  );
}

export default DownloadPage;
