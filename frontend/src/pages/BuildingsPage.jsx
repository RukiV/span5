import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { buildingsAPI, locationAPI, roomsAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import "../styles/Rooms.css";
import { useLogout } from "./Page.jsx";
import UserProfileHeader from '../components/UserProfileHeader';

function BuildingsPage() {
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();
  const [buildings, setBuildings] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  const [showModal, setShowModal] = useState(false);
  const [showRoomsModal, setShowRoomsModal] = useState(false);
  const [selectedBuilding, setSelectedBuilding] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newBuilding, setNewBuilding] = useState({
    building_name: "",
    building_type: "other",
    building_streetnum: "",
    building_streetname: "",
    location_id: "",
  });

  const translateBuildingType = (type) => {
    const translations = {
      admin: "Admin",
      onderwys: "Onderwys",
      laboratory: "Laboratorium",
      warehouse: "Pakhuis",
      other: "Ander",
    };
    return translations[type] || type;
  };

  useEffect(() => {
    const loadData = async () => {
      await Promise.all([fetchBuildings(), fetchTerrains(), fetchRooms()]);
    };
    loadData();
  }, []);

  const fetchBuildings = async () => {
    setLoading(true);
    try {
      const response = await buildingsAPI.getAll();
      setBuildings(response.data || []);
    } catch (error) {
      console.error("Error fetching buildings:", error);
    } finally {
      setLoading(false);
    }
  };

  const fetchTerrains = async () => {
    try {
      const response = await locationAPI.getAll();
      setTerrains(response.data || []);
    } catch (error) {
      console.error("Error fetching terrains:", error);
    }
  };

  const fetchRooms = async () => {
    try {
      const response = await roomsAPI.getAll();
      setRooms(response.data || []);
    } catch (error) {
      console.error("Error fetching rooms:", error);
    }
  };

  const getTerrainName = (locationId) => {
    const terrain = terrains.find((t) => t.location_id === locationId);
    return terrain ? terrain.location_name : "-";
  };

  const getRoomsForBuilding = (buildingId) => rooms.filter((r) => r.building_id === buildingId);

  const translateRoomType = (type) => {
    const translations = {
      classroom: "Klaslokaal",
      laboratory: "Laboratorium",
      office: "Kantoor",
      other: "Ander",
    };
    return translations[type] || type;
  };

  const handleSaveBuilding = async () => {
    if (!newBuilding.building_name?.trim()) {
      alert("Voer asseblief 'n gebounaam in");
      return;
    }

    if (!newBuilding.location_id) {
      alert("Voer asseblief 'n terrein in");
      return;
    }

    const buildingData = {
      building_name: newBuilding.building_name,
      building_type: newBuilding.building_type,
      building_streetnum: newBuilding.building_streetnum,
      building_streetname: newBuilding.building_streetname,
      location_id: Number(newBuilding.location_id),
    };

    try {
      if (isEditing) {
        await buildingsAPI.update(editingId, buildingData);
      } else {
        await buildingsAPI.create(buildingData);
      }
      await fetchBuildings();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving building:", error);
      alert("Fout tydens besparing. Probeer asseblief weer.");
    }
  };

  const handleDeleteBuilding = async (id) => {
    if (!window.confirm("Is jy seker jy wil hierdie gebou verwyder?")) {
      return;
    }
    try {
      await buildingsAPI.delete(id);
      await fetchBuildings();
    } catch (error) {
      console.error("Error deleting building:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  const handleEditBuilding = (item) => {
    setIsEditing(true);
    setEditingId(item.building_id);
    setNewBuilding({
      building_name: item.building_name || "",
      building_type: item.building_type || "other",
      building_streetnum: item.building_streetnum || "",
      building_streetname: item.building_streetname || "",
      location_id: item.location_id || "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewBuilding({ building_name: "", building_type: "other", building_streetnum: "", building_streetname: "", location_id: "" });
  };

  const handleNewBuilding = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewBuilding({ building_name: "", building_type: "other", building_streetnum: "", building_streetname: "", location_id: "" });
    setShowModal(true);
  };

  const handleViewRooms = (building) => {
    setSelectedBuilding(building);
    setShowRoomsModal(true);
  };

  const filteredBuildings = [...buildings]
    .filter((building) => {
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        id: building.building_id,
        name: building.building_name,
        type: translateBuildingType(building.building_type),
        streetnum: building.building_streetnum,
        streetname: building.building_streetname,
        terrain: getTerrainName(building.location_id),
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'id') return (Number(a.building_id || 0) - Number(b.building_id || 0)) * direction;
      if (sortBy === 'name') return String(a.building_name || '').localeCompare(String(b.building_name || ''), 'af', { sensitivity: 'base' }) * direction;
      return 0;
    });

  if (loading) {
    return <div style={{ display: "flex" }}><div className="main"><div className="content">Laai...</div></div></div>;
  }

  return (
    <div style={{ display: "flex" }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
            <li><Link to="/dashboard">Paneelbord</Link></li>
            <li class="dropdown" >
                <div className="dropdown-trigger">
                    <span>Bates & Voorraad</span>
                </div>
                    <div className="dropdown-content">
                    <Link to="/assets">Bates</Link>
                    <Link to="/stock">Voorraad</Link>
                    </div>
            </li>
                <li class="dropdown" style={{ background: '#935e28' }}>
                <div className="dropdown-trigger">
                    <span>Lokale & Terreine</span>
                </div>
                <div className="dropdown-content">
                    <li><Link to="/rooms">Lokale</Link></li>
                    <li><Link to="/buildings" style={{ background: '#935e28' }}>Geboue</Link></li>
                    <li><Link to="/terrains">Terreine</Link></li>
                </div>
            </li>
            <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
            <li><Link to="/work-orders">Werksopdragte</Link></li>
            <li><Link to="/contractors">Kontrakteurs</Link></li>
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
          <h3>Gebou Bestuur</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          <div className="controls">
            <div className="controls-left">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <input
                  type="text"
                  className="search-box"
                  placeholder="Soek geboue..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <select value={filterColumn} onChange={(e) => setFilterColumn(e.target.value)}>
                <option value="all">Alle kolomme</option>
                <option value="id">ID</option>
                <option value="name">Naam</option>
                <option value="type">Tipe</option>
                <option value="streetnum">Straatnommer</option>
                <option value="streetname">Straatnaam</option>
                <option value="terrain">Terrein</option>
              </select>
            </div>
            <div className="controls-right">
              <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
                <option value="default">Standaard</option>
                <option value="id">ID</option>
                <option value="name">Naam</option>
              </select>
              <div style={{ display: 'flex', gap: '0.25rem' }}>
                <button type="button" className="btn-add" onClick={() => setSortDirection('asc')} style={{ minWidth: '40px', background: sortDirection === 'asc' ? '#935e28' : undefined }} title="Stygend">▲</button>
                <button type="button" className="btn-add" onClick={() => setSortDirection('desc')} style={{ minWidth: '40px', background: sortDirection === 'desc' ? '#935e28' : undefined }} title="Dalend">▼</button>
              </div>
              <button className="btn-add" onClick={handleNewBuilding}>+ Nuwe Gebou</button>
            </div>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th>ID Gebou</th>
                <th>Naam</th>
                <th>Tipe</th>
                <th>Straatnommer</th>
                <th>Straatnaam</th>
                <th>Terrein</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredBuildings.map((building) => (
                <tr key={building.building_id}>
                  <td>{building.building_id}</td>
                  <td>{building.building_name}</td>
                  <td>{translateBuildingType(building.building_type)}</td>
                  <td>{building.building_streetnum || '-'}</td>
                  <td>{building.building_streetname || '-'}</td>
                  <td>{getTerrainName(building.location_id)}</td>
                  <td>
                    <button className="btn-view" onClick={() => handleViewRooms(building)}>Besigtig Lokale</button>
                    <button className="btn-edit" onClick={() => handleEditBuilding(building)}>Wysig</button>
                    <button className="btn-delete" onClick={() => handleDeleteBuilding(building.building_id)}>Verwyder</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>{isEditing ? "Wysig" : "Nuwe"} Gebou {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
               <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Naam</label>
                <input
                  type="text"
                  value={newBuilding.building_name}
                  onChange={(e) => setNewBuilding({ ...newBuilding, building_name: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Tipe</label>
                <select
                  value={newBuilding.building_type}
                  onChange={(e) => setNewBuilding({ ...newBuilding, building_type: e.target.value })}
                >
                  <option value="admin">Admin</option>
                  <option value="onderwys">Onderwys</option>
                  <option value="laboratory">Laboratorium</option>
                  <option value="warehouse">Pakhuis</option>
                  <option value="other">Ander</option>
                </select>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Straatnommer</label>
                <input
                  type="text"
                  value={newBuilding.building_streetnum}
                  onChange={(e) => setNewBuilding({ ...newBuilding, building_streetnum: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Straatnaam</label>
                <input
                  type="text"
                  value={newBuilding.building_streetname}
                  onChange={(e) => setNewBuilding({ ...newBuilding, building_streetname: e.target.value })}
                />
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Terrein</label>
                <select
                  value={newBuilding.location_id}
                  onChange={(e) => setNewBuilding({ ...newBuilding, location_id: e.target.value })}
                >
                  <option value="">Kies 'n terrein</option>
                  {terrains.map((terrain) => (
                    <option key={terrain.location_id} value={terrain.location_id}>{terrain.location_name}</option>
                  ))}
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleSaveBuilding}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}

      {showRoomsModal && selectedBuilding && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Lokale in {selectedBuilding.building_name} ({getTerrainName(selectedBuilding.location_id)})</h3>
              <span className="close" onClick={() => setShowRoomsModal(false)}>&times;</span>
            </div>
            <div className="modal-body">
              {getRoomsForBuilding(selectedBuilding.building_id).length > 0 ? (
                <table className="standard-table">
                  <thead>
                    <tr>
                      <th>Naam</th>
                      <th>Tipe</th>
                      <th>Kapasiteit</th>
                    </tr>
                  </thead>
                  <tbody>
                    {getRoomsForBuilding(selectedBuilding.building_id).map((room) => (
                      <tr key={room.room_id}>
                        <td>{room.room_name}</td>
                        <td>{translateRoomType(room.room_type || 'other')}</td>
                        <td>{room.room_capacity ?? '-'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p>Geen lokale in hierdie gebou.</p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default BuildingsPage;
