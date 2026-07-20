import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import Select from "react-select"; // Bygevoeg vir react-select
import { roomsAPI, stockAPI, buildingsAPI, locationAPI, apiClient } from "../services/api"; // Bygevoeg buildingsAPI en locationAPI
import { useCurrentUser } from "../hooks/useCurrentUser";
import "../styles/Asset.css";
import "../styles/App.css";
import { useLogout } from "./Page.jsx";
import Sidebar from '../components/Sidebar';
import UserProfileHeader from '../components/UserProfileHeader';

function StockPage() {
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();
  const [stock, setStock] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [buildings, setBuildings] = useState([]); // Bygevoeg
  const [terrains, setTerrains] = useState([]); // Bygevoeg
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  const [stockImages, setStockImages] = useState([]);
  const [selectedImageFiles, setSelectedImageFiles] = useState([]);
  const [selectedImagePreviewUrls, setSelectedImagePreviewUrls] = useState([]);
  const [imagesToDelete, setImagesToDelete] = useState([]);
  const [activeImageViewer, setActiveImageViewer] = useState(null);
  const MAX_STOCK_IMAGES = 1;
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newStock, setNewStock] = useState({
    stock_name: "",
    stock_brand: "",
    stock_amount: 0,
    stock_minimum: 0,
    stock_boxTotal: 0,
    stock_type: "",
    stock_desc: "",
    room_id: "",
    location_id: "", // Bygevoeg vir cascading logika
    building_id: ""  // Bygevoeg vir cascading logika
  });

  useEffect(() => {
    const loadInitialData = async () => {
      await Promise.all([fetchStock(), fetchRooms(), fetchBuildings(), fetchTerrains()]);
    };
    loadInitialData();
  }, []);

  const fetchStock = async () => {
    try {
      const response = await stockAPI.getAll();
      setStock(response.data || []);
    } catch (error) {
      console.error("Error fetching stock:", error);
    } finally {
      setLoading(false);
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

  const fetchBuildings = async () => {
    try {
      const response = await buildingsAPI.getAll();
      setBuildings(response.data || []);
    } catch (error) {
      console.error("Error fetching buildings:", error);
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

  const fetchStockImages = async (stockId) => {
    if (!stockId) {
      setStockImages([]);
      return;
    }

    try {
      const response = await apiClient.image.getByParent("stock", stockId);
      setStockImages(response.data || []);
    } catch (error) {
      console.error("Fout by laai van voorraad-beelde:", error);
      setStockImages([]);
    }
  };

  const getStockImageUrl = (imageId) => {
    if (!imageId) return null;
    return apiClient.image?.getFileUrl ? apiClient.image.getFileUrl(imageId) : null;
  };

  const handleImageFilesChange = (event) => {
    const files = Array.from(event.target.files || []);
    const remainingSlots = Math.max(0, MAX_STOCK_IMAGES - (selectedImageFiles.length + stockImages.length));
    const incomingFiles = files.slice(0, remainingSlots);

    if (files.length > remainingSlots) {
      alert(`Jy kan maksimaal ${MAX_STOCK_IMAGES} beeld per voorraad-item oplaai.`);
    }

    if (incomingFiles.length === 0) {
      event.target.value = "";
      return;
    }

    const previewUrls = incomingFiles.map((file) => URL.createObjectURL(file));
    setSelectedImageFiles((prev) => [...prev, ...incomingFiles]);
    setSelectedImagePreviewUrls((prev) => [...prev, ...previewUrls]);
    event.target.value = "";
  };

  const handleRemoveSelectedPreview = (index) => {
    if (!window.confirm("Is jy seker jy wil hierdie beeld verwyder?")) {
      return;
    }

    setSelectedImageFiles((prev) => prev.filter((_, itemIndex) => itemIndex !== index));
    setSelectedImagePreviewUrls((prev) => {
      const urlToRevoke = prev[index];
      if (urlToRevoke) {
        URL.revokeObjectURL(urlToRevoke);
      }
      return prev.filter((_, itemIndex) => itemIndex !== index);
    });
  };

  const handleDeleteExistingImage = (imageId) => {
    if (!window.confirm("Is jy seker jy wil hierdie beeld verwyder?")) {
      return;
    }

    setStockImages((prev) => prev.filter((image) => image.image_id !== imageId));
    setImagesToDelete((prev) => (prev.includes(imageId) ? prev : [...prev, imageId]));
  };

  const handleSaveStock = async () => {
    let savedStockId = isEditing ? editingId : null;
    try {
      if (!newStock.stock_name.trim()) {
        alert("Voer asseblief 'n voorraadnaam in");
        return;
      }
      if (!newStock.stock_brand.trim()) {
        alert("Voer asseblief 'n merk in");
        return;
      }
      if (!newStock.stock_type.trim()) {
        alert("Voer asseblief 'n tipe in");
        return;
      }
      if (!newStock.room_id) {
        alert("Kies asseblief 'n lokaal vir hierdie voorraad.");
        return;
      }

      const stockData = {
        stock_name: newStock.stock_name,
        stock_brand: newStock.stock_brand,
        stock_amount: Number(newStock.stock_amount),
        stock_minimum: Number(newStock.stock_minimum),
        stock_boxTotal: Number(newStock.stock_boxTotal),
        stock_type: newStock.stock_type,
        stock_desc: newStock.stock_desc,
        room_id: Number(newStock.room_id),
      };

      if (isEditing) {
        await stockAPI.update(editingId, stockData);
        savedStockId = editingId;
      } else {
        const response = await stockAPI.create(stockData);
        savedStockId = response?.data?.stock_id ?? response?.data?.id ?? null;
      }

      if (!savedStockId) {
        throw new Error("Kon nie die voorraad-ID na stoor terugkry nie.");
      }

      if (isEditing) {
        for (const imageId of imagesToDelete) {
          await apiClient.image.delete(imageId);
        }
      }

      if (selectedImageFiles.length > 0) {
        for (const file of selectedImageFiles.slice(0, MAX_STOCK_IMAGES)) {
          const formData = new FormData();
          formData.append("file", file);
          await apiClient.image.uploadForParent(savedStockId, "stock", formData);
        }
      }

      handleCloseModal();
      fetchStock();
      fetchStockImages(savedStockId);
    } catch (error) {
      console.error("Error saving stock:", error);
      alert("Fout tydens besparing. Probeer asseblief weer.");
    }
  };

  const handleDeleteStock = async (id) => {
    if (!window.confirm("Is jy seker jy wil hierdie voorraad-item verwyder?")) {
      return;
    }
    try {
      await stockAPI.delete(id);
      fetchStock();
    } catch (error) {
      console.error("Error deleting stock:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  const handleEditStock = (item) => {
    // Vind die geassosieerde kamer en gebou vir die geselekteerde item
    const room = rooms.find((r) => r.room_id === item.room_id);
    const building = room ? buildings.find((b) => b.building_id === room.building_id) : null;

    setIsEditing(true);
    setEditingId(item.stock_id);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewStock({
      stock_name: item.stock_name || "",
      stock_brand: item.stock_brand || "",
      stock_amount: item.stock_amount || 0,
      stock_minimum: item.stock_minimum || 0,
      stock_boxTotal: item.stock_boxTotal || 0,
      stock_type: item.stock_type || "",
      stock_desc: item.stock_desc || "",
      room_id: item.room_id ? Number(item.room_id) : "",
      location_id: building ? building.location_id : "",
      building_id: room ? room.building_id : ""
    });
    fetchStockImages(item.stock_id);
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setStockImages([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewStock({ stock_name: "", stock_brand: "", stock_amount: 0, stock_minimum: 0, stock_boxTotal: 0, stock_type: "", stock_desc: "", room_id: "", location_id: "", building_id: "" });
  };

  const handleNewStock = () => {
    setIsEditing(false);
    setEditingId(null);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setStockImages([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewStock({ stock_name: "", stock_brand: "", stock_amount: 0, stock_minimum: 0, stock_boxTotal: 0, stock_type: "", stock_desc: "", room_id: "", location_id: "", building_id: "" });
    setShowModal(true);
  };

  const getRoomName = (item) => {
    if (!item.room_id) return "-";
    const room = rooms.find((roomItem) => roomItem.room_id === item.room_id);
    return room ? room.room_name : `Room ${item.room_id}`;
  };

  // Dropdown opsies kartering (Mapping)
  const terrainOptions = terrains.map(t => ({
    value: String(t.location_id),
    label: t.location_name
  }));

  const buildingOptions = buildings
    .filter(b => Number(b.location_id) === Number(newStock.location_id))
    .map(b => ({
      value: String(b.building_id),
      label: b.building_name
    }));

  const roomOptions = rooms
    .filter(r => Number(r.building_id) === Number(newStock.building_id))
    .map(r => ({
      value: String(r.room_id),
      label: r.room_name
    }));

  const filteredStock = [...stock]
    .filter((item) => {
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        id: item.stock_id,
        name: item.stock_name,
        brand: item.stock_brand,
        type: item.stock_type,
        amount: item.stock_amount,
        minimum: item.stock_minimum,
        boxTotal: item.stock_boxTotal,
        description: item.stock_desc,
        room: getRoomName(item),
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'id') return (Number(a.stock_id || 0) - Number(b.stock_id || 0)) * direction;
      if (sortBy === 'name') return String(a.stock_name || '').localeCompare(String(b.stock_name || ''), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'amount') return (Number(a.stock_amount || 0) - Number(b.stock_amount || 0)) * direction;
      if (sortBy === 'minimum') return (Number(a.stock_minimum || 0) - Number(b.stock_minimum || 0)) * direction;
      if (sortBy === 'boxTotal') return (Number(a.stock_boxTotal || 0) - Number(b.stock_boxTotal || 0)) * direction;
      return 0;
    });

  if (loading) {
    return <div style={{ display: "flex" }}><div className="main"><div className="content">Laai...</div></div></div>;
  }

  return (
    <div style={{ display: "flex" }}>
      <Sidebar currentPath="/stock" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Voorraad Bestuur</h3>
          <UserProfileHeader />
        </div>

          <div className="content">
          <div className="analytics-grid">
            <div className="analytics-card">
              <h4>Totale Voorraad</h4>
              <p className="analytics-value">{stock.length}</p>
            </div>
            <div className="analytics-card">
              <h4>Minimum Voorraad</h4>
              <p className="analytics-value warning">{stock.filter(s => Number(s.stock_amount) < Number(s.stock_minimum)).length}</p>
            </div>
            <div className="analytics-card">
              <h4>Uit Voorraad</h4>
              <p className="analytics-value danger">{stock.filter(s => Number(s.stock_amount) === 0).length}</p>
            </div>
            <div className="analytics-card">
              <h4>Tipes</h4>
              <p className="analytics-value">{new Set(stock.map(s => s.stock_type).filter(Boolean)).size}</p>
            </div>
          </div>
          <div className="controls">
            <div className="controls-left">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <input
                  type="text"
                  placeholder="Soek voorraad..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <select value={filterColumn} onChange={(e) => setFilterColumn(e.target.value)}>
                <option value="all">Alle kolomme</option>
                <option value="id">ID</option>
                <option value="name">Naam</option>
                <option value="brand">Merk</option>
                <option value="type">Tipe</option>
                <option value="amount">Hoeveelheid</option>
                <option value="minimum">Minimum</option>
                <option value="boxTotal">Boks Totaal</option>
                <option value="room">Lokaal</option>
                <option value="description">Beskrywing</option>
              </select>
            </div>
            <div className="controls-right">
              <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
                <option value="default">Standaard</option>
                <option value="id">ID</option>
                <option value="name">Naam</option>
                <option value="amount">Hoeveelheid</option>
                <option value="minimum">Minimum</option>
                <option value="boxTotal">Boks Totaal</option>
              </select>
              <div style={{ display: 'flex', gap: '0.25rem' }}>
                <button type="button" className="btn-add" onClick={() => setSortDirection('asc')} style={{ minWidth: '40px', background: sortDirection === 'asc' ? '#935e28' : undefined }} title="Stygend">▲</button>
                <button type="button" className="btn-add" onClick={() => setSortDirection('desc')} style={{ minWidth: '40px', background: sortDirection === 'desc' ? '#935e28' : undefined }} title="Dalend">▼</button>
              </div>
              <button className="btn-add" onClick={handleNewStock}>+ Nuwe Voorraad</button>
            </div>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th>ID Voorraad</th>
                <th>Naam</th>
                <th>Merk</th>
                <th>Tipe</th>
                <th>Hoeveelheid</th>
                <th>Minimum</th>
                <th>Boks Totaal</th>
                <th>Lokaal</th>
                <th>Beskrywing</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredStock.map((item) => (
                <tr key={item.stock_id}>
                  <td>{item.stock_id}</td>
                  <td>{item.stock_name}</td>
                  <td>{item.stock_brand}</td>
                  <td>{item.stock_type}</td>
                  <td>{item.stock_amount}</td>
                  <td>{item.stock_minimum}</td>
                  <td>{item.stock_boxTotal}</td>
                  <td>{getRoomName(item)}</td>
                  <td>{item.stock_desc || '-'}</td>
                  <td>
                    <button className="btn-edit" onClick={() => handleEditStock(item)}>Wysig</button>
                    <button className="btn-delete" onClick={() => handleDeleteStock(item.stock_id)}>Verwyder</button>
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
              <h3>{isEditing ? "Wysig" : "Nuwe"} Voorraad {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
              <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
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
            <div className="input-row">
              <div className="input-group">
                <label>Tipe</label>
                <input
                  type="text"
                  value={newStock.stock_type}
                  onChange={(e) => setNewStock({ ...newStock, stock_type: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Hoeveelheid</label>
                <input
                  type="number"
                  value={newStock.stock_amount}
                  onChange={(e) => setNewStock({ ...newStock, stock_amount: e.target.value })}
                />
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Minimum voorraad</label>
                <input
                  type="number"
                  value={newStock.stock_minimum}
                  onChange={(e) => setNewStock({ ...newStock, stock_minimum: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Boks Totaal</label>
                <input
                  type="number"
                  value={newStock.stock_boxTotal}
                  onChange={(e) => setNewStock({ ...newStock, stock_boxTotal: e.target.value })}
                />
              </div>
            </div>

            {/* Nuwe Gekoppelde Dropdowns begin hier */}
            <div className="input-row">
              {/* Terrein Dropdown */}
              <div className="input-group">
                <label>Terrein</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder="Kies 'n terrein..."
                  isSearchable={true}
                  options={terrainOptions}
                  value={terrainOptions.find(o => Number(o.value) === Number(newStock.location_id)) || null}
                  onChange={(selected) => {
                    setNewStock({
                      ...newStock,
                      location_id: selected ? Number(selected.value) : "",
                      building_id: "",
                      room_id: ""
                    });
                  }}
                />
              </div>

              {/* Gebou Dropdown */}
              <div className="input-group">
                <label>Gebou</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder={!newStock.location_id ? "Kies eers 'n terrein" : "Kies 'n gebou..."}
                  isSearchable={true}
                  isDisabled={!newStock.location_id}
                  options={buildingOptions}
                  value={buildingOptions.find(o => Number(o.value) === Number(newStock.building_id)) || null}
                  onChange={(selected) => {
                    setNewStock({
                      ...newStock,
                      building_id: selected ? Number(selected.value) : "",
                      room_id: ""
                    });
                  }}
                />
              </div>
            </div>

            <div className="input-row">
              {/* Lokaal Dropdown */}
              <div className="input-group" style={{ width: "50%" }}>
                <label>Lokaal *</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder={!newStock.building_id ? "Kies eers 'n gebou" : "Kies lokaal *"}
                  isSearchable={true}
                  isDisabled={!newStock.building_id}
                  options={roomOptions}
                  value={roomOptions.find(o => Number(o.value) === Number(newStock.room_id)) || null}
                  onChange={(selected) => {
                    setNewStock({
                      ...newStock,
                      room_id: selected ? Number(selected.value) : ""
                    });
                  }}
                />
              </div>
            </div>
            {/* Nuwe Gekoppelde Dropdowns eindig hier */}

            <div className="input-row">
              <div className="input-group">
                <label>Beskrywing</label>
                <textarea
                  value={newStock.stock_desc}
                  onChange={(e) => setNewStock({ ...newStock, stock_desc: e.target.value })}
                />
              </div>
            </div>

            <div className="input-row">
              <div className="input-group" style={{ width: "100%" }}>
                <label>Beelde</label>
                <input type="file" accept="image/*" multiple onChange={handleImageFilesChange} />
                <div className="image-preview-grid">
                  {stockImages.map((image) => (
                    <div key={image.image_id} className="record-image-card">
                      <img
                        src={getStockImageUrl(image.image_id)}
                        alt={image.filename || "Voorraadbeeld"}
                        className="record-image-thumb"
                        onClick={() => setActiveImageViewer(getStockImageUrl(image.image_id))}
                      />
                      <button type="button" className="btn-delete" onClick={() => handleDeleteExistingImage(image.image_id)}>
                        Verwyder
                      </button>
                    </div>
                  ))}
                  {selectedImagePreviewUrls.map((url, index) => (
                    <div key={`${url}-${index}`} className="record-image-card">
                      <img src={url} alt={`Voorgestelde beeld ${index + 1}`} className="record-image-thumb" onClick={() => setActiveImageViewer(url)} />
                      <button type="button" className="btn-delete" onClick={() => handleRemoveSelectedPreview(index)}>
                        Verwyder
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleSaveStock}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}

      {activeImageViewer && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', zIndex: 1100, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '2rem' }} onClick={() => setActiveImageViewer(null)}>
          <div style={{ background: '#fff', borderRadius: '8px', maxWidth: 'min(90vw, 1200px)', maxHeight: '90vh', padding: '2rem', position: 'relative', boxShadow: '0 12px 30px rgba(0,0,0,0.25)' }}>
            <span className="close" onClick={() => setActiveImageViewer(null)} style={{ position: 'absolute', top: '0.75rem', right: '0.75rem', cursor: 'pointer' }}>&times;</span>
            <img src={activeImageViewer} alt="Vergrote beeld" style={{ width: '100%', maxHeight: '75vh', objectFit: 'contain', display: 'block', marginTop: '2rem' }} onClick={(event) => event.stopPropagation()} />
          </div>
        </div>
      )}
    </div>
  );
}

export default StockPage;