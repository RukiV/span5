import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { assetsAPI, roomsAPI, locationAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import "../styles/App.css";
import "../styles/Rooms.css";

function RoomsPage() {
  const { isAdmin } = useCurrentUser();

  const [rooms, setRooms] = useState([]);
  const [assets, setAssets] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
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
  });

  useEffect(() => {
    const loadData = async () => {
      await Promise.all([fetchRooms(), fetchAssets(), fetchTerrains()]);
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

    if (!newRoom.location_id) {
      alert("Voer asseblief 'n terrein in");
      return;
    }

    const roomData = {
      room_name: newRoom.room_name,
      room_capacity: newRoom.room_capacity ? Number(newRoom.room_capacity) : null,
      room_type: newRoom.room_type,
      location_id: Number(newRoom.location_id),
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
    setIsEditing(true);
    setEditingId(room.room_id);
    setNewRoom({
      room_name: room.room_name || "",
      room_capacity: room.room_capacity ?? "",
      room_type: room.room_type || "other",
      location_id: room.location_id ?? "",
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

  const filteredRooms = rooms.filter((room) => {
    const query = searchTerm.toLowerCase();
    return (
      room.room_name?.toLowerCase().includes(query) ||
      room.room_capacity?.toString().includes(query)
    );
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
          <li><Link to="/assets">Bates</Link></li>
          <li><Link to="/stock">Voorraad</Link></li>
          <li><Link to="/rooms" style={{ background: '#935e28' }}>Lokale</Link></li>
          <li><Link to="/terrains">Terreine</Link></li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          {isAdmin && <li><Link to="/users">Gebruikers</Link></li>}
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
            <input
              type="text"
              className="search-box"
              placeholder="Soek lokale..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <button className="btn-add" onClick={handleNewRoom}>+ Nuwe Lokaal</button>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th>ID Lokaal</th>
                <th>Naam</th>
                <th>Tipe</th>
                <th>Terrein</th>
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
                  <td>{getTerrainName(room.location_id)}</td>
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
        <div className="modal-overlay" style={{ display: 'flex' }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>{isEditing ? "Wysig" : "Nuwe"} lokaal {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
              <button className="close" onClick={handleCloseModal}>×</button>
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
            </div>
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
              <button className="btn-save" onClick={handleSaveRoom}>{isEditing ? "Opdateer" : "Stoor"}</button>
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
