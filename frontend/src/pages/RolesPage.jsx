import React, { useState, useEffect, useCallback } from 'react';
import usePagination from "../hooks/usePagination";
import Pagination from "../components/Pagination/Pagination";
import Select from 'react-select';
import { IoPencil } from 'react-icons/io5';
import { apiClient } from '../services/api';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import { useToast } from '../components/Toast/useToast';
import { useCurrentUser } from '../hooks/useCurrentUser';


function RolesPage({ embedded = false }) {
  const { confirm, dialog } = useConfirmDialog();
  const { showToast } = useToast();
  const { isAdmin } = useCurrentUser();
  const [roles, setRoles] = useState([]);
  const [rights, setRights] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterColumn, setFilterColumn] = useState('all');
  const [showModal, setShowModal] = useState(false);
  const [isViewMode, setIsViewMode] = useState(true);


  const [roleForm, setRoleForm] = useState({ id: null, name: '', isBuiltin: false, rightIds: [] });

  const refetch = useCallback(async () => {
    try {
      const [rolesRes, rightsRes] = await Promise.all([apiClient.roles.getAll(), apiClient.rights.getAll()]);
      setRoles(rolesRes.data);
      setRights(rightsRes.data);
    } catch (err) {
      showToast({ type: 'error', message: err.response?.data?.detail || 'Kon nie rolle/regte laai nie.' });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { refetch(); }, [refetch]);

  const openNewRole = () => { setRoleForm({ id: null, name: '', isBuiltin: false, rightIds: [] }); setIsViewMode(false); setShowModal(true); };
  const openEditRole = (role) => { setRoleForm({ id: role.role_id, name: role.role_name, isBuiltin: role.is_builtin, rightIds: role.right_ids || [] }); setIsViewMode(true); setShowModal(true); };
  const handleCloseModal = () => { setShowModal(false); };
  const toggleRight = (id) => setRoleForm(f => ({
    ...f,
    rightIds: f.rightIds.includes(id) ? f.rightIds.filter(x => x !== id) : [...f.rightIds, id],
  }));

  const saveRole = async () => {
    if (!roleForm.name.trim()) { showToast({ type: 'error', message: 'Rolnaam is verpligtend.' }); return; }
    try {
      if (roleForm.id) {
        const payload = { right_ids: roleForm.rightIds };
        if (!roleForm.isBuiltin) payload.role_name = roleForm.name.trim();
        await apiClient.roles.update(roleForm.id, payload);
      } else {
        await apiClient.roles.create({ role_name: roleForm.name.trim(), right_ids: roleForm.rightIds });
      }
      await refetch();
      handleCloseModal(); showToast({ type: 'success', message: 'Rol gestoor.' });
    } catch (err) {
      showToast({ type: 'error', message: err.response?.data?.detail || 'Kon nie rol stoor nie.' });
    }
  };

  const deleteRole = async (role) => {
    const confirmed = await confirm({ message: `Verwyder rol "${role.role_name}"?`, variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;
    try {
      await apiClient.roles.delete(role.role_id);
      await refetch();
      showToast({ type: 'success', message: 'Rol verwyder.' });
    } catch (err) {
      showToast({ type: 'error', message: err.response?.data?.detail || 'Kon nie rol verwyder nie.' });
    }
  };

  const FILTER_COLUMNS = [
    { value: 'all', label: 'Alle kolomme' },
    { value: 'name', label: 'Naam' },
    { value: 'type', label: 'Tipe' },
  ];

  const filteredRoles = [...roles].filter(role => {
    const query = searchTerm.trim().toLowerCase();
    if (!query) return true;
    const values = {
      name: role.role_name,
      type: role.is_builtin ? 'Ingebou' : 'Pasgemaak',
    };
    return filterColumn === 'all'
      ? Object.values(values).some((value) => String(value || '').toLowerCase().includes(query))
      : String(values[filterColumn] || '').toLowerCase().includes(query);
  });
  const { currentPage, totalPages, paginatedData: paginatedRoles, goToPage } = usePagination(filteredRoles, 100);
  useEffect(() => { goToPage(1); }, [searchTerm, filterColumn, goToPage]);

  if (loading) return <div className="main"><div className="content">Besig om te laai...</div></div>;

  const pageContent = (
    <>
      <div className="controls controls--sticky">
        <div className="controls-left">
          <div className="control-input-shell">
            <input
              type="text"
              placeholder="Soek rolle..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <Select className="react-select-container" classNamePrefix="react-select" value={FILTER_COLUMNS.find((option) => option.value === filterColumn)} onChange={(selected) => setFilterColumn(selected?.value || "all")} options={FILTER_COLUMNS} isSearchable={false} />
        </div>
        <div className="controls-right">
          <button type="button" className="btn-add" onClick={openNewRole}>+ Nuwe Rol</button>
        </div>
      </div>

      <table className="standard-table">
        <thead>
          <tr><th>Naam</th><th>Aantal regte</th><th>Tipe</th><th>Aksies</th></tr>
        </thead>
        <tbody>
          {filteredRoles.length === 0 ? (
            <tr><td colSpan={4} style={{ textAlign: 'center', padding: '20px' }}>Geen rolle gevind nie</td></tr>
          ) : (
            paginatedRoles.map(role => (
              <tr key={role.role_id} onClick={() => openEditRole(role)} style={{ cursor: "pointer" }}>
                <td>{role.role_name}</td>
                <td>{(role.right_ids || []).length}</td>
                <td>{role.is_builtin ? 'Ingebou' : 'Pasgemaak'}</td>
                <td onClick={(e) => e.stopPropagation()}>
                  {!role.is_builtin && (
                    <button className="btn-delete" onClick={() => deleteRole(role)} style={{ marginLeft: '5px', backgroundColor: '#dc3545' }}>Verwyder</button>
                  )}
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
      <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} totalItems={filteredRoles.length} pageSize={100} />
    </>
  );

  const modalContent = showModal && (
    <div className="modal" style={{ display: "flex" }} onClick={(e) => { if (e.target === e.currentTarget && isViewMode) handleCloseModal(); }}>
      <div className="modal-content">
        <div className="modal-header">
          <h3>{isViewMode ? 'Bekyk' : roleForm.id ? 'Wysig' : 'Nuwe'} Rol</h3>
          <div className="modal-header-actions">
            {roleForm.id && isViewMode && (isAdmin || roleForm.id !== 3) && (
              <IoPencil size={20} className="modal-edit-btn" onClick={() => setIsViewMode(false)} title="Wysig" />
            )}
            <span className="close" onClick={handleCloseModal}>&times;</span>
          </div>
        </div>

        <div className="input-row">
          <div className="input-group">
            <label>Rolnaam *</label>
            <input
              type="text"
              value={roleForm.name}
              disabled={isViewMode || roleForm.isBuiltin}
              onChange={(e) => setRoleForm(f => ({ ...f, name: e.target.value }))}
            />
          </div>
        </div>
        {roleForm.isBuiltin && (
          <div style={{ margin: '0 20px' }}>
            <small style={{ color: '#888' }}>Ingeboude rolname kan nie verander word nie; jy kan wel die regte hieronder aanpas.</small>
          </div>
        )}
        <div className="input-group" style={{ margin: '0 20px', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          <label>Regte</label>
          <div style={{ flex: 1, overflowY: 'auto', border: '1px solid #ddd', borderRadius: '4px', padding: '8px' }}>
            {rights.map(right => (
              <label key={right.right_id} style={{ display: 'block', fontWeight: 'normal', marginBottom: '4px' }}>
                <input
                  type="checkbox"
                  checked={roleForm.rightIds.includes(right.right_id)}
                  disabled={isViewMode || (roleForm.id === 3 && !isAdmin)}
                  onChange={() => toggleRight(right.right_id)}
                />
                {' '}{right.right_name}
                {right.right_description ? <span style={{ color: '#888', fontSize: '12px' }}> — {right.right_description}</span> : null}
              </label>
            ))}
          </div>
        </div>
        {!isViewMode && (
          <div className="modal-footer">
            <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
            <button className="btn-add" onClick={saveRole}>Stoor</button>
          </div>
        )}
      </div>
    </div>
  );

  if (embedded) {
    return <>{pageContent}{modalContent}{dialog}</>;
  }

  return (
    <div className="main">
      <div className="content">
        {pageContent}
        {modalContent}
      </div>
      {dialog}
    </div>
  );
}

export default RolesPage;
