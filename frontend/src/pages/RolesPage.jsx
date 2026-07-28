import React, { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../services/api';

const errBox = { color: '#dc3545', padding: '10px', marginBottom: '10px', backgroundColor: '#f8d7da', borderRadius: '4px' };
const okBox = { color: '#155724', padding: '10px', marginBottom: '10px', backgroundColor: '#d4edda', borderRadius: '4px' };

function RolesPage({ embedded = false }) {
  const [view, setView] = useState('list');
  const [roles, setRoles] = useState([]);
  const [rights, setRights] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [roleForm, setRoleForm] = useState({ id: null, name: '', isBuiltin: false, rightIds: [] });

  const refetch = useCallback(async () => {
    try {
      const [rolesRes, rightsRes] = await Promise.all([apiClient.roles.getAll(), apiClient.rights.getAll()]);
      setRoles(rolesRes.data);
      setRights(rightsRes.data);
    } catch (err) {
      setError(err.response?.data?.detail || 'Kon nie rolle/regte laai nie.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { refetch(); }, [refetch]);

  const openNewRole = () => { setRoleForm({ id: null, name: '', isBuiltin: false, rightIds: [] }); setError(''); setSuccess(''); setView('roleForm'); };
  const openEditRole = (role) => { setRoleForm({ id: role.role_id, name: role.role_name, isBuiltin: role.is_builtin, rightIds: role.right_ids || [] }); setError(''); setSuccess(''); setView('roleForm'); };
  const toggleRight = (id) => setRoleForm(f => ({
    ...f,
    rightIds: f.rightIds.includes(id) ? f.rightIds.filter(x => x !== id) : [...f.rightIds, id],
  }));

  const saveRole = async () => {
    setError(''); setSuccess('');
    if (!roleForm.name.trim()) { setError('Rolnaam is verpligtend.'); return; }
    try {
      if (roleForm.id) {
        const payload = { right_ids: roleForm.rightIds };
        if (!roleForm.isBuiltin) payload.role_name = roleForm.name.trim();
        await apiClient.roles.update(roleForm.id, payload);
      } else {
        await apiClient.roles.create({ role_name: roleForm.name.trim(), right_ids: roleForm.rightIds });
      }
      await refetch();
      setView('list'); setSuccess('Rol gestoor.');
    } catch (err) {
      setError(err.response?.data?.detail || 'Kon nie rol stoor nie.');
    }
  };

  const deleteRole = async (role) => {
    if (!window.confirm(`Verwyder rol "${role.role_name}"?`)) return;
    setError(''); setSuccess('');
    try {
      await apiClient.roles.delete(role.role_id);
      await refetch();
      setSuccess('Rol verwyder.');
    } catch (err) {
      setError(err.response?.data?.detail || 'Kon nie rol verwyder nie.');
    }
  };

  const backToList = () => { setView('list'); setError(''); };

  if (loading) return <div className="main"><div className="content">Besig om te laai...</div></div>;

  const pageContent = (
    <>
      {error && <div style={errBox}>{error}</div>}
      {success && <div style={okBox}>{success}</div>}

      {view === 'list' ? (
        <>
          <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem', alignItems: 'center' }}>
            <div style={{ flex: 1 }} />
            <button type="button" className="btn-add" onClick={openNewRole}>+ Nuwe Rol</button>
          </div>

          <table className="standard-table">
            <thead>
              <tr><th>Naam</th><th>Aantal regte</th><th>Tipe</th><th>Aksies</th></tr>
            </thead>
            <tbody>
              {roles.map(role => (
                <tr key={role.role_id}>
                  <td>{role.role_name}</td>
                  <td>{(role.right_ids || []).length}</td>
                  <td>{role.is_builtin ? 'Ingebou' : 'Pasgemaak'}</td>
                  <td>
                    <button className="btn-edit" onClick={() => openEditRole(role)}>Wysig</button>
                    {!role.is_builtin && (
                      <button className="btn-delete" onClick={() => deleteRole(role)} style={{ marginLeft: '5px', backgroundColor: '#dc3545' }}>Verwyder</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      ) : (
        <div>
          <div className="form-group">
            <label>Rolnaam *</label>
            <input
              type="text"
              value={roleForm.name}
              disabled={roleForm.isBuiltin}
              onChange={(e) => setRoleForm(f => ({ ...f, name: e.target.value }))}
            />
            {roleForm.isBuiltin && (
              <small style={{ color: '#888' }}>Ingeboude rolname kan nie verander word nie; jy kan wel die regte hieronder aanpas.</small>
            )}
          </div>
          <div className="form-group">
            <label>Regte</label>
            <div style={{ maxHeight: '260px', overflowY: 'auto', border: '1px solid #ddd', borderRadius: '4px', padding: '8px' }}>
              {rights.map(right => (
                <label key={right.right_id} style={{ display: 'block', fontWeight: 'normal', marginBottom: '4px' }}>
                  <input
                    type="checkbox"
                    checked={roleForm.rightIds.includes(right.right_id)}
                    onChange={() => toggleRight(right.right_id)}
                  />
                  {' '}{right.right_name}
                  {right.right_description ? <span style={{ color: '#888', fontSize: '12px' }}> — {right.right_description}</span> : null}
                </label>
              ))}
            </div>
          </div>
          <div className="modal-footer">
            <button className="btn-cancel" onClick={backToList}>Terug</button>
            <button className="btn-add" onClick={saveRole}>Stoor</button>
          </div>
        </div>
      )}
    </>
  );

  if (embedded) {
    return <>{pageContent}</>;
  }

  return (
    <div className="main">
      <div className="content">
        {pageContent}
      </div>
    </div>
  );
}

export default RolesPage;
