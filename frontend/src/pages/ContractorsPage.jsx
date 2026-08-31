import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { contractorsAPI } from '../services/api';
import { useCurrentUser } from '../hooks/useCurrentUser';
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import UserProfileHeader from '../components/UserProfileHeader';
import '../styles/App.css';

function ContractorsPage() {
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();

  const [contractors, setContractors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterColumn, setFilterColumn] = useState('all');
  const [sortBy, setSortBy] = useState('default');
  const [sortDirection, setSortDirection] = useState('asc');
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [formData, setFormData] = useState({
    contractor_businessName: '',
    contractor_name: '',
    contractor_surname: '',
    contractor_email: '',
    contractor_number: '',
    contractor_type: '',
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    fetchContractors();
  }, []);

  const fetchContractors = async () => {
    setLoading(true);
    try {
      const response = await contractorsAPI.getAll();
      setContractors(response.data || []);
    } catch (fetchError) {
      console.error('Fout by haal kontrakteurs:', fetchError);
    } finally {
      setLoading(false);
    }
  };

  const handleNewContractor = () => {
    setIsEditing(false);
    setEditingId(null);
    setFormData({
      contractor_businessName: '',
      contractor_name: '',
      contractor_surname: '',
      contractor_email: '',
      contractor_number: '',
      contractor_type: '',
    });
    setError('');
    setSuccess('');
    setShowModal(true);
  };

  const handleEditContractor = (contractor) => {
    setIsEditing(true);
    setEditingId(contractor.contractor_id);
    setFormData({
      contractor_businessName: contractor.contractor_businessName || '',
      contractor_name: contractor.contractor_name || '',
      contractor_surname: contractor.contractor_surname || '',
      contractor_email: contractor.contractor_email || '',
      contractor_number: contractor.contractor_number || '',
      contractor_type: contractor.contractor_type || '',
    });
    setError('');
    setSuccess('');
    setShowModal(true);
  };

  const handleDeleteContractor = async (contractorId) => {
    if (!window.confirm('Is jy seker jy wil hierdie kontrakteur verwyder?')) {
      return;
    }

    try {
      await contractorsAPI.delete(contractorId);
      fetchContractors();
    } catch (deleteError) {
      console.error('Fout by verwydering:', deleteError);
      alert('Fout tydens verwydering. Probeer asseblief weer.');
    }
  };

  const formatApiError = (errorDetail) => {
    if (!errorDetail) return '';
    if (typeof errorDetail === 'string') return errorDetail;
    if (Array.isArray(errorDetail)) {
      return errorDetail
        .map((item) => formatApiError(item))
        .filter(Boolean)
        .join(' | ');
    }
    if (typeof errorDetail === 'object') {
      if ('loc' in errorDetail && Array.isArray(errorDetail.loc) && 'msg' in errorDetail) {
        return `${errorDetail.loc.join('.')}: ${errorDetail.msg}`;
      }
      if ('msg' in errorDetail && typeof errorDetail.msg === 'string') {
        return errorDetail.msg;
      }
      if ('message' in errorDetail && typeof errorDetail.message === 'string') {
        return errorDetail.message;
      }
      return Object.entries(errorDetail)
        .map(([key, value]) => `${key}: ${formatApiError(value)}`)
        .filter(Boolean)
        .join(' | ');
    }
    return String(errorDetail);
  };

  const handleSaveContractor = async () => {
    setError('');
    setSuccess('');

    if (!formData.contractor_businessName?.trim() || !formData.contractor_name?.trim() || !formData.contractor_surname?.trim() || !formData.contractor_email?.trim()) {
      setError('Besigheid, naam, van, en e-pos is vereis');
      return;
    }

    const payload = {
      contractor_businessName: formData.contractor_businessName.trim(),
      contractor_name: formData.contractor_name.trim(),
      contractor_surname: formData.contractor_surname.trim(),
      contractor_email: formData.contractor_email.trim(),
      contractor_number: formData.contractor_number?.trim() || null,
      contractor_type: formData.contractor_type?.trim() || null,
    };

    try {
      if (isEditing && editingId) {
        await contractorsAPI.update(editingId, payload);
        setSuccess('Kontrakteur suksesvol opgedateer');
      } else {
        await contractorsAPI.create(payload);
        setSuccess('Kontrakteur suksesvol geskep');
      }
      fetchContractors();
      setShowModal(false);
    } catch (saveError) {
      console.error('Fout by stoor kontrakteur:', saveError);
      const detail = saveError.response?.data?.detail ?? saveError.response?.data ?? saveError.message;
      const message = formatApiError(detail) || 'Fout by die stoor van kontrakteur';
      setError(message);
    }
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setFormData({
      contractor_businessName: '',
      contractor_name: '',
      contractor_surname: '',
      contractor_email: '',
      contractor_number: '',
      contractor_type: '',
    });
    setError('');
    setSuccess('');
  };

  const filteredContractors = [...contractors]
    .filter((contractor) => {
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        id: contractor.contractor_id,
        name: contractor.contractor_businessName,
        name: contractor.contractor_name,
        surname: contractor.contractor_surname,
        email: contractor.contractor_email,
        number: contractor.contractor_number,
        type: contractor.contractor_type,
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'businessName') return String(a.contractor_businessName || '').localeCompare(String(b.contractor_businessName || ''), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'name') return String(a.contractor_name || '').localeCompare(String(b.contractor_name || ''), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'surname') return String(a.contractor_surname || '').localeCompare(String(b.contractor_surname || ''), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'id') return (Number(a.contractor_id || 0) - Number(b.contractor_id || 0)) * direction;
      return 0;
    });

  if (loading) {
    return (
      <div style={{ display: 'flex' }}>
        <div className="main">
          <div className="content">Laai kontrakteurs...</div>
        </div>
      </div>
    );
  }

  return (
    <div >
      <Sidebar currentPath="/contractors" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Kontrakteurs</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          <div className="controls">
            <div className="controls-left">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <input
                  type="text"
                  className="search-box"
                  placeholder="Soek kontrakteur..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <select value={filterColumn} onChange={(e) => setFilterColumn(e.target.value)}>
                <option value="all">Alle kolomme</option>
                <option value="id">ID</option>
                <option value="businessName">Besigheid</option>
                <option value="name">Naam</option>
                <option value="surname">Van</option>
                <option value="email">E-pos</option>
                <option value="number">Tel</option>
                <option value="type">Tipe</option>
              </select>
            </div>
            <div className="controls-right">
              <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
                <option value="default">Standaard</option>
                <option value="id">ID</option>
                <option value="businessName">Besigheid</option>
                <option value="name">Naam</option>
                <option value="surname">Van</option>
              </select>
              <div style={{ display: 'flex', gap: '0.25rem' }}>
                <button type="button" className="btn-add" onClick={() => setSortDirection('asc')} style={{ minWidth: '40px', background: sortDirection === 'asc' ? '#935e28' : undefined }} title="Stygend">▲</button>
                <button type="button" className="btn-add" onClick={() => setSortDirection('desc')} style={{ minWidth: '40px', background: sortDirection === 'desc' ? '#935e28' : undefined }} title="Dalend">▼</button>
              </div>
              <button type="button" className="btn-add" onClick={handleNewContractor}>+ Nuwe Kontrakteur</button>
            </div>
          </div>

          
            <table className="standard-table">
                <thead>
                <tr>
                    <th>ID</th>
                    <th>Besigheid</th>
                    <th>Naam</th>
                    <th>Van</th>
                    <th>E-pos</th>
                    <th>Tel</th>
                    <th>Tipe</th>
                    <th>Aksies</th>
                </tr>
                </thead>
                <tbody>
                {filteredContractors.length === 0 ? (
                    <tr>
                    <td colSpan="7" style={{ textAlign: 'center', padding: '20px' }}>Geen kontrakteurs gevind nie</td>
                    </tr>
                ) : (
                    filteredContractors.map((contractor) => (
                    <tr key={contractor.contractor_id}>
                        <td>{contractor.contractor_id ?? '-'}</td>
                        <td>{contractor.contractor_businessName || '-'}</td>
                        <td>{contractor.contractor_name || '-'}</td>
                        <td>{contractor.contractor_surname || '-'}</td>
                        <td>{contractor.contractor_email || '-'}</td>
                        <td>{contractor.contractor_number || '-'}</td>
                        <td>{contractor.contractor_type || '-'}</td>
                        <td>
                        <button type="button" className="btn-edit" onClick={() => handleEditContractor(contractor)}>Wysig</button>
                        <button type="button" className="btn-delete" onClick={() => handleDeleteContractor(contractor.contractor_id)}>Verwyder</button>
                        </td>
                    </tr>
                    ))
                )}
                </tbody>
            </table>
            </div>

            {showModal && (
            <div className="modal">
                <div className="modal-content">
                <div className="modal-header">
                    <h3>{isEditing ? 'Wysig Kontrakteur' : 'Nuwe Kontrakteur'}</h3>
                    <span className="close" onClick={handleCloseModal}>&times;</span>
                </div>
                <div className="form-group">
                    <label>Besigheid</label>
                    <input type="text" value={formData.contractor_businessName} onChange={(e) => setFormData({ ...formData, contractor_businessName: e.target.value })} />
                </div>
                <div className="form-group">
                    <label>Naam</label>
                    <input type="text" value={formData.contractor_name} onChange={(e) => setFormData({ ...formData, contractor_name: e.target.value })} />
                </div>
                <div className="form-group">
                    <label>Van</label>
                    <input type="text" value={formData.contractor_surname} onChange={(e) => setFormData({ ...formData, contractor_surname: e.target.value })} />
                </div>
                <div className="form-group">
                    <label>E-pos</label>
                    <input type="email" value={formData.contractor_email} onChange={(e) => setFormData({ ...formData, contractor_email: e.target.value })} />
                </div>
                <div className="form-group">
                    <label>Telefoonnommer</label>
                    <input type="text" value={formData.contractor_number} onChange={(e) => setFormData({ ...formData, contractor_number: e.target.value })} />
                </div>
                <div className="form-group">
                    <label>Tipe</label>
                    <input type="text" value={formData.contractor_type} onChange={(e) => setFormData({ ...formData, contractor_type: e.target.value })} />
                </div>
                {error && <div className="alert alert-error">{error}</div>}
                {success && <div className="alert alert-success">{success}</div>}
                <div className="modal-footer">
                    <button type="button" className="btn-add" onClick={handleSaveContractor}>Stoor</button>
                    <button type="button" className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
                </div>
                </div>
            </div>
            )}
        
      </div>
    </div>
  );
}

export default ContractorsPage;
