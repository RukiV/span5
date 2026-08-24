import React, { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { apiClient } from "../services/api";
import { useToast } from '../components/Toast/useToast';
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import ResizableTh from "../components/ResizableTh";
import '../styles/App.css';

const DRAFT_COLUMNS = [
  { key: 'id', label: 'ID', render: (d) => d.draft_id, sortKey: 'id', defaultVisible: true },
  {
    key: 'title', label: 'Titel',
    render: (d) => d.title || (d.description ? d.description.substring(0, 80) + (d.description.length > 80 ? '...' : '') : '-'),
    sortKey: 'title', defaultVisible: true,
  },
  // Bate-kolom by verstek sigbaar — meeste titels is eenders; die bate/kandidaat
  // onderskei waarheen die konsep verwys (agterkant val terug op eerste kandidaat).
  {
    key: 'asset', label: 'Bate',
    render: (d) => d.resolved_asset_name || '-',
    sortKey: 'asset', defaultVisible: true,
  },
  { key: 'type', label: 'Tipe', render: (d) => d.suggested_type || '-', sortKey: 'type', defaultVisible: true },
  { key: 'priority', label: 'Prioriteit', render: (d) => d.suggested_priority || '-', sortKey: 'priority', defaultVisible: true },
  { key: 'ai', label: 'AI Status', render: (d) => getAiStatusBadge(d.ai_status), sortKey: 'ai', defaultVisible: true },
  { key: 'source', label: 'Bron', render: (d) => getSourceLabel(d.source), sortKey: 'source', defaultVisible: true },
  { key: 'date', label: 'Datum', render: (d) => formatDate(d.created_at), sortKey: 'date', defaultVisible: true },
];

function formatDate(dateStr) {
  if (!dateStr) return '-';
  return new Date(dateStr).toLocaleDateString('af-ZA', { year: 'numeric', month: 'short', day: 'numeric' });
}

function getAiStatusBadge(aiStatus) {
  if (aiStatus === 'ok') {
    return <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#d4edda', color: '#155724' }}>OK</span>;
  }
  if (aiStatus === 'degraded') {
    return <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#fff3cd', color: '#856404' }}>Afgemaal</span>;
  }
  return <span style={{ padding: '3px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold', backgroundColor: '#e9ecef', color: '#333' }}>{aiStatus || '-'}</span>;
}

function getSourceLabel(source) {
  if (source === 'auto') return 'Outomaties';
  if (source === 'manual') return 'Handmatig';
  return source || '-';
}

function AIDraftQueuePage() {
  const { showToast } = useToast();
  const navigate = useNavigate();
  const colPickerRef = useRef(null);

  const [drafts, setDrafts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("draft");

  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: null });
  const colVis = useColumnVisibility('ai-draft-queue', DRAFT_COLUMNS);
  const colWidths = useColumnWidths('ai-draft-queue', DRAFT_COLUMNS);

  useEffect(() => {
    fetchDrafts();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [statusFilter]);

  const fetchDrafts = async () => {
    setLoading(true);
    try {
      const params = { status_filter: statusFilter }; // '' = Alle (backend treats empty as no filter)
      const response = await apiClient.jobDrafts.getAll(params);
      setDrafts(response.data || []);
    } catch (error) {
      console.error("Error fetching AI drafts:", error);
      showToast({ type: 'error', title: 'Fout', message: "Fout by laai van AI-konsepte: " + (error.response?.data?.detail || error.message) });
    } finally {
      setLoading(false);
    }
  };

  const sortedDrafts = [...drafts].sort((a, b) => {
    if (!sortKey) return 0;
    const dir = sortDirection === 'asc' ? 1 : -1;
    switch (sortKey) {
      case 'id': return (Number(a.draft_id || 0) - Number(b.draft_id || 0)) * dir;
      case 'title': {
        const ta = a.title || a.description || '';
        const tb = b.title || b.description || '';
        return String(ta).localeCompare(String(tb), 'af', { sensitivity: 'base' }) * dir;
      }
      case 'asset': return String(a.resolved_asset_name || '').localeCompare(String(b.resolved_asset_name || ''), 'af', { sensitivity: 'base' }) * dir;
      case 'type': return String(a.suggested_type || '').localeCompare(String(b.suggested_type || ''), 'af') * dir;
      case 'priority': return String(a.suggested_priority || '').localeCompare(String(b.suggested_priority || ''), 'af') * dir;
      case 'ai': return String(a.ai_status || '').localeCompare(String(b.ai_status || ''), 'af') * dir;
      case 'source': return String(a.source || '').localeCompare(String(b.source || ''), 'af') * dir;
      case 'date': return (new Date(a.created_at || 0) - new Date(b.created_at || 0)) * dir;
      default: return 0;
    }
  });

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
            <ColumnPicker
              ref={colPickerRef}
              columns={DRAFT_COLUMNS}
              visibleColumns={colVis.visibleColumns}
              toggleColumn={colVis.toggleColumn}
              resetVisibility={colVis.resetVisibility}
              onResetWidths={colWidths.resetWidths}
            />
          </div>
        </div>

        <table className="standard-table">
          <thead>
            <tr>
              {colVis.visibleColumns.map((col) => (
                <ResizableTh
                  key={col.key}
                  col={col}
                  colWidths={colWidths}
                  className={col.sortKey ? getSortClass(col.sortKey) : ''}
                  onClick={() => col.sortKey && handleSort(col.sortKey)}
                  onContextMenu={(e) => colPickerRef.current?.openAt(e)}
                >
                  {col.label}{col.sortKey && getSortIndicator(col.sortKey)}
                </ResizableTh>
              ))}
              <th style={{ width: '100px' }}>Aksies</th>
            </tr>
          </thead>
          <tbody>
            {sortedDrafts.length === 0 ? (
              <tr><td colSpan={colVis.visibleColumns.length + 1} style={{ textAlign: 'center', padding: '20px' }}>Geen AI-konsepte gevind nie</td></tr>
            ) : (
              sortedDrafts.map((draft) => (
                <tr key={draft.draft_id} style={{ cursor: "pointer" }} onClick={() => navigate(`/ai-drafts/${draft.draft_id}`)}>
                  {colVis.visibleColumns.map((col) => (
                    <td key={col.key}>{col.render(draft)}</td>
                  ))}
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