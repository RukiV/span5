import React, { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { apiClient } from "../services/api";
import { useToast } from '../components/Toast/useToast';
import InfoTip, { JOB_TYPE_HELP } from "../components/InfoTip";
import '../styles/App.css';

function AIDraftDetailPage() {
  const { showToast } = useToast();
  const navigate = useNavigate();
  const { id } = useParams();

  const [draft, setDraft] = useState(null);
  const [loading, setLoading] = useState(true);

  // Editable fields (pre-filled from draft)
  const [cleanedDescription, setCleanedDescription] = useState("");
  const [title, setTitle] = useState("");
  const [faultType, setFaultType] = useState("");
  const [faultPriority, setFaultPriority] = useState("");
  const [selectedAssetId, setSelectedAssetId] = useState(null);
  const [selectedRoomId, setSelectedRoomId] = useState(null);

  // Reject modal
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    fetchDraft();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const fetchDraft = async () => {
    setLoading(true);
    try {
      const response = await apiClient.jobDrafts.getById(id);
      const d = response.data;
      setDraft(d);
      setCleanedDescription(d.cleaned_description || "");
      setTitle(d.title || "");
      setFaultType(d.suggested_type || "");
      setFaultPriority(d.suggested_priority || "");
      setSelectedAssetId(d.resolved_asset_id || (d.asset_candidates && d.asset_candidates.length > 0 ? d.asset_candidates[0].id : null));
      setSelectedRoomId(d.resolved_room_id || (d.room_candidates && d.room_candidates.length > 0 ? d.room_candidates[0].id : null));
    } catch (error) {
      console.error("Error fetching AI draft:", error);
      showToast({ type: 'error', title: 'Fout', message: "Fout by laai van AI-konsep: " + (error.response?.data?.detail || error.message) });
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async () => {
    setActionLoading(true);
    try {
      const payload = {
        cleaned_description: cleanedDescription,
        title,
        fault_type: faultType || undefined,
        fault_priority: faultPriority || undefined,
        asset_id: selectedAssetId || undefined,
        room_id: selectedRoomId || undefined,
      };
      await apiClient.jobDrafts.approve(id, payload);
      showToast({ type: 'success', title: 'Slaag', message: 'Konsep goedgekeur' });
      navigate('/ai-drafts');
    } catch (error) {
      console.error("Error approving draft:", error);
      if (error.response && error.response.status === 409) {
        showToast({ type: 'error', title: 'Fout', message: 'Konsep is reeds hanteer' });
        navigate('/ai-drafts');
      } else {
        const errorDetail = error.response?.data?.detail;
        const errorMsg = Array.isArray(errorDetail)
          ? errorDetail.map(e => `${e.loc?.join('.')}: ${e.msg}`).join('\n')
          : errorDetail || error.message;
        showToast({ type: 'error', title: 'Fout', message: "Fout by goedkeuring:\n" + errorMsg });
      }
    } finally {
      setActionLoading(false);
    }
  };

  const handleReject = async () => {
    if (!rejectReason.trim()) {
      showToast({ type: 'error', title: 'Fout', message: "Voer asseblief 'n rede vir afwysing in." });
      return;
    }
    setActionLoading(true);
    try {
      await apiClient.jobDrafts.reject(id, { reason: rejectReason.trim() });
      showToast({ type: 'success', title: 'Slaag', message: 'Konsep is afgewys' });
      navigate('/ai-drafts');
    } catch (error) {
      console.error("Error rejecting draft:", error);
      if (error.response && error.response.status === 409) {
        showToast({ type: 'error', title: 'Fout', message: 'Konsep is reeds hanteer' });
        navigate('/ai-drafts');
      } else {
        const errorDetail = error.response?.data?.detail;
        const errorMsg = Array.isArray(errorDetail)
          ? errorDetail.map(e => `${e.loc?.join('.')}: ${e.msg}`).join('\n')
          : errorDetail || error.message;
        showToast({ type: 'error', title: 'Fout', message: "Fout by afwysing:\n" + errorMsg });
      }
    } finally {
      setActionLoading(false);
    }
  };

  const getAiStatusBadge = (aiStatus) => {
    if (aiStatus === 'ok') {
      return <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#d4edda', color: '#155724' }}>AI: OK</span>;
    }
    if (aiStatus === 'degraded') {
      return <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#fff3cd', color: '#856404' }}>AI: Afgemaal</span>;
    }
    return <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#e9ecef', color: '#333' }}>AI: {aiStatus || '-'}</span>;
  };

  const getStatusLabel = (status) => {
    const translations = { draft: 'Konsep', approved: 'Goedgekeur', rejected: 'Afgewys' };
    return translations[status] || status || '-';
  };

  const getStatusClass = (status) => {
    switch (status) {
      case 'draft': return 'status-wait';
      case 'approved': return 'status-resolved';
      case 'rejected': return 'status-closed';
      default: return 'status-default';
    }
  };

  const getSourceLabel = (source) => {
    if (source === 'auto') return 'Outomaties';
    if (source === 'manual') return 'Handmatig';
    return source || '-';
  };

  if (loading) {
    return <div className="main"><div className="content">Laai...</div></div>;
  }

  if (!draft) {
    return <div className="main"><div className="content">Konsep nie gevind nie.</div></div>;
  }

  const isDraft = draft.status === 'draft';
  const isReviewed = draft.status === 'approved' || draft.status === 'rejected';

  return (
    <div className="main">
      <div className="content">
        {/* Header */}
        <div className="controls">
          <div className="controls-left">
            <h3 style={{ margin: 0 }}>{draft.title || 'AI Foutkonsep'} #{draft.draft_id}</h3>
          </div>
          <div className="controls-right">
            <button className="btn-edit" onClick={() => navigate('/ai-drafts')}>Terug</button>
          </div>
        </div>

        {/* Badges */}
        <div style={{ display: 'flex', gap: '8px', marginBottom: '1rem', flexWrap: 'wrap' }}>
          <span className={`status ${getStatusClass(draft.status)}`}>{getStatusLabel(draft.status)}</span>
          <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#e2e8f0', color: '#2d3748' }}>
            {getSourceLabel(draft.source)}
          </span>
          {getAiStatusBadge(draft.ai_status)}
        </div>

        {/* Original description */}
        <div style={{ marginBottom: '1.5rem' }}>
          <label style={{ display: 'block', fontWeight: 600, marginBottom: '0.25rem' }}>Oorspronklike beskrywing:</label>
          <div style={{ padding: '10px', backgroundColor: '#f7fafc', border: '1px solid #e2e8f0', borderRadius: '5px', whiteSpace: 'pre-wrap' }}>
            {draft.description || '-'}
          </div>
        </div>

        {isDraft && (
          <>
            {/* Editable fields */}
            <div className="input-row" style={{ marginBottom: '1rem' }}>
              <div className="input-group" style={{ flex: 2 }}>
                <label style={{ display: 'block', marginBottom: '0.25rem', fontWeight: 600 }}>Titel</label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  disabled={actionLoading}
                  style={{ width: '100%', padding: '10px', border: '1px solid #cbd5e1', borderRadius: '5px' }}
                />
              </div>
              <div className="input-group" style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '0.25rem', fontWeight: 600 }}>
                  Tipe
                  <InfoTip
                    ariaLabel="Verduideliking van werksoorte"
                    text={JOB_TYPE_HELP[faultType] || 'Kies die soort werk: Herstelwerk (iets is gebreek), Onderhoud (roetine-diens), Inspeksie (kyk of alles werk) of Installasie (nuwe toestel opsit).'}
                  />
                </label>
                <select
                  value={faultType}
                  onChange={(e) => setFaultType(e.target.value)}
                  disabled={actionLoading}
                  style={{ width: '100%', padding: '10px', border: '1px solid #cbd5e1', borderRadius: '5px', backgroundColor: 'white' }}
                >
                  <option value="">Kies tipe</option>
                  <option value="REPAIR">Herstelwerk</option>
                  <option value="MAINTENANCE">Onderhoud</option>
                  <option value="INSPECTION">Inspeksie</option>
                  <option value="INSTALLATION">Installasie</option>
                </select>
              </div>
              <div className="input-group" style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '0.25rem', fontWeight: 600 }}>Prioriteit</label>
                <select
                  value={faultPriority}
                  onChange={(e) => setFaultPriority(e.target.value)}
                  disabled={actionLoading}
                  style={{ width: '100%', padding: '10px', border: '1px solid #cbd5e1', borderRadius: '5px', backgroundColor: 'white' }}
                >
                  <option value="">Kies prioriteit</option>
                  <option value="LOW">Laag</option>
                  <option value="MEDIUM">Medium</option>
                  <option value="HIGH">Hoog</option>
                </select>
              </div>
            </div>

            <div style={{ marginBottom: '1rem' }}>
              <label style={{ display: 'block', marginBottom: '0.25rem', fontWeight: 600 }}>
                Skoon beskrywing
                <InfoTip
                  ariaLabel="Wat is 'n skoon beskrywing?"
                  text="Die oorspronklike foutbeskrywing, netjies herskryf: spelfoute en herhaling reggemaak en die kernprobleem duidelik gestate — sonder om inligting by te voeg of te versin. Dit word die werkkaart se beskrywing by goedkeuring."
                />
              </label>
              <textarea
                value={cleanedDescription}
                onChange={(e) => setCleanedDescription(e.target.value)}
                rows={4}
                disabled={actionLoading}
                style={{ width: '100%', padding: '10px', border: '1px solid #cbd5e1', borderRadius: '5px', resize: 'vertical', fontFamily: 'inherit' }}
              />
            </div>

            {/* Asset candidates */}
            {draft.asset_candidates && draft.asset_candidates.length > 0 && (
              <div style={{ marginBottom: '1rem' }}>
                <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 600 }}>Bate kandidate:</label>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  {draft.asset_candidates.map((asset) => (
                    <label
                      key={asset.id}
                      style={{
                        display: 'flex', alignItems: 'flex-start', gap: '10px', padding: '10px',
                        border: selectedAssetId === asset.id ? '2px solid #935E28' : '1px solid #cbd5e1',
                        borderRadius: '6px', cursor: 'pointer', backgroundColor: selectedAssetId === asset.id ? '#fdf8f3' : 'white',
                      }}
                    >
                      <input
                        type="radio"
                        name="asset_candidate"
                        value={asset.id}
                        checked={selectedAssetId === asset.id}
                        onChange={() => setSelectedAssetId(asset.id)}
                        disabled={actionLoading}
                        style={{ marginTop: '2px' }}
                      />
                      <div>
                        <div style={{ fontWeight: 600 }}>{asset.name}</div>
                        {asset.detail && <div style={{ fontSize: '0.85rem', color: '#666' }}>{asset.detail}</div>}
                      </div>
                    </label>
                  ))}
                </div>
              </div>
            )}

            {/* Room candidates */}
            {draft.room_candidates && draft.room_candidates.length > 0 && (
              <div style={{ marginBottom: '1rem' }}>
                <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 600 }}>Lokaal kandidate:</label>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  {draft.room_candidates.map((room) => (
                    <label
                      key={room.id}
                      style={{
                        display: 'flex', alignItems: 'flex-start', gap: '10px', padding: '10px',
                        border: selectedRoomId === room.id ? '2px solid #935E28' : '1px solid #cbd5e1',
                        borderRadius: '6px', cursor: 'pointer', backgroundColor: selectedRoomId === room.id ? '#fdf8f3' : 'white',
                      }}
                    >
                      <input
                        type="radio"
                        name="room_candidate"
                        value={room.id}
                        checked={selectedRoomId === room.id}
                        onChange={() => setSelectedRoomId(room.id)}
                        disabled={actionLoading}
                        style={{ marginTop: '2px' }}
                      />
                      <div>
                        <div style={{ fontWeight: 600 }}>{room.name}</div>
                        {room.detail && <div style={{ fontSize: '0.85rem', color: '#666' }}>{room.detail}</div>}
                      </div>
                    </label>
                  ))}
                </div>
              </div>
            )}

            {/* Action buttons */}
            <div className="modal-footer" style={{ marginTop: '1.5rem' }}>
              <button className="btn-cancel" onClick={() => navigate('/ai-drafts')} disabled={actionLoading}>Kanselleer</button>
              <button
                className="btn-delete"
                onClick={() => setShowRejectModal(true)}
                disabled={actionLoading}
                style={{ marginRight: '0.5rem' }}
              >
                Keur Af
              </button>
              <button className="btn-add" onClick={handleApprove} disabled={actionLoading}>
                {actionLoading ? 'Besig...' : 'Keur Goed'}
              </button>
            </div>
          </>
        )}

        {isReviewed && (
          <div style={{ marginTop: '1rem' }}>
            <div style={{ padding: '12px', backgroundColor: '#f0f4f8', borderRadius: '6px', marginBottom: '1rem' }}>
              <p style={{ margin: 0 }}><strong>Status:</strong> {getStatusLabel(draft.status)}</p>
              {draft.reviewed_at && <p style={{ margin: '0.5rem 0 0' }}><strong>Hersien op:</strong> {new Date(draft.reviewed_at).toLocaleString('af-ZA')}</p>}
              {draft.reviewer_id && <p style={{ margin: '0.5rem 0 0' }}><strong>Hersien deur:</strong> Gebruiker #{draft.reviewer_id}</p>}
              {draft.review_note && <p style={{ margin: '0.5rem 0 0' }}><strong>Nota:</strong> {draft.review_note}</p>}
            </div>
            <button className="btn-edit" onClick={() => navigate('/ai-drafts')}>Terug</button>
          </div>
        )}

        {/* Reject modal */}
        {showRejectModal && (
          <div className="modal" style={{ display: "flex" }}>
            <div className="modal-content">
              <div className="modal-header">
                <h3>Konsep Afwys</h3>
                <span className="close" onClick={() => { setShowRejectModal(false); setRejectReason(""); }}>&times;</span>
              </div>
              <div className="input-group" style={{ padding: '1rem' }}>
                <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 600 }}>Rede vir afwysing *</label>
                <textarea
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  rows={4}
                  placeholder="Verduidelik waarom hierdie konsep afgewys word..."
                  disabled={actionLoading}
                  style={{ width: '100%', padding: '10px', border: '1px solid #cbd5e1', borderRadius: '5px', resize: 'vertical', fontFamily: 'inherit' }}
                />
              </div>
              <div className="modal-footer">
                <button className="btn-cancel" onClick={() => { setShowRejectModal(false); setRejectReason(""); }} disabled={actionLoading}>Kanselleer</button>
                <button className="btn-delete" onClick={handleReject} disabled={actionLoading}>
                  {actionLoading ? 'Besig...' : 'Keur Af'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default AIDraftDetailPage;
