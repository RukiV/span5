import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { apiClient } from '../services/api';
import '../styles/Users.css';

function UsersPage() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filter, setFilter] = useState('almal');
  const [showModal, setShowModal] = useState(false);
  const [newUser, setNewUser] = useState({
    name: '',
    email: '',
    role: 'Student',
    status: 'Aktief'
  });

  useEffect(() => {
    fetchUsers();
  }, []);

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

  const handleAddUser = async () => {
    try {
      await apiClient.users.create(newUser);
      setShowModal(false);
      setNewUser({ name: '', email: '', role: 'Student', status: 'Aktief' });
      fetchUsers();
    } catch (error) {
      console.error('Error adding user:', error);
    }
  };

  const filteredUsers = users.filter(user => {
    const matchesSearch = user.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         user.email.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesFilter = filter === 'almal' || user.status === filter;
    return matchesSearch && matchesFilter;
  });

  const getRoleClass = (role) => {
    switch (role) {
      case 'Fasiliteit': return 'rol-fasiliteit';
      case 'Personeel': return 'rol-personeel';
      case 'Student': return 'rol-student';
      default: return 'rol-personeel';
    }
  };

  const getStatusClass = (status) => {
    return status === 'Aktief' ? 'status-aktief' : 'status-onaktief';
  };

  if (loading) {
    return (
      <div style={{ display: 'flex' }}>
        <div className="sidebar">
          <h2>FBS</h2>
          <ul>
            <li><Link to="/dashboard">Paneelbord</Link></li>
            <li><Link to="/assets">Bates</Link></li>
            <li><Link to="/calendar">Kalender</Link></li>
            <li><Link to="/analysis">Analise</Link></li>
            <li><Link to="/reports">Verslae</Link></li>
            <li><Link to="/reporting">Rapportering</Link></li>
            <li><Link to="/rooms">Lokale</Link></li>
            <li><Link to="/work-orders">Werksopdragte</Link></li>
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
          <div className="content">Laai gebruikers...</div>
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
          <li><Link to="/calendar">Kalender</Link></li>
          <li><Link to="/analysis">Analise</Link></li>
          <li><Link to="/reports">Verslae</Link></li>
          <li><Link to="/reporting">Rapportering</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
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
              <option value="Aktief">Aktief</option>
              <option value="Onaktief">Onaktief</option>
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
                <tr key={user.id}>
                  <td>{user.name}</td>
                  <td>{user.email}</td>
                  <td><span className={`badge ${getRoleClass(user.role)}`}>{user.role}</span></td>
                  <td className={getStatusClass(user.status)}>{user.status}</td>
                  <td>
                    <button className="btn-edit">Wysig</button>
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
            <h3 className="form-title">Nuwe Gebruiker</h3>
            <div className="form-group">
              <label>Naam</label>
              <input
                type="text"
                value={newUser.name}
                onChange={(e) => setNewUser({ ...newUser, name: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label>E-pos</label>
              <input
                type="email"
                value={newUser.email}
                onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label>Rol</label>
              <select
                value={newUser.role}
                onChange={(e) => setNewUser({ ...newUser, role: e.target.value })}
              >
                <option value="Student">Student</option>
                <option value="Personeel">Personeel</option>
                <option value="Fasiliteit">Fasiliteit</option>
              </select>
            </div>
            <div className="form-group">
              <label>Status</label>
              <select
                value={newUser.status}
                onChange={(e) => setNewUser({ ...newUser, status: e.target.value })}
              >
                <option value="Aktief">Aktief</option>
                <option value="Onaktief">Onaktief</option>
              </select>
            </div>
            <div className="form-actions">
              <button className="btn-close" onClick={() => setShowModal(false)}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddUser}>Stoor</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default UsersPage;