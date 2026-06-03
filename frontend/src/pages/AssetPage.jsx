import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { assetsAPI, roomsAPI, stockAPI } from "../services/api";
import "../styles/Asset.css";

function AssetPage() {
  const [assets, setAssets] = useState([]);
  const [stock, setStock] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filter, setFilter] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [assetType, setAssetType] = useState("asset"); // "asset" or "inventory"
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
  const [newStock, setNewStock] = useState({
    stock_name: "",
    stock_brand: "",
    stock_amount: 0,
    stock_type: "",
    stock_desc: "",
    room_id: "",
  });

  useEffect(() => {
    fetchAssets();
    fetchStock();
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

  const fetchStock = async () => {
    try {
      const response = await stockAPI.getAll();
      setStock(response.data);
    } catch (error) {
      console.error("Error fetching stock:", error);
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
      if (assetType === "asset") {
        // Validation for assets
        if (!newAsset.asset_name || !newAsset.asset_name.trim()) {
          alert("Voer asseblief 'n batenaam in");
          return;
        }
        if (!newAsset.asset_serial || !newAsset.asset_serial.trim()) {
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
        setNewAsset({ asset_name: "", asset_serial: "", asset_isoutdoor: false, asset_status: "active", assettype_id: 1, room_id: "" });
      } else {
        // Validation for inventory
        if (!newStock.stock_name || !newStock.stock_name.trim()) {
          alert("Voer asseblief 'n voorraadnaam in");
          return;
        }
        if (!newStock.stock_brand || !newStock.stock_brand.trim()) {
          alert("Voer asseblief 'n merk in");
          return;
        }
        if (!newStock.stock_type || !newStock.stock_type.trim()) {
          alert("Voer asseblief 'n tipe in");
          return;
        }
        
        const stockData = {
          stock_name: newStock.stock_name,
          stock_brand: newStock.stock_brand,
          stock_amount: Number(newStock.stock_amount),
          stock_type: newStock.stock_type,
          stock_desc: newStock.stock_desc,
          room_id: newStock.room_id ? Number(newStock.room_id) : null,
        };
        if (isEditing) {
          await stockAPI.update(editingId, stockData);
        } else {
          await stockAPI.create(stockData);
        }
        setNewStock({ stock_name: "", stock_brand: "", stock_amount: 0, stock_type: "", stock_desc: "", room_id: "" });
      }
      handleCloseModal();
      if (assetType === "asset") {
        fetchAssets();
      } else {
        fetchStock();
      }
    } catch (error) {
      console.error("Error saving item:", error);
      alert("Fout tydens besparing. Probeer asseblief weer.");
    }
  };

  const handleDeleteAsset = async (id) => {
    if (!window.confirm("Is jy seker jy wil hierdie item verwyder?")) {
      return;
    }
    try {
      if (assetType === "asset") {
        await assetsAPI.delete(id);
        fetchAssets();
      } else {
        await stockAPI.delete(id);
        fetchStock();
      }
    } catch (error) {
      console.error("Error deleting item:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  const handleEditAsset = (item) => {
    setIsEditing(true);
    setEditingId(assetType === "asset" ? item.asset_id : item.stock_id);
    if (assetType === "asset") {
      setNewAsset({
        asset_name: item.asset_name,
        asset_serial: item.asset_serial || "",
        asset_isoutdoor: item.asset_isoutdoor || false,
        asset_status: item.asset_status || "active",
        assettype_id: item.assettype_id || 1,
        room_id: item.room_id || "",
      });
    } else {
      setNewStock({
        stock_name: item.stock_name || "",
        stock_brand: item.stock_brand || "",
        stock_amount: item.stock_amount || 0,
        stock_type: item.stock_type || "",
        stock_desc: item.stock_desc || "",
        room_id: item.room_id || "",
      });
    }
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewAsset({ asset_name: "", asset_serial: "", asset_isoutdoor: false, asset_status: "active", assettype_id: 1, room_id: "" });
    setNewStock({ stock_brand: "", stock_amount: 0, stock_type: "", stock_desc: "", room_id: "" });
  };

  const handleNewAsset = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewAsset({ asset_name: "", asset_serial: "", asset_isoutdoor: false, asset_status: "active", assettype_id: 1, room_id: "" });
    setNewStock({ stock_brand: "", stock_amount: 0, stock_type: "", stock_desc: "", room_id: "" });
    setShowModal(true);
  };

  const filteredItems = assetType === "asset" ? assets.filter((asset) => {
    const query = searchTerm.toLowerCase();
    const matchesSearch =
      asset.asset_name?.toLowerCase().includes(query) ||
      String(asset.assettype_id).includes(query);
    const matchesFilter = filter === "" || asset.asset_status === filter;
    return matchesSearch && matchesFilter;
  }) : stock.filter((item) => {
    const query = searchTerm.toLowerCase();
    const matchesSearch =
      item.stock_name?.toLowerCase().includes(query) ||
      item.stock_brand?.toLowerCase().includes(query) ||
      item.stock_type?.toLowerCase().includes(query) ||
      item.stock_desc?.toLowerCase().includes(query);
    return matchesSearch;
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
    
  }

  return (
    <div style={{ display: "flex" }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
          <li><Link to="/dashboard">Paneelbord</Link></li>
          <li><Link to="/assets" style={{ background: '#935e28' }}>Bates</Link></li>
          <li><Link to="/rooms">Lokale</Link></li>
          <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
          <li><Link to="/work-orders">Werksopdragte</Link></li>
          <li><Link to="/users">Gebruikers</Link></li>
          
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
            <button className="btn-add-bate" onClick={handleNewAsset}>+ Nuwe {assetType === "asset" ? "Bate" : "Voorraad"}</button>
          </div>

          <table className="bates-table">
            <thead>
              <tr>
                {assetType === "asset" && <th>ID Bate</th>}
                {assetType === "inventory" && <th>ID Voorraad</th>}
                <th>Naam</th>
                {assetType === "asset" && <th>Serienommer</th>}
                {assetType === "inventory" && <th>Merk</th>}
                {assetType === "inventory" && <th>Tipe</th>}
                {assetType === "inventory" && <th>Hoeveelheid</th>}
                {assetType === "asset" && <th>Buite</th>}
                <th>Lokaal</th>
                {assetType === "asset" && <th>Status</th>}
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredItems.map((item) => (
                <tr key={assetType === "asset" ? item.asset_id : item.stock_id}>
                  <td>{assetType === "asset" ? item.asset_id : item.stock_id}</td>
                  <td>{assetType === "asset" ? item.asset_name : item.stock_name}</td>
                  {assetType === "asset" && <td>{item.asset_serial}</td>}
                  {assetType === "inventory" && <td>{item.stock_brand}</td>}
                  {assetType === "inventory" && <td>{item.stock_type}</td>}
                  {assetType === "inventory" && <td>{item.stock_amount}</td>}
                  {assetType === "asset" && <td>{item.asset_isoutdoor ? "Ja" : "Nee"}</td>}
                  <td>{getRoomName(item)}</td>
                  {assetType === "asset" && (
                    <td>
                      <span className={`status ${getStatusClass(item.asset_status)}`}>
                        {getStatusLabel(item.asset_status)}
                      </span>
                    </td>
                  )}
                  <td>
                    <button className="btn-edit" onClick={() => handleEditAsset(item)}>
                      Wysig
                    </button>
                    <button className="btn-delete" onClick={() => handleDeleteAsset(assetType === "asset" ? item.asset_id : item.stock_id)}>
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
              <h3>{isEditing ? "Wysig" : "Nuwe"} {assetType === "asset" ? "Bate" : "Voorraad"} {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
              <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            {assetType === "asset" && (
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
            )}
            {assetType === "inventory" && (
              <div className="input-row">
                <div className="input-group">
                  <label>Naam</label>
                  <input
                    type="text"
                    value={newStock.stock_name}
                    onChange={(e) => setNewStock({ ...newStock, stock_name: e.target.value })}
                  />
                </div>
                <div className="input-group">
                  <label>Merk</label>
                  <input
                    type="text"
                    value={newStock.stock_brand}
                    onChange={(e) => setNewStock({ ...newStock, stock_brand: e.target.value })}
                  />
                </div>
              </div>
            )}
            {assetType === "inventory" && (
              <div className="input-row">
                <div className="input-group">
                  <label>Tipe</label>
                  <input
                    type="text"
                    value={newStock.stock_type}
                    onChange={(e) => setNewStock({ ...newStock, stock_type: e.target.value })}
                  />
                </div>
              </div>
            )}
            {assetType === "inventory" && (
              <div className="input-row">
                <div className="input-group">
                  <label>Hoeveelheid</label>
                  <input
                    type="number"
                    value={newStock.stock_amount}
                    onChange={(e) => setNewStock({ ...newStock, stock_amount: e.target.value })}
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
                      checked={newAsset.asset_isoutdoor}
                      onChange={(e) => setNewAsset({ ...newAsset, asset_isoutdoor: e.target.checked })}
                    />
                    Buite
                  </label>
                </div>
              </div>
            )}
            <div className="input-row">
              <div className="input-group">
                <label>Lokaal</label>
                <select
                  value={assetType === "asset" ? newAsset.room_id : newStock.room_id}
                  onChange={(e) => assetType === "asset"
                    ? setNewAsset({ ...newAsset, room_id: e.target.value })
                    : setNewStock({ ...newStock, room_id: e.target.value })}
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
            {assetType === "asset" && (
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
            )}
            {assetType === "inventory" && (
              <div className="input-row">
                <div className="input-group">
                  <label>Beskrywing</label>
                  <textarea
                    value={newStock.stock_desc}
                    onChange={(e) => setNewStock({ ...newStock, stock_desc: e.target.value })}
                  />
                </div>
              </div>
            )}
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-save" onClick={handleAddAsset}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default AssetPage;
