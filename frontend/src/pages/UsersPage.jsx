import React, { useState, useEffect, useRef } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { apiClient } from '../services/api';
import '../styles/App.css';
import '../styles/Users.css';
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import UserProfileHeader from '../components/UserProfileHeader';

function UsersPage() {
  const navigate = useNavigate();
    const logout = useLogout();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filter, setFilter] = useState('almal');
  const [filterColumn, setFilterColumn] = useState('all');
  const [sortBy, setSortBy] = useState('default');
  const [sortDirection, setSortDirection] = useState('asc');
  const [showModal, setShowModal] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [isAuthorized, setIsAuthorized] = useState(false);
  const [formUser, setFormUser] = useState({
    user_name: '',
    user_surname: '',
    user_email: '',
    user_password: '',
    user_status: 'active',
    role_id: 1
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});

  const roles = [
    { id: 1, name: 'Gebruiker' },
    { id: 2, name: 'Fasiliteit Koördineerder' },
    { id: 3, name: 'Administrateur' }
  ];

  // Kontroleer of huidige gebruiker 'n Administrateur is
  // Slegs Administrateure (role_id=3) kan die Gebruikersblad sien
  useEffect(() => {
    const checkAuthorization = async () => {
      try {
        // Haal huidige gebruiker se inligting van backend
        const response = await apiClient.get('/auth/me');
        
        // Kontroleer of rol-ID 3 is (Administrateur)
        if (response.data.role_id === 3) {
          setIsAuthorized(true);
        } else {
          // As nie administrateur nie, magtig-status sal vals wees
          setIsAuthorized(false);
          // Navigeer terug na dashboard na 2 sekondes
          setTimeout(() => {
            navigate('/dashboard');
          }, 2000);
        }
      } catch (error) {
        console.error('Error checking authorization:', error);
        // As fout, navigeer na login-blad
        navigate('/login');
      }
    };

    checkAuthorization();
  }, [navigate]);

  // Haal almal gebruikers van backend wanneer magtiging bevestig is
  useEffect(() => {
    if (isAuthorized) {
      fetchUsers();
    }
  }, [isAuthorized]);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const response = await apiClient.users.getAll();
      setUsers(response.data);
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  // Hanteer toevoeging van nuwe gebruiker of opdatering van bestaande
  const handleAddUser = async () => {
    try {
      setError('');
      setSuccess('');

      // Valideer dat vereiste velde ingevul is
      const errors = {};
      if (!formUser.user_name?.trim()) errors.user_name = true;
      if (!formUser.user_surname?.trim()) errors.user_surname = true;
      if (!formUser.user_email?.trim()) errors.user_email = true;
      if (!editingUser && !formUser.user_password?.trim()) errors.user_password = true;
      if (!formUser.role_id) errors.role_id = true;
      if (!formUser.user_status) errors.user_status = true;
      if (Object.keys(errors).length > 0) {
        setInvalidFields(errors);
        setError('');
        const firstKey = Object.keys(errors)[0];
        fieldRefs.current[firstKey]?.scrollIntoView({ behavior: "smooth", block: "center" });
        fieldRefs.current[firstKey]?.focus();
        return;
      }
      setInvalidFields({});
      setError('');

      let dataToSend = { ...formUser };

      // Wanneer redigeer, stuur nie leë wagwoord (laat bestaande wagwoord onveranderd)
      if (editingUser && !formUser.user_password) {
        delete dataToSend.user_password;
      }

      // As ons redigeer, stuur PATCH-versoek, anders POST vir nuwe gebruiker
      if (editingUser) {
        await apiClient.users.update(editingUser.user_id, dataToSend);
        setSuccess('Gebruiker het succesvol opgedateer');
      } else {
        await apiClient.users.create(dataToSend);
        setSuccess('Gebruiker het suksesvol geskep');
      }

      // Sluit modale na 1.5 sekondes en herlaai gebruikerlys
      setTimeout(() => {
        setShowModal(false);
        setEditingUser(null);
        setFormUser({
          user_name: '',
          user_surname: '',
          user_email: '',
          user_password: '',
          user_status: 'active',
          role_id: 1
        });
        setSuccess('');
        fetchUsers();
      }, 1500);
    } catch (error) {
      console.error('Error saving user:', error);
      setError(error.response?.data?.detail || 'Fout by die opslaan van gebruiker');
    }
  };

  // Laai gebruiker-data in vorm vir redigering
  const handleEditUser = (user) => {
    setEditingUser(user);
    setFormUser({
      user_name: user.user_name,
      user_surname: user.user_surname || '',
      user_email: user.user_email,
      user_password: '', // Laat leeg sodat bestaande wagwoord nie oorskryf word
      user_status: user.user_status,
      role_id: user.role_id
    });
    setShowModal(true);
  };

  // Verwyder gebruiker na bevestiging
  const handleDeleteUser = async (userId) => {
    // Vra bevestiging voordat verwyder word
    if (window.confirm('Is jy seker jy wil hierdie gebruiker verwyder?')) {
      try {
        await apiClient.users.delete(userId);
        fetchUsers(); // Herlaai lys na suksesvol verwyder
      } catch (error) {
        console.error('Error deleting user:', error);
      }
    }
  };

  // Sluit modal en stel vorm terug
  const handleCloseModal = () => {
    setShowModal(false);
    setEditingUser(null);
    setFormUser({
      user_name: '',
      user_surname: '',
      user_email: '',
      user_password: '',
      user_status: 'active',
      role_id: 1
    });
  };

  const getRoleName = (roleId) => {
    switch (roleId) {
      case 1: return 'Gebruiker';
      case 2: return 'Fasiliteit Koördineerder';
      case 3: return 'Administrateur';
      default: return 'Gebruiker';
    }
  };

  // Filter gebruikers op soekterm EN status
  const filteredUsers = [...users]
    .filter(user => {
      const query = searchTerm.trim().toLowerCase();
      const matchesFilter = filter === 'almal' || user.user_status === filter;
      if (!query) return matchesFilter;
      const values = {
        name: user.user_name,
        email: user.user_email,
        role: getRoleName(user.role_id),
        status: user.user_status === 'active' ? 'Aktief' : 'Onaktief',
      };
      const matchesColumn = filterColumn === 'all'
        ? Object.values(values).some((value) => String(value || '').toLowerCase().includes(query))
        : String(values[filterColumn] || '').toLowerCase().includes(query);
      return matchesFilter && matchesColumn;
    })
    .sort((a, b) => {
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'name') return String(a.user_name || '').localeCompare(String(b.user_name || ''), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'email') return String(a.user_email || '').localeCompare(String(b.user_email || ''), 'af', { sensitivity: 'base' }) * direction;
      return 0;
    });

  // Gee CSS-klasse vir rol vir styling
  const getRoleClass = (roleId) => {
    switch (roleId) {
      case 1: return 'rol-user';
      case 2: return 'rol-fasiliteit';
      case 3: return 'rol-admin';
      default: return 'rol-user';
    }
  };

  const getStatusClass = (status) => {
    return (status === 'Aktief' || status === 'active') ? 'status-aktief' : 'status-onaktief';
  };

  if (loading) {
    return <div>Besig om gebruikers te laai...</div>;
  }

  if (!isAuthorized) {
    return (
      <div style={{ padding: '20px', color: 'red', fontSize: '16px' }}>
              <p>Jammer, jy het nie die regte toestemming om die Gebruikers blad te besoek nie.</p>
              <p>Alleen administrateurs kan hierdie blad sien.</p>
              <p>Jy word nou teruggeleei na die Paneelbord...</p>
            </div>
    );
  }

  return (
    <div style={{ display: 'flex' }}>
      <Sidebar currentPath="/users" isAdmin={true} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Gebruikers Bestuur</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          <div className="controls">
            <div className="controls-left">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <input
                  type="text"
                  className="search-box"
                  placeholder="Soek op Naam of E-pos..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>

              <select
                className="filter-select"
                value={filter}
                onChange={(e) => setFilter(e.target.value)}
              >
                <option value="almal">Alle Statusse</option>
                <option value="active">Aktief</option>
                <option value="inactive">Onaktief</option>
              </select>
              <select value={filterColumn} onChange={(e) => setFilterColumn(e.target.value)}>
                <option value="all">Alle kolomme</option>
                <option value="name">Naam</option>
                <option value="email">E-pos</option>
                <option value="role">Rol</option>
                <option value="status">Status</option>
              </select>
            </div>
            <div className="controls-right">
              <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
                <option value="default">Standaard</option>
                <option value="name">Naam</option>
                <option value="email">E-pos</option>
              </select>
              <div style={{ display: 'flex', gap: '0.25rem' }}>
                <button type="button" className="btn-add" onClick={() => setSortDirection('asc')} style={{ minWidth: '40px', background: sortDirection === 'asc' ? '#935e28' : undefined }} title="Stygend">▲</button>
                <button type="button" className="btn-add" onClick={() => setSortDirection('desc')} style={{ minWidth: '40px', background: sortDirection === 'desc' ? '#935e28' : undefined }} title="Dalend">▼</button>
              </div>

              <button className="btn-add" onClick={() => setShowModal(true)}>+ Nuwe Gebruiker</button>
            </div>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th>Naam</th>
                <th>E-pos</th>
                <th>Rol</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map(user => (
                <tr key={user.user_id} onClick={() => handleEditUser(user)} style={{ cursor: "pointer" }}>
                  <td>{user.user_name}</td>
                  <td>{user.user_email}</td>
                  <td><span className={`badge ${getRoleClass(user.role_id)}`}>{getRoleName(user.role_id)}</span></td>
                  <td className={getStatusClass(user.user_status)}>{user.user_status === 'active' ? 'Aktief' : 'Onaktief'}</td>
                  <td onClick={e => e.stopPropagation()}>
                    <button className="btn-delete" onClick={() => handleDeleteUser(user.user_id)} style={{ marginLeft: '5px', backgroundColor: '#dc3545' }}>Verwyder</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal">
          <div className="modal-content">
            <div className="modal-header">
              <h3 >{editingUser ? 'Wysig Gebruiker' : 'Nuwe Gebruiker'}</h3>
              <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            {error && <div style={{ color: '#dc3545', padding: '10px', marginBottom: '10px', backgroundColor: '#f8d7da', borderRadius: '4px' }}>{error}</div>}
            {success && <div style={{ color: '#155724', padding: '10px', marginBottom: '10px', backgroundColor: '#d4edda', borderRadius: '4px' }}>{success}</div>}
            <div className="form-group">
              <label>Voornaam *</label>
              <input
                ref={el => fieldRefs.current.user_name = el}
                type="text"
                className={invalidFields.user_name ? "field-invalid" : ""}
                value={formUser.user_name}
                onChange={(e) => {
                  setFormUser({ ...formUser, user_name: e.target.value });
                  setInvalidFields(p => { const n = {...p}; delete n.user_name; return n; });
                }}
              />
            </div>
            <div className="form-group">
              <label>Van *</label>
              <input
                ref={el => fieldRefs.current.user_surname = el}
                type="text"
                className={invalidFields.user_surname ? "field-invalid" : ""}
                value={formUser.user_surname}
                onChange={(e) => {
                  setFormUser({ ...formUser, user_surname: e.target.value });
                  setInvalidFields(p => { const n = {...p}; delete n.user_surname; return n; });
                }}
              />
            </div>
            <div className="form-group">
              <label>E-pos *</label>
              <input
                ref={el => fieldRefs.current.user_email = el}
                type="email"
                className={invalidFields.user_email ? "field-invalid" : ""}
                value={formUser.user_email}
                onChange={(e) => {
                  setFormUser({ ...formUser, user_email: e.target.value });
                  setInvalidFields(p => { const n = {...p}; delete n.user_email; return n; });
                }}
              />
            </div>
            {!editingUser && (
              <div className="form-group">
                <label>Wagwoord *</label>
                <input
                  ref={el => fieldRefs.current.user_password = el}
                  type="password"
                  className={invalidFields.user_password ? "field-invalid" : ""}
                  value={formUser.user_password}
                  onChange={(e) => {
                    setFormUser({ ...formUser, user_password: e.target.value });
                    setInvalidFields(p => { const n = {...p}; delete n.user_password; return n; });
                  }}
                />
              </div>
            )}
            <div className="form-group">
              <label>Rol *</label>
              <select
                ref={el => fieldRefs.current.role_id = el}
                className={invalidFields.role_id ? "field-invalid" : ""}
                value={formUser.role_id}
                onChange={(e) => {
                  setFormUser({ ...formUser, role_id: parseInt(e.target.value) });
                  setInvalidFields(p => { const n = {...p}; delete n.role_id; return n; });
                }}
              >
                {roles.map(role => (
                  <option key={role.id} value={role.id}>{role.name}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label>Status *</label>
              <select
                ref={el => fieldRefs.current.user_status = el}
                className={invalidFields.user_status ? "field-invalid" : ""}
                value={formUser.user_status}
                onChange={(e) => {
                  setFormUser({ ...formUser, user_status: e.target.value });
                  setInvalidFields(p => { const n = {...p}; delete n.user_status; return n; });
                }}
              >
                <option value="active">Aktief</option>
                <option value="inactive">Onaktief</option>
              </select>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleAddUser}>Stoor</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default UsersPage;