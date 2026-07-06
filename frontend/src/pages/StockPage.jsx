import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { roomsAPI, stockAPI } from "../services/api";
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
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newStock, setNewStock] = useState({
    stock_name: "",
    stock_brand: "",
    stock_amount: 0,
    stock_type: "",
    stock_desc: "",
    room_id: "",
  });

  useEffect(() => {
    fetchStock();
    fetchRooms();
  }, []);

  const fetchStock = async () => {
    try {
      const response = await stockAPI.getAll();
      setStock(response.data);
    } catch (error) {
      console.error("Error fetching stock:", error);
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

  const handleSaveStock = async () => {
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

      handleCloseModal();
      fetchStock();
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
    setIsEditing(true);
    setEditingId(item.stock_id);
    setNewStock({
      stock_name: item.stock_name || "",
      stock_brand: item.stock_brand || "",
      stock_amount: item.stock_amount || 0,
      stock_type: item.stock_type || "",
      stock_desc: item.stock_desc || "",
      room_id: item.room_id || "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewStock({ stock_name: "", stock_brand: "", stock_amount: 0, stock_type: "", stock_desc: "", room_id: "" });
  };

  const handleNewStock = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewStock({ stock_name: "", stock_brand: "", stock_amount: 0, stock_type: "", stock_desc: "", room_id: "" });
    setShowModal(true);
  };

  const getRoomName = (item) => {
    if (!item.room_id) return "-";
    const room = rooms.find((roomItem) => roomItem.room_id === item.room_id);
    return room ? room.room_name : `Room ${item.room_id}`;
  };

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
                <label>Lokaal</label>
                <select
                  value={newStock.room_id}
                  onChange={(e) => setNewStock({ ...newStock, room_id: e.target.value })}
                >
                  <option value="">Geen lokaal</option>
                  {rooms.map((room) => (
                    <option key={room.room_id} value={room.room_id}>{room.room_name}</option>
                  ))}
                </select>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Beskrywing</label>
                <textarea
                  value={newStock.stock_desc}
                  onChange={(e) => setNewStock({ ...newStock, stock_desc: e.target.value })}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleSaveStock}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default StockPage;
