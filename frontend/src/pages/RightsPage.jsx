import React, { useState, useEffect, useCallback } from 'react';
import usePagination from "../hooks/usePagination";
import Pagination from "../components/Pagination/Pagination";
import { apiClient } from '../services/api';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import { useToast } from '../components/Toast/useToast';
import FilterPicker from "../components/ColumnPicker/FilterPicker";


function RightsPage({ embedded = false }) {
  const { confirm, dialog } = useConfirmDialog();
  const { showToast } = useToast();
  const [view, setView] = useState('list');
  const [rights, setRights] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterColumn, setFilterColumn] = useState('all');


  const [rightForm, setRightForm] = useState({ id: null, name: '', description: '', isBuiltin: false });

  const refetch = useCallback(async () => {
    try {
      const res = await apiClient.rights.getAll();
      setRights(res.data);
    } catch (err) {
      showToast({ type: 'error', message: err.response?.data?.detail || 'Kon nie regte laai nie.' });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { refetch(); }, [refetch]);

  const openEditRight = (right) => { setRightForm({ id: right.right_id, name: right.right_name, description: right.right_description || '', isBuiltin: right.is_builtin }); setView('rightForm'); };

  const saveRight = async () => {
    if (!rightForm.name.trim()) { showToast({ type: 'error', message: 'Regnaam is verpligtend.' }); return; }
    try {
      await apiClient.rights.update(rightForm.id, { right_name: rightForm.name.trim(), right_description: rightForm.description });
      await refetch();
      setView('list'); showToast({ type: 'success', message: 'Reg gestoor.' });
    } catch (err) {
      showToast({ type: 'error', message: err.response?.data?.detail || 'Kon nie reg stoor nie.' });
    }
  };

  const deleteRight = async (right) => {
    const confirmed = await confirm({ message: `Verwyder reg "${right.right_name}"?`, variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;
    try {
      await apiClient.rights.delete(right.right_id);
      await refetch();
      showToast({ type: 'success', message: 'Reg verwyder.' });
    } catch (err) {
      showToast({ type: 'error', message: err.response?.data?.detail || 'Kon nie reg verwyder nie.' });
    }
  };

  const backToList = () => { setView('list'); };

  const FILTER_COLUMNS = [
    { value: 'all', label: 'Alle kolomme' },
    { value: 'name', label: 'Naam' },
    { value: 'description', label: 'Beskrywing' },
    { value: 'type', label: 'Tipe' },
  ];

  const filteredRights = [...rights].filter(right => {
    const query = searchTerm.trim().toLowerCase();
    if (!query) return true;
    const values = {
      name: right.right_name,
      description: right.right_description,
      type: right.is_builtin ? 'Ingebou' : 'Pasgemaak',
    };
    return filterColumn === 'all'
      ? Object.values(values).some((value) => String(value || '').toLowerCase().includes(query))
      : String(values[filterColumn] || '').toLowerCase().includes(query);
  });
  const { currentPage, totalPages, paginatedData: paginatedRights, goToPage } = usePagination(filteredRights, 100);
  useEffect(() => { goToPage(1); }, [searchTerm, filterColumn, goToPage]);

  if (loading) return <div className="main"><div className="content">Besig om te laai...</div></div>;

  const pageContent = (
    <>

      {view === 'list' ? (
        <>
          <div className="controls controls--sticky">
            <div className="controls-left">
              <div className="control-input-shell">
                <input
                  type="text"
                  placeholder="Soek regte..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <FilterPicker
                search={searchTerm}
                onSearch={setSearchTerm}
                filterColumn={filterColumn}
                onFilterColumnChange={setFilterColumn}
                filterColumnOptions={FILTER_COLUMNS}
                onReset={() => setSearchTerm("")}
              />
            </div>
            <div className="controls-right">
            </div>
          </div>

          <table className="standard-table">
            <thead>
              <tr><th>Naam</th><th>Beskrywing</th><th>Tipe</th><th>Aksies</th></tr>
            </thead>
            <tbody>
              {filteredRights.length === 0 ? (
                <tr><td colSpan={4} style={{ textAlign: 'center', padding: '20px' }}>Geen regte gevind nie</td></tr>
              ) : (
                paginatedRights.map(right => (
                  <tr key={right.right_id}>
                    <td>{right.right_name}</td>
                    <td>{right.right_description}</td>
                    <td>{right.is_builtin ? 'Ingebou' : 'Pasgemaak'}</td>
                    <td>
                      {right.is_builtin ? (
                        <span style={{ color: '#888' }}>Beskerm</span>
                      ) : (
                        <>
                          <button className="btn-edit" onClick={() => openEditRight(right)}>Wysig</button>
                          <button className="btn-delete" onClick={() => deleteRight(right)} style={{ marginLeft: '5px', backgroundColor: '#dc3545' }}>Verwyder</button>
                        </>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
      <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} totalItems={filteredRights.length} pageSize={100} />
        </>
      ) : (
        <div>
          <div className="input-row">
            <div className="input-group">
              <label>Regnaam *</label>
              <input
                type="text"
                value={rightForm.name}
                onChange={(e) => setRightForm(f => ({ ...f, name: e.target.value }))}
                placeholder="bv. reports.export"
              />
            </div>
            <div className="input-group">
              <label>Beskrywing</label>
              <input
                type="text"
                value={rightForm.description}
                onChange={(e) => setRightForm(f => ({ ...f, description: e.target.value }))}
              />
            </div>
          </div>
          <div className="modal-footer">
            <button className="btn-cancel" onClick={backToList}>Terug</button>
            <button className="btn-add" onClick={saveRight}>Stoor</button>
          </div>
        </div>
      )}
    </>
  );

  if (embedded) {
    return <>{pageContent}{dialog}</>;
  }

  return (
    <div className="main">
      <div className="content">
        {pageContent}
      </div>
      {dialog}
    </div>
  );
}

export default RightsPage;
