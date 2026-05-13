import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { assetsAPI, roomsAPI, locationAPI } from "../services/api";
import "../styles/Rooms.css";

function RoomsPage() {
  const [rooms, setRooms] = useState([]);
  const [assets, setAssets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [selectedRoom, setSelectedRoom] = useState(null);
  const [showAssetsModal, setShowAssetsModal] = useState(false);
  const [roomType, setRoomType] = useState("room"); // "room" or "terrain"
  const [terrains, setTerrains] = useState([]);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newRoom, setNewRoom] = useState({
    room_name: "",
    room_capacity: "",
    room_type: "other",
    location_id: "",
  });

  const [newTerrain, setNewTerrain] = useState({
    location_name: "",
    location_type: "",
    location_streetnum: "",
    location_streetname: "",
    zipcode_id: "",
  });

  useEffect(() => {
    fetchRooms();
    fetchAssets();
    fetchTerrains();
  }, []);

  const fetchRooms = async () => {
    setLoading(true);
    try {
      const response = await roomsAPI.getAll();
      setRooms(response.data);
    } catch (error) {
      console.error("Error fetching rooms:", error);
    } finally {
      setLoading(false);
    }
  };

  const fetchAssets = async () => {
    try {
      const response = await assetsAPI.getAll();
      setAssets(response.data);
    } catch (error) {
      console.error("Error fetching assets:", error);
    }
  };

  const fetchTerrains = async () => {
    try {
      const response = await locationAPI.getAll();
      setTerrains(response.data);
    } catch (error) {
      console.error("Error fetching terrains:", error);
    }
  };

  const translateRoomType = (type) => {
    const translations = {
      "classroom": "Klaslokaal",
      "laboratory": "Laboratorium",
      "office": "Kantoor",
      "other": "Ander",
    };
    return translations[type] || type;
  };

  const handleAddRoom = async () => {
    try {
      if (roomType === "room") {
        if (!newRoom.room_name || !newRoom.location_id) {
          alert("Voer asseblief die roomnaam en terrein in");
          return;
        }
        const roomData = {
          room_name: newRoom.room_name,
          room_capacity: newRoom.room_capacity ? Number(newRoom.room_capacity) : null,
          room_type: newRoom.room_type,
          location_id: Number(newRoom.location_id),
        };
        if (isEditing) {
          await roomsAPI.update(editingId, roomData);
        } else {
          await roomsAPI.create(roomData);
        }
        setNewRoom({
          room_name: "",
          room_capacity: "",
          room_type: "",
          location_id: "",
        });
      } else {
        const terrainData = {
          location_name: newTerrain.location_name,
          location_type: newTerrain.location_type,
          location_streetnum: newTerrain.location_streetnum,
          location_streetname: newTerrain.location_streetname,
          zipcode_id: 1,
        };
        if (isEditing) {
          await locationAPI.update(editingId, terrainData);
        } else {
          await locationAPI.create(terrainData);
        }
        setNewTerrain({
          location_name: "",
          location_type: "",
          location_streetnum: "",
          location_streetname: "",
          zipcode_id: "",
        });
      }
      handleCloseModal();
      fetchRooms();
      fetchTerrains();
    } catch (error) {
      console.error("Error saving:", error);
    }
  };

  const handleEditRoom = (item) => {
    setIsEditing(true);
    setEditingId(roomType === "room" ? item.room_id : item.location_id);
    if (roomType === "room") {
      setNewRoom({
        room_name: item.room_name,
        room_capacity: item.room_capacity || "",
        room_type: item.room_type || "other",
        location_id: item.location_id || "",
      });
    } else {
      setNewTerrain({
        location_name: item.location_name || "",
        location_type: item.location_type || "",
        location_streetnum: item.location_streetnum || "",
        location_streetname: item.location_streetname || "",
        zipcode_id: item.zipcode_id || "",
      });
    }
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
    });
    setNewTerrain({
      location_name: "",
      location_type: "",
      location_streetnum: "",
      location_streetname: "",
      zipcode_id: "",
    });
  };

  const handleNewRoom = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewRoom({
      room_name: "",
      room_capacity: "",
      room_type: "other",
      location_id: "",
    });
    setNewTerrain({
      location_name: "",
      location_type: "",
      location_streetnum: "",
      location_streetname: "",
      zipcode_id: "",
    });
    setShowModal(true);
  };

  const handleViewAssets = (room) => {
    setSelectedRoom(room);
    setShowAssetsModal(true);
  };

  const getAssetsForRoom = (roomId) => {
    return assets.filter(asset => asset.room_id === roomId);
  };

  const getTerrainName = (locationId) => {
    const terrain = terrains.find(t => t.location_id === locationId);
    return terrain ? terrain.location_name : '-';
  };

  const handleDeleteItem = async (itemId) => {
    try {
      if (roomType === "room") {
        await roomsAPI.delete(itemId);
        fetchRooms();
      } else {
        await locationAPI.delete(itemId);
        fetchTerrains();
      }
    } catch (error) {
      console.error('Error deleting item:', error);
    }
  };

  const filteredItems = roomType === "room" ? rooms.filter((room) => {
    const query = searchTerm.toLowerCase();
    const matchesSearch =
      room.room_name?.toLowerCase().includes(query) ||
      room.room_capacity?.toString().includes(query);
    return matchesSearch;
  }) : terrains.filter((terrain) => {
    const query = searchTerm.toLowerCase();
    const matchesSearch =
      terrain.location_name?.toLowerCase().includes(query) ||
      terrain.location_type?.toLowerCase().includes(query);
    return matchesSearch;
  });



  if (loading) {
    return (
      <div style={{ display: 'flex' }}>
        <div className="sidebar">
          <h2>FBS</h2>
          <ul>
            <li><Link to="/dashboard">Paneelbord</Link></li>
            <li><Link to="/assets">Bates</Link></li>
            <li><Link to="/rooms" style={{ background: '#935e28' }}>Lokale</Link></li>
            <li><Link to="/work-orders">Werksopdragte</Link></li>
            <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          </ul>
          <div className="logout-container">
            <Link to="/login" className="btn-logout-sidebar">Logout</Link>
          </div>
        </div>
        <div className="main">
          <div className="navbar">
            <h3>Lokale Bestuur</h3>
            <div className="user">Admin</div>
          </div>
          <div className="content">Laai lokale...</div>
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
          <li><Link to="/rooms" style={{ background: '#935e28' }}>Lokale</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
        </ul>
        <div className="logout-container">
          <Link to="/login" className="btn-logout-sidebar">Logout</Link>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Lokale Bestuur</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
          <div className="controls">
            <div className="toggle-switch">
              <span className={roomType === "room" ? "active" : ""} onClick={() => setRoomType("room")}>Lokale</span>
              <span className={roomType === "terrain" ? "active" : ""} onClick={() => setRoomType("terrain")}>Terreine</span>
            </div>
            <input
              type="text"
              className="search-box"
              placeholder={`Soek ${roomType === "room" ? "lokale" : "terreine"}...`}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <select
              className="filter-select"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="">Filter: Alle Statusse</option>
              <option value="active">Aktief</option>
              <option value="maintenance">Onderhoud</option>
              <option value="closed">Gesluit</option>
            </select>
            <button className="btn-add" onClick={handleNewRoom}>+ Nuwe {roomType === "room" ? "lokaal" : "terrein"}</button>
          </div>

          <table className="rooms-table">
            <thead>
              <tr>
                {roomType === "room" && <th>ID Lokaal</th>}
                {roomType === "terrain" && <th>ID Terrein</th>}
                <th>Naam</th>
                <th>Tipe</th>
                {roomType === "room" && <th>Terrein</th>}
                {roomType === "room" && <th>Kapasiteit</th>}
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredItems.map((item) => (
                <tr key={roomType === "room" ? item.room_id : item.location_id}>
                  <td>{roomType === "room" ? item.room_id : item.location_id}</td>
                  <td>{roomType === "room" ? item.room_name : item.location_name}</td>
                  <td>{roomType === "room" ? translateRoomType(item.room_type || 'other') : (item.location_type || '-')}</td>
                  {roomType === "room" && <td>{getTerrainName(item.location_id)}</td>}
                  {roomType === "room" && <td>{item.room_capacity ?? '-'}</td>}
                  <td>Aktief</td>
                  <td>
                    {roomType === "room" && (
                      <button className="btn-view" onClick={() => handleViewAssets(item)}>
                        Besigtig Bates
                      </button>
                    )}
                    <button className="btn-edit" onClick={() => handleEditRoom(item)}>
                      Wysig
                    </button>
                    <button className="btn-delete" onClick={() => handleDeleteItem(roomType === "room" ? item.room_id : item.location_id)}>
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
        <div className="modal-overlay" style={{ display: 'flex' }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>{isEditing ? "Wysig" : "Nuwe"} {roomType === "room" ? "lokaal" : "terrein"} {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
              <button className="close" onClick={handleCloseModal}>×</button>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Naam</label>
                <input
                  type="text"
                  value={roomType === "room" ? newRoom.room_name : newTerrain.location_name}
                  onChange={(e) => roomType === "room" 
                    ? setNewRoom({ ...newRoom, room_name: e.target.value })
                    : setNewTerrain({ ...newTerrain, location_name: e.target.value })}
                />
              </div>
              {roomType === "room" && (
                <div className="input-group">
                  <label>Terrein</label>
                  <select
                    value={newRoom.location_id}
                    onChange={(e) => setNewRoom({ ...newRoom, location_id: e.target.value })}
                  >
                    <option value="">Kies 'n terrein</option>
                    {terrains.map((terrain) => (
                      <option key={terrain.location_id} value={terrain.location_id}>{terrain.location_name}</option>
                    ))}
                  </select>
                </div>
              )}
            </div>
            {roomType === "room" && (
              <div className="input-row">
                <div className="input-group">
                  <label>Kapasiteit</label>
                  <input
                    type="number"
                    value={newRoom.room_capacity}
                    onChange={(e) => setNewRoom({ ...newRoom, room_capacity: e.target.value })}
                  />
                </div>
              </div>
            )}
            {roomType === "terrain" && (
              <div className="input-row">
                <div className="input-group">
                  <label>Tipe</label>
                  <input
                    type="text"
                    value={newTerrain.location_type}
                    onChange={(e) => setNewTerrain({ ...newTerrain, location_type: e.target.value })}
                    placeholder="bv. Kantoor, Fasiliteit, ens"
                  />
                </div>
              </div>
            )}
            {roomType === "terrain" && (
              <div className="input-row">
                <div className="input-group">
                  <label>Straatnommer</label>
                  <input
                    type="text"
                    value={newTerrain.location_streetnum}
                    onChange={(e) => setNewTerrain({ ...newTerrain, location_streetnum: e.target.value })}
                  />
                </div>
                <div className="input-group">
                  <label>Straatnaam</label>
                  <input
                    type="text"
                    value={newTerrain.location_streetname}
                    onChange={(e) => setNewTerrain({ ...newTerrain, location_streetname: e.target.value })}
                  />
                </div>
              </div>
            )}
            {roomType === "room" && (
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
            )}
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddRoom}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}

      {showAssetsModal && selectedRoom && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Bates in {getTerrainName(selectedRoom.location_id)} - {selectedRoom.room_name}</h3>
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
