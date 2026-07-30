import React, { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../services/api';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import { useToast } from '../components/Toast/useToast';


function RightsPage({ embedded = false }) {
  const { confirm, dialog } = useConfirmDialog();
  const { showToast } = useToast();
  const [view, setView] = useState('list');
  const [rights, setRights] = useState([]);
  const [loading, setLoading] = useState(true);


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

  const openNewRight = () => { setRightForm({ id: null, name: '', description: '', isBuiltin: false }); setView('rightForm'); };
  const openEditRight = (right) => { setRightForm({ id: right.right_id, name: right.right_name, description: right.right_description || '', isBuiltin: right.is_builtin }); setView('rightForm'); };

  const saveRight = async () => {
    if (!rightForm.name.trim()) { showToast({ type: 'error', message: 'Regnaam is verpligtend.' }); return; }
    try {
      if (rightForm.id) {
        await apiClient.rights.update(rightForm.id, { right_name: rightForm.name.trim(), right_description: rightForm.description });
      } else {
        await apiClient.rights.create({ right_name: rightForm.name.trim(), right_description: rightForm.description });
      }
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

  if (loading) return <div className="main"><div className="content">Besig om te laai...</div></div>;

  const pageContent = (
    <>

      {view === 'list' ? (
        <>
          <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem', alignItems: 'center' }}>
            <div style={{ flex: 1 }} />
            <button type="button" className="btn-add" onClick={openNewRight}>+ Nuwe Reg</button>
          </div>

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
        </>
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
