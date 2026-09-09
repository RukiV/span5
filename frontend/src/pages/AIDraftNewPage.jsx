import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { apiClient } from "../services/api";
import { useToast } from '../components/Toast/useToast';
import '../styles/App.css';

function AIDraftNewPage() {
  const { showToast } = useToast();
  const navigate = useNavigate();

  const [description, setDescription] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async () => {
    if (!description.trim()) {
      showToast({ type: 'error', title: 'Fout', message: "Voer asseblief 'n beskrywing in." });
      return;
    }

    setSubmitting(true);
    try {
      await apiClient.jobDrafts.create({ description: description.trim() });
      showToast({ type: 'success', title: 'Slaag', message: 'AI-konsep suksesvol gegenereer. Die konsep sal deur FK/Admin hersien word.' });
      navigate('/ai-drafts');
    } catch (error) {
      console.error("Error creating AI draft:", error);
      const errorDetail = error.response?.data?.detail;
      const errorMsg = Array.isArray(errorDetail)
        ? errorDetail.map(e => `${e.loc?.join('.')}: ${e.msg}`).join('\n')
        : errorDetail || error.message;
      showToast({ type: 'error', title: 'Fout', message: "Fout by skep van AI-konsep:\n" + errorMsg });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="main">
      <div className="content">
        <div className="controls controls--sticky controls--with-tabs">
          <div className="controls-left">
            <h3 style={{ margin: 0 }}>Nuwe AI Foutkonsep</h3>
          </div>
          <div className="controls-right">
            <button className="btn-edit" onClick={() => navigate('/ai-drafts')}>Terug</button>
          </div>
        </div>

        <div style={{ maxWidth: '700px', marginTop: '1rem' }}>
          <div className="input-group" style={{ marginBottom: '1rem' }}>
            <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 600 }}>Beskrywing *</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Plak die foutverslag of nota hier..."
              rows={8}
              disabled={submitting}
              style={{ width: '100%', padding: '10px', border: '1px solid #cbd5e1', borderRadius: '5px', resize: 'vertical', fontFamily: 'inherit' }}
            />
          </div>

          <div style={{ padding: '12px', backgroundColor: '#f0f4f8', borderRadius: '6px', marginBottom: '1.5rem', fontSize: '0.9rem', color: '#4a5568' }}>
            Die AI sal die beskrywing skoonmaak en 'n konsep-foutkaartjie genereer met voorgestelde tipe, prioriteit, bate en lokaal. Die konsep sal deur 'n FK of Admin hersien en goedgekeur word voordat dit 'n amptelike foutkaartjie word.
          </div>

          <div className="modal-footer">
            <button className="btn-cancel" onClick={() => navigate('/ai-drafts')} disabled={submitting}>Kanselleer</button>
            <button className="btn-add" onClick={handleSubmit} disabled={submitting}>
              {submitting ? 'Besig om te genereer...' : 'Genereer Konsep'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default AIDraftNewPage;
