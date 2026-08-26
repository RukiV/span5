import React, { useState } from 'react';
import ImportExportModal from '../components/DataTransfer/ImportExportModal';
import '../styles/App.css';
import './VerslaePage.css';

function VerslaePage() {
  const [showWizard, setShowWizard] = useState(true);

  return (
    <div className="verslae-page">
      <div className="verslae-container">
        <ImportExportModal
          isOpen={showWizard}
          onClose={() => setShowWizard(false)}
          onImported={() => {}}
        />
        {!showWizard && (
          <div className="verslae-reopen">
            <p>Die invoer/uitvoer paneel is gesluit.</p>
            <button className="btn-add" onClick={() => setShowWizard(true)}>
              Heropen In/Uitvoer
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

export default VerslaePage;
