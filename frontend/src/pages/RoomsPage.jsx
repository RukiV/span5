import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { assetsAPI, roomsAPI } from "../services/api";
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
  const [newRoom, setNewRoom] = useState({
    name: "",
    description: "",
    terrain_id: "",
    capacity: "",
    type: "room",
    status: "active",
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
      const response = await roomsAPI.getAll();
      setTerrains(response.data.filter(room => room.type === "terrain"));
    } catch (error) {
      console.error("Error fetching terrains:", error);
    }
  };

  const handleAddRoom = async () => {
    try {
      await roomsAPI.create({
        ...newRoom,
        type: roomType,
        terrain_id: newRoom.terrain_id ? Number(newRoom.terrain_id) : undefined,
        capacity: newRoom.capacity ? Number(newRoom.capacity) : undefined,
      });
      setShowModal(false);
      setNewRoom({ name: "", description: "", terrain_id: "", capacity: "", type: roomType, status: "active" });
      fetchRooms();
    } catch (error) {
      console.error("Error creating room:", error);
    }
  };

  const handleViewAssets = (room) => {
    setSelectedRoom(room);
    setShowAssetsModal(true);
  };

  const getAssetsForRoom = (roomId) => {
    return assets.filter(asset => asset.room_id === roomId);
  };

  const handleDeleteRoom = async (roomId) => {
    try {
      await roomsAPI.delete(roomId);
      fetchRooms();
    } catch (error) {
      console.error('Error deleting room:', error);
    }
  };

  const filteredRooms = rooms.filter((room) => {
    const query = searchTerm.toLowerCase();
    const matchesSearch =
      room.name.toLowerCase().includes(query) ||
      (room.terrain && room.terrain.name && room.terrain.name.toLowerCase().includes(query)) ||
      room.status.toLowerCase().includes(query);
    const matchesFilter = statusFilter === '' || room.status === statusFilter;
    const matchesType = room.type === roomType;
    return matchesSearch && matchesFilter && matchesType;
  });

  const getStatusClass = (status) => {
    if (status === 'active') return 'status-aktief';
    if (status === 'maintenance') return 'status-onderhoud';
    if (status === 'closed') return 'status-gesluit';
    return 'status-waarskuwing';
  };

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
            <button className="btn-add" onClick={() => setShowModal(true)}>+ Nuwe {roomType === "room" ? "lokaal" : "terrein"}</button>
          </div>

          <table className="rooms-table">
            <thead>
              <tr>
                {roomType === "room" && <th>ID Lokaal</th>}
                {roomType === "terrain" && <th>ID Terrein</th>}
                <th>Naam</th>
                <th>Beskrywing</th>
                {roomType === "room" && <th>Terrein</th>}
                {roomType === "room" && <th>Kapasiteit</th>}
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredRooms.map((room) => (
                <tr key={room.id}>
                  <td>{room.id}</td>
                  <td>{room.name}</td>
                  <td>{room.description || '-'}</td>
                  {roomType === "room" && <td>{room.terrain ? room.terrain.name : '-'}</td>}
                  {roomType === "room" && <td>{room.capacity ?? '-'}</td>}
                  <td>
                    <span className={`status ${getStatusClass(room.status)}`}>
                      {room.status}
                    </span>
                  </td>
                  <td>
                    <button className="btn-view" onClick={() => handleViewAssets(room)}>
                      View Bates
                    </button>
                    <button className="btn-delete" onClick={() => handleDeleteRoom(room.id)}>
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
              <h3>Nuwe {roomType === "room" ? "lokaal (ID Lokaal sal outomaties gegenereer word)" : "terrein (ID Terrein sal outomaties gegenereer word)"}</h3>
              <button className="close" onClick={() => setShowModal(false)}>×</button>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Naam</label>
                <input
                  type="text"
                  value={newRoom.name}
                  onChange={(e) => setNewRoom({ ...newRoom, name: e.target.value })}
                />
              </div>
              {roomType === "room" && (
                <div className="input-group">
                  <label>Terrein</label>
                  <select
                    value={newRoom.terrain_id}
                    onChange={(e) => setNewRoom({ ...newRoom, terrain_id: e.target.value })}
                  >
                    <option value="">Kies 'n terrein</option>
                    {terrains.map((terrain) => (
                      <option key={terrain.id} value={terrain.id}>{terrain.name}</option>
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
                    value={newRoom.capacity}
                    onChange={(e) => setNewRoom({ ...newRoom, capacity: e.target.value })}
                  />
                </div>
              </div>
            )}
            <div className="input-row">
              <div className="input-group">
                <label>Status</label>
                <select
                  value={newRoom.status}
                  onChange={(e) => setNewRoom({ ...newRoom, status: e.target.value })}
                >
                  <option value="active">Aktief</option>
                  <option value="maintenance">Onderhoud</option>
                  <option value="closed">Gesluit</option>
                </select>
              </div>
              <div className="input-group">
                <label>Beskrywing</label>
                <input
                  type="text"
                  value={newRoom.description}
                  onChange={(e) => setNewRoom({ ...newRoom, description: e.target.value })}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={() => setShowModal(false)}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddRoom}>Stoor</button>
            </div>
          </div>
        </div>
      )}

      {showAssetsModal && selectedRoom && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Bates in {selectedRoom.terrain ? `${selectedRoom.terrain} - ` : ""}{selectedRoom.name}</h3>
              <span className="close" onClick={() => setShowAssetsModal(false)}>&times;</span>
            </div>
            <div className="modal-body">
              {getAssetsForRoom(selectedRoom.id).length > 0 ? (
                <table className="assets-table">
                  <thead>
                    <tr>
                      <th>Naam</th>
                      <th>Tipe</th>
                      <th>Beskrywing</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {getAssetsForRoom(selectedRoom.id).map((asset) => (
                      <tr key={asset.id}>
                        <td>{asset.name}</td>
                        <td>{asset.asset_type}</td>
                        <td>{asset.description || "-"}</td>
                        <td>
                          <span className={`status ${getStatusClass(asset.status)}`}>
                            {asset.status}
                          </span>
                        </td>
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
