import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { apiClient } from '../services/api';
import '../styles/Users.css';

function UsersPage() {
  const navigate = useNavigate();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filter, setFilter] = useState('almal');
  const [showModal, setShowModal] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [currentUser, setCurrentUser] = useState(null);
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
        setCurrentUser(response.data);
        
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

  // Haal almal gebruikers-lys van backend-API
  const fetchUsers = async () => {
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
      if (!formUser.user_name || !formUser.user_email) {
        setError('Naam en e-pos is vereist');
        return;
      }

      // Vir nuwe gebruikers, wagwoord is vereist
      if (!editingUser && !formUser.user_password) {
        setError('Wagwoord is vereist vir nuwe gebruikers');
        return;
      }

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
        setSuccess('Gebruiker het succesvol geskep');
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

  // Filter gebruikers op soekterm EN status
  const filteredUsers = users.filter(user => {
    // Soek in naam of e-pos veld
    const matchesSearch = (user.user_name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
                         (user.user_email || '').toLowerCase().includes(searchTerm.toLowerCase());
    // Filter op status (almal, aktief, onaktief)
    const matchesFilter = filter === 'almal' || user.user_status === filter;
    return matchesSearch && matchesFilter;
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

  const getRoleName = (roleId) => {
    switch (roleId) {
      case 1: return 'Gebruiker';
      case 2: return 'Fasiliteit Koördineerder';
      case 3: return 'Administrateur';
      default: return 'Gebruiker';
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
      <div style={{ display: 'flex' }}>
        <div className="sidebar">
          <h2>FBS</h2>
          <ul>
            <li><Link to="/dashboard">Paneelbord</Link></li>
            <li><Link to="/assets">Bates</Link></li>
            <li><Link to="/rooms">Lokale</Link></li>
            <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
            <li><Link to="/work-orders">Werksopdragte</Link></li>
          </ul>
          <div className="logout-container">
            <Link to="/login" className="btn-logout-sidebar">Logout</Link>
          </div>
        </div>
        <div className="main">
          <div className="navbar">
            <h3>Toegang Geweier</h3>
          </div>
          <div className="content">
            <div style={{ padding: '20px', color: 'red', fontSize: '16px' }}>
              <p>Jammer, jy het nie die regte toestemming om die Gebruikers blad te besoek nie.</p>
              <p>Alleen administrateurs kan hierdie blad sien.</p>
              <p>Jy word nou teruggeleei na die Paneelbord...</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex' }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li><Link to="/assets">Bates</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          <li><Link to="/users" style={{ background: "#935e28" }}>Gebruikers</Link></li>
        </ul>
        <div className="logout-container">
          <Link to="/login" className="btn-logout-sidebar">Logout</Link>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Gebruikers Bestuur</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
          <div className="controls">
            <input
              type="text"
              className="search-box"
              placeholder="Soek op Naam of E-pos..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />

            <select
              className="filter-select"
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
            >
              <option value="almal">Filter: Alle Statusse</option>
              <option value="active">Aktief</option>
              <option value="inactive">Onaktief</option>
            </select>

            <button className="btn-add-user" onClick={() => setShowModal(true)}>+ Nuwe Gebruiker</button>
          </div>

          <table className="users-table">
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
                <tr key={user.user_id}>
                  <td>{user.user_name}</td>
                  <td>{user.user_email}</td>
                  <td><span className={`badge ${getRoleClass(user.role_id)}`}>{getRoleName(user.role_id)}</span></td>
                  <td className={getStatusClass(user.user_status)}>{user.user_status === 'active' ? 'Aktief' : 'Onaktief'}</td>
                  <td>
                    <button className="btn-edit" onClick={() => handleEditUser(user)}>Wysig</button>
                    <button className="btn-delete" onClick={() => handleDeleteUser(user.user_id)} style={{ marginLeft: '5px', backgroundColor: '#dc3545' }}>Verwyder</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal-overlay" style={{ display: 'flex' }}>
          <div className="job-form-card">
            <h3 className="form-title">{editingUser ? 'Wysig Gebruiker' : 'Nuwe Gebruiker'}</h3>
            {error && <div style={{ color: '#dc3545', padding: '10px', marginBottom: '10px', backgroundColor: '#f8d7da', borderRadius: '4px' }}>{error}</div>}
            {success && <div style={{ color: '#155724', padding: '10px', marginBottom: '10px', backgroundColor: '#d4edda', borderRadius: '4px' }}>{success}</div>}
            <div className="form-group">
              <label>Voornaam</label>
              <input
                type="text"
                value={formUser.user_name}
                onChange={(e) => setFormUser({ ...formUser, user_name: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label>Van</label>
              <input
                type="text"
                value={formUser.user_surname}
                onChange={(e) => setFormUser({ ...formUser, user_surname: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label>E-pos</label>
              <input
                type="email"
                value={formUser.user_email}
                onChange={(e) => setFormUser({ ...formUser, user_email: e.target.value })}
              />
            </div>
            {!editingUser && (
              <div className="form-group">
                <label>Wagwoord</label>
                <input
                  type="password"
                  value={formUser.user_password}
                  onChange={(e) => setFormUser({ ...formUser, user_password: e.target.value })}
                />
              </div>
            )}
            <div className="form-group">
              <label>Rol</label>
              <select
                value={formUser.role_id}
                onChange={(e) => setFormUser({ ...formUser, role_id: parseInt(e.target.value) })}
              >
                {roles.map(role => (
                  <option key={role.id} value={role.id}>{role.name}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label>Status</label>
              <select
                value={formUser.user_status}
                onChange={(e) => setFormUser({ ...formUser, user_status: e.target.value })}
              >
                <option value="active">Aktief</option>
                <option value="inactive">Onaktief</option>
              </select>
            </div>
            <div className="form-actions">
              <button className="btn-close" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddUser}>Stoor</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default UsersPage;