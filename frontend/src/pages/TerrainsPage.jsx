import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import Sidebar from '../components/Sidebar';
import { buildingsAPI, locationAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import "../styles/Rooms.css";
import { useLogout } from "./Page.jsx";
import UserProfileHeader from '../components/UserProfileHeader';

function TerrainsPage() {
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  const [showModal, setShowModal] = useState(false);
  const [showBuildingsModal, setShowBuildingsModal] = useState(false);
  const [selectedTerrain, setSelectedTerrain] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newTerrain, setNewTerrain] = useState({
    location_name: "",
    location_type: "",
    location_streetnum: "",
    location_streetname: "",
    zipcode_id: "",
  });

  useEffect(() => {
    fetchTerrains();
    fetchBuildings();
  }, []);

  const fetchTerrains = async () => {
    try {
      const response = await locationAPI.getAll();
      setTerrains(response.data);
    } catch (error) {
      console.error("Error fetching terrains:", error);
    } finally {
      setLoading(false);
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

  const handleSaveTerrain = async () => {
    try {
      if (!newTerrain.location_name.trim()) {
        alert("Voer asseblief 'n terreinnaam in");
        return;
      }
      if (!newTerrain.location_type.trim()) {
        alert("Voer asseblief 'n terreintipe in");
        return;
      }

      const terrainData = {
        location_name: newTerrain.location_name,
        location_type: newTerrain.location_type,
        location_streetnum: newTerrain.location_streetnum,
        location_streetname: newTerrain.location_streetname,
        zipcode_id: newTerrain.zipcode_id ? Number(newTerrain.zipcode_id) : null,
      };

      if (isEditing) {
        await locationAPI.update(editingId, terrainData);
      } else {
        await locationAPI.create(terrainData);
      }

      handleCloseModal();
      fetchTerrains();
    } catch (error) {
      console.error("Error saving terrain:", error);
      alert("Fout tydens besparing. Probeer asseblief weer.");
    }
  };

  const handleDeleteTerrain = async (id) => {
    if (!window.confirm("Is jy seker jy wil hierdie terrein verwyder?")) {
      return;
    }
    try {
      await locationAPI.delete(id);
      fetchTerrains();
    } catch (error) {
      console.error("Error deleting terrain:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  const handleViewBuildings = (terrain) => {
    setSelectedTerrain(terrain);
    setShowBuildingsModal(true);
  };

  const getBuildingsForTerrain = (locationId) => buildings.filter((b) => b.location_id === locationId);

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

  const handleEditTerrain = (item) => {
    setIsEditing(true);
    setEditingId(item.location_id);
    setNewTerrain({
      location_name: item.location_name || "",
      location_type: item.location_type || "",
      location_streetnum: item.location_streetnum || "",
      location_streetname: item.location_streetname || "",
      zipcode_id: item.zipcode_id || "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewTerrain({ location_name: "", location_type: "", location_streetnum: "", location_streetname: "", zipcode_id: "" });
  };

  const handleNewTerrain = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewTerrain({ location_name: "", location_type: "", location_streetnum: "", location_streetname: "", zipcode_id: "" });
    setShowModal(true);
  };

  const filteredTerrains = [...terrains]
    .filter((terrain) => {
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        id: terrain.location_id,
        name: terrain.location_name,
        type: terrain.location_type,
        streetnum: terrain.location_streetnum,
        streetname: terrain.location_streetname,
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'id') return (Number(a.location_id || 0) - Number(b.location_id || 0)) * direction;
      if (sortBy === 'name') return String(a.location_name || '').localeCompare(String(b.location_name || ''), 'af', { sensitivity: 'base' }) * direction;
      return 0;
    });

  if (loading) {
    return <div style={{ display: "flex" }}><div className="main"><div className="content">Laai...</div></div></div>;
  }

  return (
    <div style={{ display: "flex" }}>
      <Sidebar currentPath="/terrains" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Terrein Bestuur</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          <div className="controls">
            <div className="controls-left">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <input
                  type="text"
                  className="search-box"
                  placeholder="Soek terreine..."
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
              <button className="btn-add" onClick={handleNewTerrain}>+ Nuwe Terrein</button>
            </div>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th>ID Terrein</th>
                <th>Naam</th>
                <th>Tipe</th>
                <th>Straatnommer</th>
                <th>Straatnaam</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredTerrains.map((terrain) => (
                <tr key={terrain.location_id}>
                  <td>{terrain.location_id}</td>
                  <td>{terrain.location_name}</td>
                  <td>{terrain.location_type}</td>
                  <td>{terrain.location_streetnum || '-'}</td>
                  <td>{terrain.location_streetname || '-'}</td>
                  <td>
                    <button className="btn-view" onClick={() => handleViewBuildings(terrain)}>Besigtig Geboue</button>
                    <button className="btn-edit" onClick={() => handleEditTerrain(terrain)}>Wysig</button>
                    <button className="btn-delete" onClick={() => handleDeleteTerrain(terrain.location_id)}>Verwyder</button>
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
              <h3>{isEditing ? "Wysig" : "Nuwe"} Terrein {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
               <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Naam</label>
                <input
                  type="text"
                  value={newTerrain.location_name}
                  onChange={(e) => setNewTerrain({ ...newTerrain, location_name: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Tipe</label>
                <input
                  type="text"
                  value={newTerrain.location_type}
                  onChange={(e) => setNewTerrain({ ...newTerrain, location_type: e.target.value })}
                />
              </div>
            </div>
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
            <div className="input-row">
              <div className="input-group">
                <label>Poskode ID</label>
                <input
                  type="number"
                  value={newTerrain.zipcode_id}
                  onChange={(e) => setNewTerrain({ ...newTerrain, zipcode_id: e.target.value })}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleSaveTerrain}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
      {showBuildingsModal && selectedTerrain && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Geboue in {selectedTerrain.location_name}</h3>
              <span className="close" onClick={() => setShowBuildingsModal(false)}>&times;</span>
            </div>
            <div className="modal-body">
              {getBuildingsForTerrain(selectedTerrain.location_id).length > 0 ? (
                <table className="standard-table">
                  <thead>
                    <tr>
                      <th>Naam</th>
                      <th>Tipe</th>
                    </tr>
                  </thead>
                  <tbody>
                    {getBuildingsForTerrain(selectedTerrain.location_id).map((building) => (
                      <tr key={building.building_id}>
                        <td>{building.building_name}</td>
                        <td>{translateBuildingType(building.building_type)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p>Geen geboue op hierdie terrein.</p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default TerrainsPage;
