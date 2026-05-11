import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { assetsAPI, roomsAPI } from "../services/api";
import "../styles/Asset.css";

function AssetPage() {
  const [assets, setAssets] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filter, setFilter] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [assetType, setAssetType] = useState("asset"); // "asset" or "inventory"
  const [newAsset, setNewAsset] = useState({
    name: "",
    asset_type: "",
    description: "",
    serial_number: "",
    brand: "",
    quantity: "",
    is_outside: false,
    type: "asset",
    status: "active",
    room_id: "",
  });

  useEffect(() => {
    fetchAssets();
    fetchRooms();
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

  const handleAddAsset = async () => {
    try {
      const assetData = {
        ...newAsset,
        type: assetType,
        room_id: newAsset.room_id ? Number(newAsset.room_id) : null,
        quantity: newAsset.quantity ? Number(newAsset.quantity) : null,
      };
      await assetsAPI.create(assetData);
      setShowModal(false);
      setNewAsset({ name: "", asset_type: "", description: "", serial_number: "", brand: "", quantity: "", is_outside: false, type: assetType, status: "active", room_id: "" });
      fetchAssets();
    } catch (error) {
      console.error("Error adding asset:", error);
    }
  };

  const handleDeleteAsset = async (assetId) => {
    try {
      await assetsAPI.delete(assetId);
      fetchAssets();
    } catch (error) {
      console.error("Error deleting asset:", error);
    }
  };

  const filteredAssets = assets.filter((asset) => {
    const query = searchTerm.toLowerCase();
    const matchesSearch =
      asset.name?.toLowerCase().includes(query) ||
      asset.asset_type?.toLowerCase().includes(query) ||
      (asset.description && asset.description.toLowerCase().includes(query)) ||
      (asset.room && asset.room?.name?.toLowerCase().includes(query));
    const matchesFilter = filter === "" || asset.status === filter;
    const matchesType = asset.type === assetType;
    return matchesSearch && matchesFilter && matchesType;
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

  const getRoomName = (asset) => {
    if (asset.room) {
      return `${asset.room.building || ""} ${asset.room.name}`.trim();
    }
    return "-";
  };

  if (loading) {
    return (
      <div style={{ display: "flex" }}>
        <div className="sidebar">
          <h2>FBS</h2>
          <ul>
            <li><Link to="/dashboard">Paneelbord</Link></li>
            <li><Link to="/assets" style={{ background: "#935e28" }}>Bates</Link></li>
            <li><Link to="/rooms">Lokale</Link></li>
            <li><Link to="/work-orders">Werksopdragte</Link></li>
            <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          </ul>
          <div className="logout-container">
            <Link to="/login" className="btn-logout-sidebar">Logout</Link>
          </div>
        </div>
        <div className="main">
          <div className="navbar">
            <h3>Bates Bestuur</h3>
            <div className="user">Admin</div>
          </div>
          <div className="content">Laai bates...</div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ display: "flex" }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li><Link to="/assets" style={{ background: "#935e28" }}>Bates</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
        </ul>
        <div className="logout-container">
          <Link to="/login" className="btn-logout-sidebar">Logout</Link>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Bates Bestuur</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
          <div className="controls">
            <div className="toggle-switch">
              <span className={assetType === "asset" ? "active" : ""} onClick={() => setAssetType("asset")}>Bates</span>
              <span className={assetType === "inventory" ? "active" : ""} onClick={() => setAssetType("inventory")}>Voorraad</span>
            </div>
            <input
              type="text"
              placeholder={`Soek ${assetType === "asset" ? "bates" : "voorraad"}...`}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <select value={filter} onChange={(e) => setFilter(e.target.value)}>
              <option value="">Filter: Alle</option>
              <option value="active">Aktief</option>
              <option value="maintenance">Onderhoud</option>
              <option value="retired">Afgedank</option>
            </select>
            <button className="btn-add-bate" onClick={() => setShowModal(true)}>+ Nuwe {assetType === "asset" ? "Bate" : "Voorraad"}</button>
          </div>

          <table className="bates-table">
            <thead>
              <tr>
                {assetType === "asset" && <th>ID Bate</th>}
                {assetType === "inventory" && <th>ID Voorraad</th>}
                <th>Naam</th>
                <th>Tipe</th>
                {assetType === "inventory" && <th>Merk</th>}
                <th>Serienommer</th>
                {assetType === "inventory" && <th>Hoeveelheid</th>}
                {assetType === "asset" && <th>Buite</th>}
                <th>Lokaal</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredAssets.map((asset) => (
                <tr key={asset.id}>
                  <td>{asset.id}</td>
                  <td>{asset.name}</td>
                  <td>{asset.asset_type}</td>
                  {assetType === "inventory" && <td>{asset.brand || "-"}</td>}
                  <td>{asset.serial_number || "-"}</td>
                  {assetType === "inventory" && <td>{asset.quantity || "-"}</td>}
                  {assetType === "asset" && <td>{asset.is_outside ? "Ja" : "Nee"}</td>}
                  <td>{getRoomName(asset)}</td>
                  <td>
                    <span className={`status ${getStatusClass(asset.status)}`}>
                      {getStatusLabel(asset.status)}
                    </span>
                  </td>
                  <td>
                    <button className="btn-delete" onClick={() => handleDeleteAsset(asset.id)}>
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
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Nuwe {assetType === "asset" ? "Bate" : "Voorraad"} (ID sal outomaties gegenereer word)</h3>
              <span className="close" onClick={() => setShowModal(false)}>&times;</span>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Naam</label>
                <input
                  type="text"
                  value={newAsset.name}
                  onChange={(e) => setNewAsset({ ...newAsset, name: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Tipe</label>
                <input
                  type="text"
                  value={newAsset.asset_type}
                  onChange={(e) => setNewAsset({ ...newAsset, asset_type: e.target.value })}
                />
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>{assetType === "asset" ? "Serienommer (Bate ID)" : "Serienommer (Voorraad ID)"}</label>
                <input
                  type="text"
                  value={newAsset.serial_number}
                  onChange={(e) => setNewAsset({ ...newAsset, serial_number: e.target.value })}
                  placeholder={assetType === "asset" ? "Unieke bate identifikasie" : "Unieke voorraad identifikasie"}
                  required
                />
              </div>
              {assetType === "inventory" && (
                <div className="input-group">
                  <label>Merk</label>
                  <input
                    type="text"
                    value={newAsset.brand}
                    onChange={(e) => setNewAsset({ ...newAsset, brand: e.target.value })}
                  />
                </div>
              )}
            </div>
            {assetType === "inventory" && (
              <div className="input-row">
                <div className="input-group">
                  <label>Hoeveelheid</label>
                  <input
                    type="number"
                    value={newAsset.quantity}
                    onChange={(e) => setNewAsset({ ...newAsset, quantity: e.target.value })}
                  />
                </div>
              </div>
            )}
            {assetType === "asset" && (
              <div className="input-row">
                <div className="input-group">
                  <label>
                    <input
                      type="checkbox"
                      checked={newAsset.is_outside}
                      onChange={(e) => setNewAsset({ ...newAsset, is_outside: e.target.checked })}
                    />
                    Buite
                  </label>
                </div>
              </div>
            )}
            <div className="input-row">
              <div className="input-group">
                <label>Beskrywing</label>
                <textarea
                  value={newAsset.description}
                  onChange={(e) => setNewAsset({ ...newAsset, description: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Lokaal</label>
                <select
                  value={newAsset.room_id}
                  onChange={(e) => setNewAsset({ ...newAsset, room_id: e.target.value })}
                >
                  <option value="">Geen lokaal</option>
                  {rooms.map((room) => (
                    <option key={room.id} value={room.id}>
                      {room.building ? `${room.building} - ` : ""}{room.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Status</label>
                <select
                  value={newAsset.status}
                  onChange={(e) => setNewAsset({ ...newAsset, status: e.target.value })}
                >
                  <option value="active">Aktief</option>
                  <option value="maintenance">Onderhoud</option>
                  <option value="retired">Afgedank</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={() => setShowModal(false)}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddAsset}>Stoor</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default AssetPage;
