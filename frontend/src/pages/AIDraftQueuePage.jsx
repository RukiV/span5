import React, { useState, useEffect, useRef } from "react";
import Select from "react-select";
import { useNavigate } from "react-router-dom";
import { apiClient } from "../services/api";
import { useToast } from '../components/Toast/useToast';
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import SortPicker from "../components/ColumnPicker/SortPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import usePagination from "../hooks/usePagination";
import Pagination from "../components/Pagination/Pagination";
import ResizableTh from "../components/ResizableTh";
import '../styles/App.css';

const DRAFT_COLUMNS = [
  { key: 'id', label: 'ID', render: (d) => d.draft_id, sortKey: 'id', defaultVisible: false },
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
  { key: 'source', label: 'Bron', render: (d) => getSourceLabel(d.source), sortKey: 'source', defaultVisible: true },
  { key: 'date', label: 'Datum', render: (d) => formatDate(d.created_at), sortKey: 'date', defaultVisible: true },
];

function formatDate(dateStr) {
  if (!dateStr) return '-';
  return new Date(dateStr).toLocaleDateString('af-ZA', { year: 'numeric', month: 'short', day: 'numeric' });
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
  const [aiActive, setAiActive] = useState(null);

  useEffect(() => {
    apiClient.ai.getStatus()
      .then((r) => setAiActive(r.data?.ai_enabled ?? false))
      .catch(() => setAiActive(false));
  }, []);

  const { sorts, addSort, removeSort, toggleDirection, moveSort, clearSorts, applySort } = useColumnSort({
    columns: DRAFT_COLUMNS,
    storageKey: 'ai-draft-queue',
  });
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
      showToast({ type: 'error', title: 'Fout', message: "Fout by laai van voorgestelde werksopdragte: " + (error.response?.data?.detail || error.message) });
    } finally {
      setLoading(false);
    }
  };

  const sortedDrafts = applySort([...drafts], (d, key) => {
    switch (key) {
      case 'id': return Number(d.draft_id || 0);
      case 'title': return String(d.title || d.description || '');
      case 'asset': return String(d.resolved_asset_name || '');
      case 'type': return String(d.suggested_type || '');
      case 'priority': return String(d.suggested_priority || '');
      case 'source': return String(d.source || '');
      case 'date': return d.created_at ? new Date(d.created_at).getTime() : 0;
      default: return '';
    }
  });
  const { currentPage, totalPages, paginatedData: paginatedDrafts, goToPage } = usePagination(sortedDrafts, 100);
  useEffect(() => { goToPage(1); }, [statusFilter, sorts, goToPage]);

  if (loading) {
    return <div className="main"><div className="content">Laai...</div></div>;
  }

  return (
    <div className="main">
      <div className="content">
        {aiActive !== null && (
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: '6px',
            marginBottom: '0.5rem', padding: '4px 10px', borderRadius: '4px',
            fontSize: '12px', fontWeight: 'bold',
            backgroundColor: aiActive ? '#d4edda' : '#f8d7da',
            color: aiActive ? '#155724' : '#721c24',
          }}>
            <span style={{ fontSize: '10px' }}>{aiActive ? '🟢' : '🔴'}</span>
            AI: {aiActive ? 'Aktief' : 'Inaktief'}
          </div>
        )}
        <div className="controls controls--sticky controls--with-tabs">
          <div className="controls-left">
            <Select className="react-select-container" classNamePrefix="react-select" value={[{ value: "", label: "Alle" }, { value: "draft", label: "Konsepte" }, { value: "approved", label: "Goedgekeur" }, { value: "rejected", label: "Afgewys" }].find((option) => option.value === statusFilter)} onChange={(selected) => setStatusFilter(selected?.value || "")} options={[{ value: "", label: "Alle" }, { value: "draft", label: "Konsepte" }, { value: "approved", label: "Goedgekeur" }, { value: "rejected", label: "Afgewys" }]} isSearchable={false} />
          <SortPicker
              columns={DRAFT_COLUMNS}
              sorts={sorts}
              onAdd={addSort}
              onRemove={removeSort}
              onToggleDirection={toggleDirection}
              onMove={moveSort}
              onClear={clearSorts}
            />
            <ColumnPicker
              ref={colPickerRef}
              columns={DRAFT_COLUMNS}
              visibleColumns={colVis.visibleColumns}
              toggleColumn={colVis.toggleColumn}
              resetVisibility={colVis.resetVisibility}
              onResetWidths={colWidths.resetWidths}
            />
          </div>
          <div className="controls-right">
            <button className="btn-add" onClick={() => navigate('/ai-drafts/new')}>+ Nuwe Voorgestelde Werksopdrag</button>
            <button className="btn-edit" onClick={fetchDrafts} style={{ marginLeft: '0.5rem' }}>Vernuwe</button>
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
                  onContextMenu={(e) => colPickerRef.current?.openAt(e)}
                >
                  {col.label}
                </ResizableTh>
              ))}
              <th style={{ width: '130px' }}>Aksies</th>
            </tr>
          </thead>
          <tbody>
            {sortedDrafts.length === 0 ? (
              <tr><td colSpan={colVis.visibleColumns.length + 1} style={{ textAlign: 'center', padding: '20px' }}>Geen voorgestelde werksopdragte gevind nie</td></tr>
            ) : (
              paginatedDrafts.map((draft) => (
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
      <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} totalItems={sortedDrafts.length} pageSize={100} />
      </div>
    </div>
  );
}

export default AIDraftQueuePage;