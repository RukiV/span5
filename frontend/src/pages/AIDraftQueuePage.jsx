import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { apiClient } from "../services/api";
import { useToast } from '../components/Toast/useToast';
import '../styles/App.css';

function AIDraftQueuePage() {
  const { showToast } = useToast();
  const navigate = useNavigate();

  const [drafts, setDrafts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("draft");

  useEffect(() => {
    fetchDrafts();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [statusFilter]);

  const fetchDrafts = async () => {
    setLoading(true);
    try {
      const params = { status_filter: statusFilter }; // '' = Alle (backend treats empty as no filter)
      const response = await apiClient.faultDrafts.getAll(params);
      setDrafts(response.data || []);
    } catch (error) {
      console.error("Error fetching AI drafts:", error);
      showToast({ type: 'error', title: 'Fout', message: "Fout by laai van AI-konsepte: " + (error.response?.data?.detail || error.message) });
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('af-ZA', { year: 'numeric', month: 'short', day: 'numeric' });
  };

  const getAiStatusBadge = (aiStatus) => {
    if (aiStatus === 'ok') {
      return <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#d4edda', color: '#155724' }}>OK</span>;
    }
    if (aiStatus === 'degraded') {
      return <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#fff3cd', color: '#856404' }}>Afgemaal</span>;
    }
    return <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#e9ecef', color: '#333' }}>{aiStatus || '-'}</span>;
  };

  const getSourceLabel = (source) => {
    if (source === 'auto') return 'Outomaties';
    if (source === 'manual') return 'Handmatig';
    return source || '-';
  };

  if (loading) {
    return <div className="main"><div className="content">Laai...</div></div>;
  }

  return (
    <div className="main">
      <div className="content">
        <div className="controls">
          <div className="controls-left">
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="">Alle</option>
              <option value="draft">Konsepte</option>
              <option value="approved">Goedgekeur</option>
              <option value="rejected">Afgewys</option>
            </select>
          </div>
          <div className="controls-right">
            <button className="btn-add" onClick={() => navigate('/ai-drafts/new')}>+ Nuwe AI Konsep</button>
            <button className="btn-edit" onClick={fetchDrafts} style={{ marginLeft: '0.5rem' }}>Vernuwe</button>
          </div>
        </div>

        <table className="standard-table">
          <thead>
            <tr>
              <th style={{ width: '80px' }}>ID</th>
              <th>Titel</th>
              <th>Tipe</th>
              <th>Prioriteit</th>
              <th>AI Status</th>
              <th>Bron</th>
              <th>Datum</th>
              <th style={{ width: '100px' }}>Aksies</th>
            </tr>
          </thead>
          <tbody>
            {drafts.length === 0 ? (
              <tr><td colSpan={8} style={{ textAlign: 'center', padding: '20px' }}>Geen AI-konsepte gevind nie</td></tr>
            ) : (
              drafts.map((draft) => (
                <tr key={draft.draft_id} style={{ cursor: "pointer" }} onClick={() => navigate(`/ai-drafts/${draft.draft_id}`)}>
                  <td>{draft.draft_id}</td>
                  <td>{draft.title || (draft.description ? draft.description.substring(0, 80) + (draft.description.length > 80 ? '...' : '') : '-')}</td>
                  <td>{draft.suggested_type || '-'}</td>
                  <td>{draft.suggested_priority || '-'}</td>
                  <td>{getAiStatusBadge(draft.ai_status)}</td>
                  <td>{getSourceLabel(draft.source)}</td>
                  <td>{formatDate(draft.created_at)}</td>
                  <td onClick={e => e.stopPropagation()}>
                    <button className="btn-add" onClick={() => navigate(`/ai-drafts/${draft.draft_id}`)}>Bekyk</button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default AIDraftQueuePage;
