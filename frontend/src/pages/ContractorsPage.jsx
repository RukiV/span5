import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { contractorsAPI } from '../services/api';
import { useCurrentUser } from '../hooks/useCurrentUser';
import { useLogout } from './Page.jsx';
import UserProfileHeader from '../components/UserProfileHeader';
import '../styles/App.css';

function ContractorsPage() {
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();

  const [contractors, setContractors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [formData, setFormData] = useState({
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

    if (!formData.contractor_name?.trim() || !formData.contractor_surname?.trim() || !formData.contractor_email?.trim()) {
      setError('Naam, van, en e-pos is vereis');
      return;
    }

    const payload = {
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
      contractor_name: '',
      contractor_surname: '',
      contractor_email: '',
      contractor_number: '',
      contractor_type: '',
    });
    setError('');
    setSuccess('');
  };

  const filteredContractors = contractors.filter((contractor) => {
    const query = searchTerm.toLowerCase();
    return (
      contractor.contractor_name?.toLowerCase().includes(query) ||
      contractor.contractor_surname?.toLowerCase().includes(query) ||
      contractor.contractor_email?.toLowerCase().includes(query) ||
      contractor.contractor_type?.toLowerCase().includes(query)
    );
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
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li className="dropdown" >
            <div className="dropdown-trigger"><span>Bates & Voorraad</span></div>
            <div className="dropdown-content">
              <Link to="/assets">Bates</Link>
              <Link to="/stock">Voorraad</Link>
            </div>
          </li>
          <li className="dropdown" >
            <div className="dropdown-trigger"><span>Lokale & Terreine</span></div>
            <div className="dropdown-content">
              <Link to="/rooms">Lokale</Link>
              <Link to="/terrains">Terreine</Link>
            </div>
          </li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          <li><Link to="/contractors" style={{ background: '#935e28' }}>Kontrakteurs</Link></li>
          <li><Link to="/calendar">Kalender</Link></li>
          <li><Link to="/analysis">Analise</Link></li>
          <li><Link to="/reports">Verslae</Link></li>
          {isAdmin && <li><Link to="/users">Gebruikers</Link></li>}
        </ul>
        <div className="logout-container">
          <button type="button" className="btn-logout-sidebar" onClick={() => logout()}>Teken Uit</button>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Kontrakteurs</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          <div className="controls">
            <input
              type="text"
              className="search-box"
              placeholder="Soek kontrakteur..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <button type="button" className="btn-add" onClick={handleNewContractor}>+ Nuwe Kontrakteur</button>
          </div>

          
            <table className="standard-table">
                <thead>
                <tr>
                    <th>ID</th>
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
