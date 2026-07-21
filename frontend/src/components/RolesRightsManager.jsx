import React, { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../services/api';

/**
 * RolesRightsManager - Modal om rolle en regte te bestuur (admin-alleen).
 *
 * Wys twee oortjies: "Rolle" en "Regte". Ingeboude rolle/regte word beskerm
 * (naam kan nie verander word nie, en hulle kan nie verwyder word nie) — die
 * backend dwing dit ook af met 403. Regte word aan rolle toegeken via 'n
 * merkblokkie-lys; die backend maak die regte-kas skoon sodat veranderinge
 * onmiddellik geld.
 *
 * Props:
 *  - onClose():    maak die modal toe
 *  - onChanged():  geroep na enige verandering (bv. sodat die Gebruikers-bladsy
 *                  se rol-keuselys kan verfris)
 */
const errBox = { color: '#dc3545', padding: '10px', marginBottom: '10px', backgroundColor: '#f8d7da', borderRadius: '4px' };
const okBox = { color: '#155724', padding: '10px', marginBottom: '10px', backgroundColor: '#d4edda', borderRadius: '4px' };

function RolesRightsManager({ onClose, onChanged }) {
  const [tab, setTab] = useState('roles');       // 'roles' | 'rights'
  const [view, setView] = useState('list');      // 'list' | 'roleForm' | 'rightForm'
  const [roles, setRoles] = useState([]);
  const [rights, setRights] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [roleForm, setRoleForm] = useState({ id: null, name: '', isBuiltin: false, rightIds: [] });
  const [rightForm, setRightForm] = useState({ id: null, name: '', description: '', isBuiltin: false });

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

  const notifyChanged = () => { if (onChanged) onChanged(); };

  // ----- Rol-vorm -----
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
      await refetch(); notifyChanged();
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
      await refetch(); notifyChanged();
      setSuccess('Rol verwyder.');
    } catch (err) {
      setError(err.response?.data?.detail || 'Kon nie rol verwyder nie.');
    }
  };

  // ----- Reg-vorm -----
  const openNewRight = () => { setRightForm({ id: null, name: '', description: '', isBuiltin: false }); setError(''); setSuccess(''); setView('rightForm'); };
  const openEditRight = (right) => { setRightForm({ id: right.right_id, name: right.right_name, description: right.right_description || '', isBuiltin: right.is_builtin }); setError(''); setSuccess(''); setView('rightForm'); };

  const saveRight = async () => {
    setError(''); setSuccess('');
    if (!rightForm.name.trim()) { setError('Regnaam is verpligtend.'); return; }
    try {
      if (rightForm.id) {
        await apiClient.rights.update(rightForm.id, { right_name: rightForm.name.trim(), right_description: rightForm.description });
      } else {
        await apiClient.rights.create({ right_name: rightForm.name.trim(), right_description: rightForm.description });
      }
      await refetch(); notifyChanged();
      setView('list'); setSuccess('Reg gestoor.');
    } catch (err) {
      setError(err.response?.data?.detail || 'Kon nie reg stoor nie.');
    }
  };

  const deleteRight = async (right) => {
    if (!window.confirm(`Verwyder reg "${right.right_name}"?`)) return;
    setError(''); setSuccess('');
    try {
      await apiClient.rights.delete(right.right_id);
      await refetch(); notifyChanged();
      setSuccess('Reg verwyder.');
    } catch (err) {
      setError(err.response?.data?.detail || 'Kon nie reg verwyder nie.');
    }
  };

  const backToList = () => { setView('list'); setError(''); };

  return (
    <div className="modal">
      <div className="modal-content" style={{ maxWidth: '760px', width: '92%' }}>
        <div className="modal-header">
          <h3>Rolle & Regte Bestuur</h3>
          <span className="close" onClick={onClose}>&times;</span>
        </div>

        {error && <div style={errBox}>{error}</div>}
        {success && <div style={okBox}>{success}</div>}

        {loading ? (
          <p>Besig om te laai...</p>
        ) : view === 'list' ? (
          <>
            <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem', alignItems: 'center' }}>
              <button type="button" className="btn-add" style={{ background: tab === 'roles' ? '#935e28' : undefined }} onClick={() => { setTab('roles'); setSuccess(''); }}>Rolle</button>
              <button type="button" className="btn-add" style={{ background: tab === 'rights' ? '#935e28' : undefined }} onClick={() => { setTab('rights'); setSuccess(''); }}>Regte</button>
              <div style={{ flex: 1 }} />
              {tab === 'roles'
                ? <button type="button" className="btn-add" onClick={openNewRole}>+ Nuwe Rol</button>
                : <button type="button" className="btn-add" onClick={openNewRight}>+ Nuwe Reg</button>}
            </div>

            {tab === 'roles' ? (
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
            ) : (
              <table className="standard-table">
                <thead>
                  <tr><th>Naam</th><th>Beskrywing</th><th>Tipe</th><th>Aksies</th></tr>
                </thead>
                <tbody>
                  {rights.map(right => (
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
                  ))}
                </tbody>
              </table>
            )}
          </>
        ) : view === 'roleForm' ? (
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
        ) : (
          <div>
            <div className="form-group">
              <label>Regnaam *</label>
              <input
                type="text"
                value={rightForm.name}
                onChange={(e) => setRightForm(f => ({ ...f, name: e.target.value }))}
                placeholder="bv. reports.export"
              />
            </div>
            <div className="form-group">
              <label>Beskrywing</label>
              <input
                type="text"
                value={rightForm.description}
                onChange={(e) => setRightForm(f => ({ ...f, description: e.target.value }))}
              />
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={backToList}>Terug</button>
              <button className="btn-add" onClick={saveRight}>Stoor</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default RolesRightsManager;
