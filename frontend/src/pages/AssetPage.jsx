import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { assetsAPI, roomsAPI, authAPI } from "../services/api";
import { useNavigate } from 'react-router-dom';
import { useCurrentUser } from "../hooks/useCurrentUser";
import "../styles/App.css";
import "../styles/Asset.css";
import "./Page.jsx";
import { useLogout } from "./Page.jsx";

function AssetPage() {
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();
  const [assets, setAssets] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filter, setFilter] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newAsset, setNewAsset] = useState({
    asset_name: "",
    asset_serial: "",
    asset_isoutdoor: false,
    asset_status: "active",
    assettype_id: 1,
    room_id: "",
  });

  useEffect(() => {
    fetchAssets();
    fetchRooms();
  }, []);

  // Validate token with backend on mount — if invalid, force logout
  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await authAPI.me();
      } catch (err) {
        try { sessionStorage.clear(); localStorage.clear(); } catch(_) {}
        window.location.replace(window.location.origin + '/login');
      }
    })();
    return () => { mounted = false; };
  }, []);

  const fetchAssets = async () => {
    try {
      const response = await assetsAPI.getAll();
      setAssets(response.data);
    } catch (error) {
      console.error("Error fetching assets:", error);
    } finally {
      setLoading(false);
    }
  };

  const fetchRooms = async () => {
    try {
      const response = await roomsAPI.getAll();
      setRooms(response.data);
    } catch (error) {
      console.error("Error fetching rooms:", error);
    }
  };

  const handleSaveAsset = async () => {
    try {
      if (!newAsset.asset_name.trim()) {
        alert("Voer asseblief 'n batenaam in");
        return;
      }
      if (!newAsset.asset_serial.trim()) {
        alert("Voer asseblief 'n serienommer in");
        return;
      }

      const assetData = {
        asset_name: newAsset.asset_name,
        asset_serial: newAsset.asset_serial,
        asset_status: newAsset.asset_status,
        asset_isoutdoor: newAsset.asset_isoutdoor,
        assettype_id: 1,
        room_id: newAsset.room_id ? Number(newAsset.room_id) : null,
      };

      if (isEditing) {
        await assetsAPI.update(editingId, assetData);
      } else {
        await assetsAPI.create(assetData);
      }

      handleCloseModal();
      fetchAssets();
    } catch (error) {
      console.error("Error saving asset:", error);
      alert("Fout tydens besparing. Probeer asseblief weer.");
    }
  };

  const handleDeleteAsset = async (id) => {
    if (!window.confirm("Is jy seker jy wil hierdie item verwyder?")) {
      return;
    }
    try {
      await assetsAPI.delete(id);
      fetchAssets();
    } catch (error) {
      console.error("Error deleting asset:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  const handleEditAsset = (item) => {
    setIsEditing(true);
    setEditingId(item.asset_id);
    setNewAsset({
      asset_name: item.asset_name || "",
      asset_serial: item.asset_serial || "",
      asset_isoutdoor: item.asset_isoutdoor || false,
      asset_status: item.asset_status || "active",
      assettype_id: item.assettype_id || 1,
      room_id: item.room_id || "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewAsset({ asset_name: "", asset_serial: "", asset_isoutdoor: false, asset_status: "active", assettype_id: 1, room_id: "" });
  };

  const handleNewAsset = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewAsset({ asset_name: "", asset_serial: "", asset_isoutdoor: false, asset_status: "active", assettype_id: 1, room_id: "" });
    setShowModal(true);
  };

  const filteredItems = assets.filter((asset) => {
    const query = searchTerm.toLowerCase();
    const matchesSearch =
      asset.asset_name?.toLowerCase().includes(query) ||
      String(asset.assettype_id).includes(query);
    const matchesFilter = filter === "" || asset.asset_status === filter;
    return matchesSearch && matchesFilter;
  });

  const getStatusClass = (status) => {
    switch (status) {
      case "active":
        return "status-aktief";
      case "maintenance":
        return "status-onderhoud";
      case "retired":
        return "status-waarskuwing";
      default:
        return "status-waarskuwing";
    }
  };

  const getStatusLabel = (status) => {
    switch (status) {
      case "active":
        return "Aktief";
      case "maintenance":
        return "Onderhoud";
      case "retired":
        return "Afgedank";
      default:
        return status;
    }
  };

  const getRoomName = (item) => {
    if (!item.room_id) {
      return "-";
    }

    const room = rooms.find((roomItem) => roomItem.room_id === item.room_id);
    if (room) {
      return room.room_name;
    }

    return `Room ${item.room_id}`;
  };

  if (loading) {
    return <div style={{ display: "flex" }}><div className="main"><div className="content">Laai...</div></div></div>;
  }

  return (
    <div >
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li class="dropdown" style={{ background: '#935e28' }}>
              <div className="dropdown-trigger">
                <span>Bates & Voorraad</span>
              </div>
                <div className="dropdown-content">
                <Link to="/assets" style={{ background: '#935e28' }}>Bates</Link>
                <Link to="/stock">Voorraad</Link>
                </div>
          </li>
           <li class="dropdown">
              <div className="dropdown-trigger">
                  <span>Lokale & Terreine</span>
              </div>
              <div className="dropdown-content">
                  <li><Link to="/rooms">Lokale</Link></li>
                  <li><Link to="/terrains">Terreine</Link></li>
              </div>
          </li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          {isAdmin && <li><Link to="/users">Gebruikers</Link></li>}
        </ul>
        <div className="logout-container">
          <button type="button" className="btn-logout-sidebar" onClick={() => { logout(); }}>
            Teken Uit
          </button>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Bates Bestuur</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
          <div className="controls">
            <input
              type="text"
              placeholder="Soek bates..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <select value={filter} onChange={(e) => setFilter(e.target.value)}>
              <option value="">Filter: Alle</option>
              <option value="active">Aktief</option>
              <option value="maintenance">Onderhoud</option>
              <option value="retired">Afgedank</option>
            </select>
            <button className="btn-add" onClick={handleNewAsset}>+ Nuwe Bate</button>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th>ID Bate</th>
                <th>Naam</th>
                <th>Serienommer</th>
                <th>Buite</th>
                <th>Lokaal</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredItems.map((item) => (
                <tr key={item.asset_id}>
                  <td>{item.asset_id}</td>
                  <td>{item.asset_name}</td>
                  <td>{item.asset_serial}</td>
                  <td>{item.asset_isoutdoor ? "Ja" : "Nee"}</td>
                  <td>{getRoomName(item)}</td>
                  <td>
                    <span className={`status ${getStatusClass(item.asset_status)}`}>
                      {getStatusLabel(item.asset_status)}
                    </span>
                  </td>
                  <td>
                    <button className="btn-edit" onClick={() => handleEditAsset(item)}>Wysig</button>
                    <button className="btn-delete" onClick={() => handleDeleteAsset(item.asset_id)}>Verwyder</button>
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
              <h3>{isEditing ? "Wysig" : "Nuwe"} Bate {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
              <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Naam</label>
                <input
                  type="text"
                  value={newAsset.asset_name}
                  onChange={(e) => setNewAsset({ ...newAsset, asset_name: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Serienommer</label>
                <input
                  type="text"
                  value={newAsset.asset_serial}
                  onChange={(e) => setNewAsset({ ...newAsset, asset_serial: e.target.value })}
                  placeholder="bv. AK-MT000001"
                />
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>
                  <input
                    type="checkbox"
                    checked={newAsset.asset_isoutdoor}
                    onChange={(e) => setNewAsset({ ...newAsset, asset_isoutdoor: e.target.checked })}
                  />
                  Buite
                </label>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Lokaal</label>
                <select
                  value={newAsset.room_id}
                  onChange={(e) => setNewAsset({ ...newAsset, room_id: e.target.value })}
                >
                  <option value="">Geen lokaal</option>
                  {rooms.map((room) => (
                    <option key={room.room_id} value={room.room_id}>
                      {room.room_name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Status</label>
                <select
                  value={newAsset.asset_status}
                  onChange={(e) => setNewAsset({ ...newAsset, asset_status: e.target.value })}
                >
                  <option value="active">Aktief</option>
                  <option value="maintenance">Onderhoud</option>
                  <option value="retired">Afgedank</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-save" onClick={handleSaveAsset}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default AssetPage;
