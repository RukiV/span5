import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { locationAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import "../styles/Rooms.css";
import { useLogout } from "./Page.jsx";

function TerrainsPage() {
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();
  const [terrains, setTerrains] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [showModal, setShowModal] = useState(false);
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

  const filteredTerrains = terrains.filter((terrain) => {
    const query = searchTerm.toLowerCase();
    return (
      terrain.location_name?.toLowerCase().includes(query) ||
      terrain.location_type?.toLowerCase().includes(query) ||
      terrain.location_streetname?.toLowerCase().includes(query)
    );
  });

  if (loading) {
    return <div style={{ display: "flex" }}><div className="main"><div className="content">Laai...</div></div></div>;
  }

  return (
    <div style={{ display: "flex" }}>
      <div className="sidebar">
        <h2>FBS</h2>
        <ul>
            <li><Link to="/dashboard">Paneelbord</Link></li>
            <li class="dropdown" >
                <div className="dropdown-trigger">
                    <span>Bates & Voorraad</span>
                </div>
                    <div className="dropdown-content">
                    <Link to="/assets">Bates</Link>
                    <Link to="/stock">Voorraad</Link>
                    </div>
            </li>
                <li class="dropdown" style={{ background: '#935e28' }}>
                <div className="dropdown-trigger">
                    <span>Lokale & Terreine</span>
                </div>
                <div className="dropdown-content">
                    <li><Link to="/rooms">Lokale</Link></li>
                    <li><Link to="/terrains" style={{ background: '#935e28' }}>Terreine</Link></li>
                </div>
            </li>
            <li><Link to="/fault-tickets">Foutkaartjies</Link></li>
            <li><Link to="/work-orders">Werksopdragte</Link></li>
            {isAdmin && <li><Link to="/users">Gebruikers</Link></li>}
        </ul>
        <div className="logout-container">
          <button type="button" className="btn-logout-sidebar" onClick={() => logout()}>Teken Uit</button>
        </div>
      </div>

      <div className="main">
        <div className="navbar">
          <h3>Terrein Bestuur</h3>
          <div className="user">Admin</div>
        </div>

        <div className="content">
          <div className="controls">
            <input
              type="text"
              className="search-box"
              placeholder="Soek terreine..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <button className="btn-add" onClick={handleNewTerrain}>+ Nuwe Terrein</button>
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
              <button className="btn-save" onClick={handleSaveTerrain}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default TerrainsPage;
