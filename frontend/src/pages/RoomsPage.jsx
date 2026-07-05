import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { assetsAPI, buildingsAPI, roomsAPI, locationAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import "../styles/App.css";
import "../styles/Rooms.css";
import { useLogout } from "./Page.jsx";
import UserProfileHeader from '../components/UserProfileHeader';

function RoomsPage() {
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();

  const [rooms, setRooms] = useState([]);
  const [assets, setAssets] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  const [showModal, setShowModal] = useState(false);
  const [showAssetsModal, setShowAssetsModal] = useState(false);
  const [selectedRoom, setSelectedRoom] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newRoom, setNewRoom] = useState({
    room_name: "",
    room_capacity: "",
    room_type: "other",
    location_id: "",
    building_id: "",
  });

  useEffect(() => {
    const loadData = async () => {
      await Promise.all([fetchRooms(), fetchAssets(), fetchTerrains(), fetchBuildings()]);
    };
    loadData();
  }, []);

  const fetchRooms = async () => {
    setLoading(true);
    try {
      const response = await roomsAPI.getAll();
      setRooms(response.data || []);
    } catch (error) {
      console.error("Error fetching rooms:", error);
    } finally {
      setLoading(false);
    }
  };

  const fetchAssets = async () => {
    try {
      const response = await assetsAPI.getAll();
      setAssets(response.data || []);
    } catch (error) {
      console.error("Error fetching assets:", error);
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

  const fetchBuildings = async () => {
    try {
      const response = await buildingsAPI.getAll();
      setBuildings(response.data || []);
    } catch (error) {
      console.error("Error fetching buildings:", error);
    }
  };

  const translateRoomType = (type) => {
    const translations = {
      classroom: "Klaslokaal",
      laboratory: "Laboratorium",
      office: "Kantoor",
      other: "Ander",
    };
    return translations[type] || type;
  };

  const handleSaveRoom = async () => {
    if (!newRoom.room_name?.trim()) {
      alert("Voer asseblief 'n lokaalnaam in");
      return;
    }

    if (!newRoom.building_id) {
      alert("Voer asseblief 'n gebou in");
      return;
    }

    const roomData = {
      room_name: newRoom.room_name,
      room_capacity: newRoom.room_capacity ? Number(newRoom.room_capacity) : null,
      room_type: newRoom.room_type,
      building_id: Number(newRoom.building_id),
    };

    try {
      if (isEditing) {
        await roomsAPI.update(editingId, roomData);
      } else {
        await roomsAPI.create(roomData);
      }
      await fetchRooms();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving room:", error);
      alert("Fout tydens besparing. Probeer asseblief weer.");
    }
  };

  const handleEditRoom = (room) => {
    const building = buildings.find((b) => b.building_id === room.building_id);
    setIsEditing(true);
    setEditingId(room.room_id);
    setNewRoom({
      room_name: room.room_name || "",
      room_capacity: room.room_capacity ?? "",
      room_type: room.room_type || "other",
      location_id: building ? building.location_id : "",
      building_id: room.building_id ?? "",
    });
    setShowModal(true);
  };

  const handleDeleteRoom = async (roomId) => {
    if (!window.confirm("Is jy seker jy wil hierdie lokaal verwyder?")) {
      return;
    }
    try {
      await roomsAPI.delete(roomId);
      await fetchRooms();
    } catch (error) {
      console.error("Error deleting room:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  const handleNewRoom = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewRoom({
      room_name: "",
      room_capacity: "",
      room_type: "other",
      location_id: "",
      building_id: "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewRoom({
      room_name: "",
      room_capacity: "",
      room_type: "other",
      location_id: "",
      building_id: "",
    });
  };

  const handleViewAssets = (room) => {
    setSelectedRoom(room);
    setShowAssetsModal(true);
  };

  const getAssetsForRoom = (roomId) => assets.filter((asset) => asset.room_id === roomId);

  const getTerrainName = (locationId) => {
    const terrain = terrains.find((t) => t.location_id === locationId);
    return terrain ? terrain.location_name : "-";
  };

  const getBuildingName = (buildingId) => {
    const building = buildings.find((b) => b.building_id === buildingId);
    return building ? building.building_name : "-";
  };

  const getBuildingTerrainId = (buildingId) => {
    const building = buildings.find((b) => b.building_id === buildingId);
    return building ? building.location_id : null;
  };

  const filteredRooms = [...rooms]
    .filter((room) => {
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        id: room.room_id,
        name: room.room_name,
        type: translateRoomType(room.room_type || 'other'),
        building: getBuildingName(room.building_id),
        capacity: room.room_capacity,
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'id') return (Number(a.room_id || 0) - Number(b.room_id || 0)) * direction;
      if (sortBy === 'name') return String(a.room_name || '').localeCompare(String(b.room_name || ''), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'capacity') return (Number(a.room_capacity || 0) - Number(b.room_capacity || 0)) * direction;
      return 0;
    });

  if (loading) {
    return (
      <div style={{ display: "flex" }}>
        <div className="main">
          <div className="content">Laai...</div>
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
          <li className="dropdown" >
              <div className="dropdown-trigger">
                <span>Bates & Voorraad</span>
              </div>
                <div className="dropdown-content">
                <Link to="/assets">Bates</Link>
                <Link to="/stock">Voorraad</Link>
                </div>
          </li>
            <li className="dropdown" style={{ background: '#935e28' }}>
              <div className="dropdown-trigger">
                  <span>Lokale & Terreine</span>
              </div>
              <div className="dropdown-content">
                    <li><Link to="/rooms" style={{ background: '#935e28' }}>Lokale</Link></li>
                    <li><Link to="/buildings">Geboue</Link></li>
                    <li><Link to="/terrains">Terreine</Link></li>
              </div>
          </li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          <li><Link to="/contractors">Kontrakteurs</Link></li>
          <li><Link to="/calendar" >Kalender</Link></li>
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
          <h3>Lokale Bestuur</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          <div className="controls">
            <div className="controls-left">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <input
                  type="text"
                  className="search-box"
                  placeholder="Soek lokale..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <select value={filterColumn} onChange={(e) => setFilterColumn(e.target.value)}>
                <option value="all">Alle kolomme</option>
                <option value="id">ID</option>
                <option value="name">Naam</option>
                <option value="type">Tipe</option>
                <option value="building">Gebou</option>
                <option value="capacity">Kapasiteit</option>
              </select>
            </div>
            <div className="controls-right">
              <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
                <option value="default">Standaard</option>
                <option value="id">ID</option>
                <option value="name">Naam</option>
                <option value="capacity">Kapasiteit</option>
              </select>
              <div style={{ display: 'flex', gap: '0.25rem' }}>
                <button type="button" className="btn-add" onClick={() => setSortDirection('asc')} style={{ minWidth: '40px', background: sortDirection === 'asc' ? '#935e28' : undefined }} title="Stygend">▲</button>
                <button type="button" className="btn-add" onClick={() => setSortDirection('desc')} style={{ minWidth: '40px', background: sortDirection === 'desc' ? '#935e28' : undefined }} title="Dalend">▼</button>
              </div>
              <button className="btn-add" onClick={handleNewRoom}>+ Nuwe Lokaal</button>
            </div>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th>ID Lokaal</th>
                <th>Naam</th>
                <th>Tipe</th>
                <th>Gebou</th>
                <th>Kapasiteit</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredRooms.map((room) => (
                <tr key={room.room_id}>
                  <td>{room.room_id}</td>
                      <td>{room.room_name}</td>
                  <td>{translateRoomType(room.room_type || 'other')}</td>
                  <td>{getBuildingName(room.building_id)}</td>
                  <td>{room.room_capacity ?? '-'}</td>
                  <td>
                    <button className="btn-view" onClick={() => handleViewAssets(room)}>
                      Besigtig Bates
                    </button>
                    <button className="btn-edit" onClick={() => handleEditRoom(room)}>
                      Wysig
                    </button>
                    <button className="btn-delete" onClick={() => handleDeleteRoom(room.room_id)}>
                      Verwyder
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal" style={{ display: 'flex' }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>{isEditing ? "Wysig" : "Nuwe"} lokaal {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
               <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Naam</label>
                <input
                  type="text"
                  value={newRoom.room_name}
                  onChange={(e) => setNewRoom({ ...newRoom, room_name: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Kapasiteit</label>
                <input
                  type="number"
                  value={newRoom.room_capacity}
                  onChange={(e) => setNewRoom({ ...newRoom, room_capacity: e.target.value })}
                />
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Terrein</label>
                <select
                  value={newRoom.location_id}
                  onChange={(e) => {
                    setNewRoom({ ...newRoom, location_id: e.target.value, building_id: "" });
                  }}
                >
                  <option value="">Kies 'n terrein</option>
                  {terrains.map((terrain) => (
                    <option key={terrain.location_id} value={terrain.location_id}>{terrain.location_name}</option>
                  ))}
                </select>
              </div>
              <div className="input-group">
                <label>Gebou</label>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
                  {newRoom.location_id ? (
                    <>
                      <input
                        type="text"
                        placeholder="Soek gebou..."
                        onChange={(e) => setNewRoom({ ...newRoom, _buildingSearch: e.target.value })}
                        style={{ padding: '0.3rem', fontSize: '0.8rem' }}
                      />
                      <select
                        value={newRoom.building_id}
                        onChange={(e) => setNewRoom({ ...newRoom, building_id: e.target.value })}
                      >
                        <option value="">Kies 'n gebou</option>
                        {buildings
                          .filter((b) => b.location_id === Number(newRoom.location_id))
                          .filter((b) => {
                            const search = (newRoom._buildingSearch || '').toLowerCase();
                            if (!search) return true;
                            return b.building_name.toLowerCase().includes(search) ||
                                   String(b.building_id).includes(search);
                          })
                          .map((building) => (
                            <option key={building.building_id} value={building.building_id}>
                              {building.building_name}
                            </option>
                          ))}
                      </select>
                    </>
                  ) : (
                    <select disabled>
                      <option value="">Kies eers 'n terrein</option>
                    </select>
                  )}
                </div>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Tipe</label>
                <select
                  value={newRoom.room_type}
                  onChange={(e) => setNewRoom({ ...newRoom, room_type: e.target.value })}
                >
                  <option value="classroom">Klaslokaal</option>
                  <option value="laboratory">Laboratorium</option>
                  <option value="office">Kantoor</option>
                  <option value="other">Ander</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleSaveRoom}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}

      {showAssetsModal && selectedRoom && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Bates in {getBuildingName(selectedRoom.building_id)} - {selectedRoom.room_name}</h3>
              <span className="close" onClick={() => setShowAssetsModal(false)}>&times;</span>
            </div>
            <div className="modal-body">
              {getAssetsForRoom(selectedRoom.room_id).length > 0 ? (
                <table className="assets-table">
                  <thead>
                    <tr>
                      <th>Naam</th>
                      <th>Tipe</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {getAssetsForRoom(selectedRoom.room_id).map((asset) => (
                      <tr key={asset.asset_id}>
                        <td>{asset.asset_name}</td>
                        <td>{asset.asset_type}</td>
                        <td>{asset.asset_status}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p>Geen bates in hierdie lokaal.</p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default RoomsPage;
