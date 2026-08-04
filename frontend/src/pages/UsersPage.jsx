import React, { useState, useEffect, useRef } from 'react';
import { apiClient, locationAPI } from '../services/api';
import '../styles/App.css';
import '../styles/Users.css';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import { useToast } from '../components/Toast/useToast';
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import ResizableTh from "../components/ResizableTh";

function UsersPage({ embedded = false }) {
  const { confirm, dialog } = useConfirmDialog();
  const { showToast } = useToast();
  const [users, setUsers] = useState([]);
  const [roles, setRoles] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filter, setFilter] = useState('almal');
  const [filterColumn, setFilterColumn] = useState('all');
  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: null });

  const USER_COLUMNS = [
    { key: 'id', label: 'ID', render: (u) => u.user_id, sortKey: 'id', defaultVisible: false },
    { key: 'name', label: 'Naam', render: (u) => u.user_name, sortKey: 'name', defaultVisible: true },
    { key: 'surname', label: 'Van', render: (u) => u.user_surname || '-', sortKey: 'surname', defaultVisible: false },
    { key: 'email', label: 'E-pos', render: (u) => u.user_email, sortKey: 'email', defaultVisible: true },
    { key: 'number', label: 'Telefoon', render: (u) => u.user_number || '-', sortKey: 'number', defaultVisible: false },
    { key: 'role', label: 'Rol', render: (u) => { const role = roles.find(r => r.role_id === u.role_id); return <span className={`badge ${getRoleClass(u.role_id)}`}>{role ? role.role_name : u.role_id}</span>; }, sortKey: 'role', defaultVisible: true },
    { key: 'status', label: 'Status', render: (u) => { const label = u.user_status === 'active' ? 'Aktief' : 'Onaktief'; return <span className={getStatusClass(u.user_status)}>{label}</span>; }, sortKey: 'status', defaultVisible: true },
    { key: 'terrain', label: 'Terrein', render: (u) => { const t = terrains.find(t => t.location_id === u.location_id); return t ? t.location_name : '-'; }, sortKey: 'terrain', defaultVisible: false },
    { key: 'lastlogin', label: 'Laaste Aanmelding', render: (u) => u.user_lastlogintime ? new Date(u.user_lastlogintime).toLocaleDateString('af-ZA') : '-', sortKey: 'lastlogin', defaultVisible: false },
  ];
  const colVis = useColumnVisibility('users-page', USER_COLUMNS);
  const colWidths = useColumnWidths('users-page', USER_COLUMNS);
  const colPickerRef = useRef(null);

  const [showModal, setShowModal] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [formUser, setFormUser] = useState({
    user_name: '',
    user_surname: '',
    user_email: '',
    user_password: '',
    user_status: 'active',
    role_id: 1,
    location_id: ''
  });

  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});

  // Toegang tot hierdie bladsy word deur
  // <RightProtectedRoute requiredRight="users.manage"> in App.jsx afgedwing (en
  // die backend gate elke /users-roete met require_right("users.manage")). Hier
  // haal ons die gebruikers EN die rolle (rolle dryf die rol-keuselys en word
  // nou dinamies van die backend gehaal i.p.v. hardgekodeer).
  useEffect(() => {
    fetchUsers();
    fetchRoles();
    fetchTerrains();
  }, []);

  const fetchTerrains = async () => {
    try {
      const response = await locationAPI.getAll();
      setTerrains(response.data || []);
    } catch (error) {
      console.error('Error fetching terrains:', error);
    }
  };

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

  const fetchRoles = async () => {
    try {
      const response = await apiClient.roles.getAll();
      setRoles(response.data);
    } catch (error) {
      console.error('Error fetching roles:', error);
    }
  };

  // Hanteer toevoeging van nuwe gebruiker of opdatering van bestaande
  const handleAddUser = async () => {
    try {

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
        const firstKey = Object.keys(errors)[0];
        fieldRefs.current[firstKey]?.scrollIntoView({ behavior: "smooth", block: "center" });
        fieldRefs.current[firstKey]?.focus();
        return;
      }
      setInvalidFields({});

      let dataToSend = { ...formUser };

      // Wanneer redigeer, stuur nie leë wagwoord (laat bestaande wagwoord onveranderd)
      if (editingUser && !formUser.user_password) {
        delete dataToSend.user_password;
      }

      // As ons redigeer, stuur PATCH-versoek, anders POST vir nuwe gebruiker
      if (editingUser) {
        await apiClient.users.update(editingUser.user_id, dataToSend);
        showToast({ type: 'success', message: 'Gebruiker het succesvol opgedateer' });
      } else {
        await apiClient.users.create(dataToSend);
        showToast({ type: 'success', message: 'Gebruiker het suksesvol geskep' });
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
        fetchUsers();
      }, 1500);
    } catch (error) {
      console.error('Error saving user:', error);
      showToast({ type: 'error', message: error.response?.data?.detail || 'Fout by die opslaan van gebruiker' });
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
      role_id: user.role_id,
      location_id: user.location_id || ''
    });
    setShowModal(true);
  };

  // Verwyder gebruiker na bevestiging
  const handleDeleteUser = async (userId) => {
    const confirmed = await confirm({ message: 'Is jy seker jy wil hierdie gebruiker verwyder?', variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;
    try {
      await apiClient.users.delete(userId);
      fetchUsers();
    } catch (error) {
      console.error('Error deleting user:', error);
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
      role_id: 1,
      location_id: ''
    });
  };

  const getRoleName = (roleId) => {
    const role = roles.find(r => r.role_id === roleId);
    if (role) return role.role_name;
    // Terugval vir ingeboude rolle voordat die rol-lys gelaai het
    switch (roleId) {
      case 1: return 'Gebruiker';
      case 2: return 'Fasiliteit Koördineerder';
      case 3: return 'Administrateur';
      case 4: return 'Kontrakteur';
      default: return 'Onbekend';
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
      if (!sortKey) return 0;
      const dir = sortDirection === 'asc' ? 1 : -1;
      if (sortKey === 'id') return ((a.user_id || 0) - (b.user_id || 0)) * dir;
      if (sortKey === 'name') return String(a.user_name || '').localeCompare(String(b.user_name || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'surname') return String(a.user_surname || '').localeCompare(String(b.user_surname || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'email') return String(a.user_email || '').localeCompare(String(b.user_email || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'number') return String(a.user_number || '').localeCompare(String(b.user_number || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'role') return String(getRoleName(a.role_id) || '').localeCompare(String(getRoleName(b.role_id) || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'status') return String(a.user_status || '').localeCompare(String(b.user_status || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'terrain') {
        const ta = terrains.find(t => t.location_id === a.location_id);
        const tb = terrains.find(t => t.location_id === b.location_id);
        return String(ta ? ta.location_name : '').localeCompare(String(tb ? tb.location_name : ''), 'af', { sensitivity: 'base' }) * dir;
      }
      if (sortKey === 'lastlogin') {
        const da = a.user_lastlogintime ? new Date(a.user_lastlogintime).getTime() : 0;
        const db = b.user_lastlogintime ? new Date(b.user_lastlogintime).getTime() : 0;
        return (da - db) * dir;
      }
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

  if (loading) return <div className="main"><div className="content">Besig om gebruikers te laai...</div></div>;

  const pageContent = (
    <>
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
          <ColumnPicker
            ref={colPickerRef}
            columns={USER_COLUMNS}
            visibleColumns={colVis.visibleColumns}
            toggleColumn={colVis.toggleColumn}
            resetVisibility={colVis.resetVisibility}
            onResetWidths={colWidths.resetWidths}
          />
          <button className="btn-add" onClick={() => setShowModal(true)}>+ Nuwe Gebruiker</button>
        </div>
      </div>

      <table className="standard-table">
        <thead>
          <tr>
            {colVis.visibleColumns.map((col) => (
              <ResizableTh
                key={col.key}
                col={col}
                colWidths={colWidths}
                className={col.sortKey ? getSortClass(col.sortKey) : ''}
                onClick={() => col.sortKey && handleSort(col.sortKey)}
                onContextMenu={(e) => colPickerRef.current?.openAt(e)}
              >
                {col.label}{col.sortKey && getSortIndicator(col.sortKey)}
              </ResizableTh>
            ))}
            <th style={{ width: '120px' }}>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredUsers.length === 0 ? (
            <tr><td colSpan={colVis.visibleColumns.length + 1} style={{ textAlign: 'center', padding: '20px' }}>Geen gebruikers gevind</td></tr>
          ) : (
            filteredUsers.map(user => (
              <tr key={user.user_id} onClick={() => handleEditUser(user)} style={{ cursor: "pointer" }}>
                {colVis.visibleColumns.map((col) => (
                  <td key={col.key}>{col.render(user)}</td>
                ))}
                <td onClick={e => e.stopPropagation()}>
                  <button className="btn-delete" onClick={() => handleDeleteUser(user.user_id)} style={{ marginLeft: '5px', backgroundColor: '#dc3545' }}>Verwyder</button>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </>
  );

  const modalContent = showModal && (
    <div className="modal">
      <div className="modal-content">
        <div className="modal-header">
          <h3 >{editingUser ? 'Wysig Gebruiker' : 'Nuwe Gebruiker'}</h3>
          <span className="close" onClick={handleCloseModal}>&times;</span>
        </div>

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
              <option key={role.role_id} value={role.role_id}>{role.role_name}</option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label>Terrein (slegs vir FK)</label>
          <select
            value={formUser.location_id || ''}
            onChange={(e) => setFormUser({ ...formUser, location_id: e.target.value ? Number(e.target.value) : null })}
          >
            <option value="">Geen terrein</option>
            {terrains.map(t => (
              <option key={t.location_id} value={t.location_id}>{t.location_name}</option>
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

export default UsersPage;