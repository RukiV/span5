import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import Select from "react-select";
import { apiClient } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import "../styles/Ticket.css";
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import UserProfileHeader from '../components/UserProfileHeader';

function TicketPage() {
  // Haal admin-status vir beheer-opsies
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();
  
  // State vir foutkaartjies-lys
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");        // Soek op titel/beskrywing
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  
  // Modal en redigerings-state
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [assets, setAssets] = useState([]);
  
  // Vorm-data vir foutkaartjie
  const [newTicket, setNewTicket] = useState({
    title: "",                    // Hoofsaak/titel
    description: "",            // Volledige beskrywing
    category: "",               // Fout-tipe
    status: "Oop",              // Fout-status
    priority: "Medium",         // Prioriteit
    location_id: "",
    building_id: "",
    room_id: "",
    asset_id: "",
  });

  // Haal foutkaartjies wanneer blad laai
  useEffect(() => {
    Promise.all([fetchTickets(), fetchTerrains(), fetchBuildings(), fetchRooms(), fetchAssets()]);
  }, []);

  // Haal alle foutkaartjies van backend
  const fetchTickets = async () => {
    setLoading(true);
    try {
      const response = await apiClient.tickets.getAll();
      console.log("Tickets fetched:", response.data);
      setTickets(response.data || []);
    } catch (error) {
      console.error("Error fetching tickets:", error);
      alert("Fout by laai van foutkaartjies: " + (error.response?.data?.detail || error.message));
    } finally {
      setLoading(false);
    }
  };

  const fetchTerrains = async () => {
    try {
      const response = await apiClient.location.getAll();
      setTerrains(response.data || []);
    } catch (error) {
      console.error("Fout by laai terreine:", error);
    }
  };

  const fetchBuildings = async () => {
    try {
      const response = await apiClient.buildings.getAll();
      setBuildings(response.data || []);
    } catch (error) {
      console.error("Fout by laai geboue:", error);
    }
  };

  const fetchRooms = async () => {
    try {
      const response = await apiClient.rooms.getAll();
      setRooms(response.data || []);
    } catch (error) {
      console.error("Fout by laai lokale:", error);
    }
  };

  const fetchAssets = async () => {
    try {
      const response = await apiClient.assets.getAll();
      setAssets(response.data || []);
    } catch (error) {
      console.error("Fout by laai bates:", error);
    }
  };

  const applyTicketLocationSelection = (ticket) => {
    if (!ticket) return;

    const description = ticket.fault_description || "";
    const colonIndex = description.indexOf(":");
    const title = colonIndex > 0 ? description.substring(0, colonIndex).trim() : description;
    const details = colonIndex > 0 ? description.substring(colonIndex + 1).trim() : "";

    let detectedRoomId = ticket.room_id || "";
    let detectedBuildingId = "";
    let detectedSiteId = "";

    if (!detectedRoomId && ticket.asset_id) {
      const associatedAsset = assets.find((asset) => Number(asset.asset_id) === Number(ticket.asset_id));
      if (associatedAsset) {
        detectedRoomId = associatedAsset.room_id;
      }
    }

    if (detectedRoomId) {
      const associatedRoom = rooms.find((room) => Number(room.room_id) === Number(detectedRoomId));
      if (associatedRoom) {
        detectedBuildingId = associatedRoom.building_id;

        const associatedBuilding = buildings.find((building) => Number(building.building_id) === Number(detectedBuildingId));
        if (associatedBuilding) {
          detectedSiteId = associatedBuilding.location_id;
        }
      }
    }

    setNewTicket((prev) => ({
      ...prev,
      title,
      description: details,
      category: ticket.fault_type || "",
      status: ticket.fault_status || "Oop",
      priority: ticket.fault_priority || "Medium",
      location_id: detectedSiteId ? String(detectedSiteId) : "",
      building_id: detectedBuildingId ? String(detectedBuildingId) : "",
      room_id: detectedRoomId ? String(detectedRoomId) : "",
      asset_id: ticket.asset_id ? String(ticket.asset_id) : "",
    }));
  };

  // Hanteer toevoeging van nuwe foutkaartjie of redigering van bestaande
  const handleAddTicket = async () => {
    try {
      if (!newTicket.title && !newTicket.description) {
        alert("Voer asseblief 'n titel of beskrywing vir die foutkaartjie in.");
        return;
      }

      const payload = {
        fault_description: newTicket.title
          ? `${newTicket.title}${newTicket.description ? `: ${newTicket.description}` : ''}`
          : newTicket.description,
        fault_type: newTicket.category && newTicket.category.trim() ? newTicket.category : null,
        fault_status: newTicket.status,
        fault_priority: newTicket.priority,
        room_id: newTicket.room_id ? Number(newTicket.room_id) : null,
        asset_id: newTicket.asset_id ? Number(newTicket.asset_id) : null,
        building_id: newTicket.building_id ? Number(newTicket.building_id) : null,
        location_id: newTicket.location_id ? Number(newTicket.location_id) : null,
      };

      if (isEditing) {
        await apiClient.tickets.update(editingId, payload);
        alert("Foutkaartjie suksesvol opgedateer!");
      } else {
        await apiClient.tickets.create(payload);
        alert("Foutkaartjie suksesvol geskep!");
      }
      handleCloseModal();
      fetchTickets();
    } catch (error) {
      console.error("Error saving ticket:", error);
      const errorDetail = error.response?.data?.detail;
      const errorMsg = Array.isArray(errorDetail) 
        ? errorDetail.map(e => `${e.loc?.join('.')}: ${e.msg}`).join('\n')
        : errorDetail || error.message;
      alert("Fout by besparing van foutkaartjie:\n" + errorMsg);
    }
  };

  // Laai foutkaartjie-data in vorm vir redigering
  const handleEditTicket = (ticket) => {
    setIsEditing(true);
    setEditingId(ticket.fault_id);
    applyTicketLocationSelection(ticket);
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewTicket({ title: "", description: "", category: "", status: "Oop", priority: "Medium", location_id: "", building_id: "", room_id: "", asset_id: "" });
  };

  const handleNewTicket = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewTicket({ title: "", description: "", category: "", status: "Oop", priority: "Medium", location_id: "", building_id: "", room_id: "", asset_id: "" });
    setShowModal(true);
  };

  const handleDeleteTicket = async (ticketId) => {
    if (!window.confirm("Is jy seker jy wil hierdie foutkaartjie verwyder?")) {
      return;
    }
    try {
      await apiClient.tickets.delete(ticketId);
      fetchTickets();
    } catch (error) {
      console.error("Error deleting ticket:", error);
      alert("Fout tydens verwydering van foutkaartjie.");
    }
  };

  const extractTitle = (faultDescription) => {
    if (!faultDescription) return "-";
    const parts = faultDescription.split(":");
    return parts[0].trim();
  };

  const translateStatus = (status) => {
    const translations = { Wag: "Hangende", Oop: "Oop", Bevestig: "Bevestig", Besig: "Besig", Opgelos: "Opgelos", Gesluit: "Gesluit" };
    return translations[status] || status || "-";
  };

  const translatePriority = (priority) => {
    const translations = { Laag: "Laag", Medium: "Medium", Hoog: "Hoog" };
    return translations[priority] || priority || "-";
  };

  const translateCategory = (category) => {
    const translations = { Instandhouding: "Onderhoud", Herstelwerk: "Herstel", Opgradering: "Upgrade" };
    return translations[category] || category || "-";
  };

  const filteredTickets = [...tickets]
    .filter((ticket) => {
      const query = searchTerm.trim().toLowerCase();
      const description = ticket.fault_description || "";
      if (!query) return true;
      const values = {
        id: ticket.fault_id,
        title: extractTitle(description),
        asset_id: ticket.asset_id,
        room_id: ticket.room_id,
        building_id: ticket.building_id,
        location_id: ticket.location_id,
        category: ticket.fault_type,
        priority: translatePriority(ticket.fault_priority),
        status: translateStatus(ticket.fault_status),
      };
      return filterColumn === 'all'
        ? Object.values(values).some((value) => String(value || '').toLowerCase().includes(query))
        : String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'id') return (Number(a.fault_id || 0) - Number(b.fault_id || 0)) * direction;
      if (sortBy === 'title') return String(extractTitle(a.fault_description)).localeCompare(String(extractTitle(b.fault_description)), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'status') return String(translateStatus(a.fault_status)).localeCompare(String(translateStatus(b.fault_status)), 'af', { sensitivity: 'base' }) * direction;
      return 0;
    });

  const getStatusClass = (status) => {
    switch (String(status).toLowerCase()) {
      case "Wag": return "status-wait";
      case "Oop": return "status-open";
      case "Bevestig": return "status-confirmed";
      case "Besig": return "status-in-progress";
      case "Opgelos": return "status-resolved";
      case "Gesluit": return "status-closed";
      default: return "status-default";
    }
  };

  // GENEREER DIE OPSIES EN VERGELYK NOU SUIWER AS STRINGE OM PARSING ERRORS TE VERMY
  useEffect(() => {
    if (showModal && isEditing && editingId && tickets.length > 0) {
      const currentTicket = tickets.find((ticket) => Number(ticket.fault_id) === Number(editingId));
      if (currentTicket) {
        applyTicketLocationSelection(currentTicket);
      }
    }
  }, [showModal, isEditing, editingId, tickets, assets, rooms, buildings, terrains]);

  const terrainOptions = (terrains || []).map((terrain) => ({
    value: String(terrain.location_id),
    label: terrain.location_name || terrain.location_desc || `Terrein ${terrain.location_id}`,
  }));

  const buildingOptions = (buildings || [])
    .filter((building) => !newTicket.site_id || String(building.location_id) === String(newTicket.site_id))
    .map((building) => ({
      value: String(building.building_id),
      label: building.building_name || `Gebou ${building.building_id}`,
    }));

  const roomOptions = (rooms || [])
    .filter((room) => !newTicket.building_id || String(room.building_id) === String(newTicket.building_id))
    .map((room) => ({
      value: String(room.room_id),
      label: room.room_name || room.room_number || room.room_desc || `Lokaal ${room.room_id}`,
    }));

  const assetOptions = (assets || [])
    .filter((asset) => !newTicket.room_id || String(asset.room_id) === String(newTicket.room_id))
    .map((asset) => ({
      value: String(asset.asset_id),
      label: `${asset.asset_id} - ${asset.asset_name || "Bate"}`,
    }));

  return (
    <div style={{ display: "flex" }}>
      <Sidebar currentPath="/fault-tickets" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Foutkaartjies Bestuur</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          <div className="controls">
            <div className="controls-left">
              <input
                type="text"
                placeholder="Soek..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <select value={filterColumn} onChange={(e) => setFilterColumn(e.target.value)}>
                <option value="all">Alle kolomme</option>
                <option value="id">ID</option>
                <option value="title">Titel</option>
                <option value="asset_id">Bate ID</option>
                <option value="room_id">Lokaal ID</option>
                <option value="building_id">Gebou ID</option>
                <option value="location_id">Terrein ID</option>
                <option value="category">Kategorie</option>
                <option value="priority">Prioriteit</option>
                <option value="status">Status</option>
              </select>
            </div>
            <div className="controls-right">
              <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
                <option value="default">Standaard</option>
                <option value="id">ID</option>
                <option value="title">Titel</option>
                <option value="status">Status</option>
              </select>
              <div style={{ display: 'flex', gap: '0.25rem' }}>
                <button type="button" className="btn-add" onClick={() => setSortDirection('asc')} style={{ minWidth: '40px', background: sortDirection === 'asc' ? '#935e28' : undefined }}>▲</button>
                <button type="button" className="btn-add" onClick={() => setSortDirection('desc')} style={{ minWidth: '40px', background: sortDirection === 'desc' ? '#935e28' : undefined }}>▼</button>
              </div>
              <button className="btn-add" onClick={handleNewTicket}>+ Nuwe Foutkaartjie</button>
            </div>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th>Kaartjie ID</th>
                <th>Titel</th>
                <th>Bate ID</th>
                <th>Lokaal ID</th>
                <th>Gebou ID</th>
                <th>Terrein ID</th>
                <th>Kategorie</th>
                <th>Prioriteit</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredTickets.map((ticket) => (
                <tr key={ticket.fault_id}>
                  <td>{ticket.fault_id}</td>
                  <td>{extractTitle(ticket.fault_description)}</td>
                  <td>{ticket.asset_id}</td>
                  <td>{ticket.room_id}</td>
                  <td>{ticket.building_id}</td>
                  <td>{ticket.location_id}</td>
                  <td>{translateCategory(ticket.fault_type)}</td>
                  <td>{translatePriority(ticket.fault_priority)}</td>
                  <td>
                    <span className={`status ${getStatusClass(ticket.fault_status)}`}>
                      {translateStatus(ticket.fault_status)}
                    </span>
                  </td>
                  <td>
                    <button className="btn-edit" onClick={() => handleEditTicket(ticket)}>Wysig</button>
                    <button className="btn-delete" onClick={() => handleDeleteTicket(ticket.fault_id)}>Verwyder</button>
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
              <h3>{isEditing ? "Wysig" : "Nuwe"} Foutkaartjie</h3>
              <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Titel</label>
                <input type="text" value={newTicket.title} onChange={(e) => setNewTicket({ ...newTicket, title: e.target.value })} />
              </div>
              <div className="input-group">
                <label>Kategorie</label>
                <select value={newTicket.category} onChange={(e) => setNewTicket({ ...newTicket, category: e.target.value })}>
                  <option value="">Kies kategorie</option>
                  <option value="Instandhouding">Onderhoud</option>
                  <option value="Herstelwerk">Herstel</option>
                  <option value="Opgradering">Opgradeer</option>
                </select>
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Prioriteit</label>
                <select value={newTicket.priority} onChange={(e) => setNewTicket({ ...newTicket, priority: e.target.value })}>
                  <option value="Laag">Laag</option>
                  <option value="Medium">Medium</option>
                  <option value="Hoog">Hoog</option>
                </select>
              </div>
            </div>
            
            <div className="input-row">
              <div className="input-group">
                <label>Terrein</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder="Kies terrein..."
                  isSearchable
                  options={terrainOptions}
                  value={terrainOptions.find((option) => String(option.value) === String(newTicket.site_id)) || null}
                  onChange={(selected) => setNewTicket({ ...newTicket, site_id: selected ? String(selected.value) : "", building_id: "", room_id: "", asset_id: "" })}
                />
              </div>
              <div className="input-group">
                <label>Gebou</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder={!newTicket.site_id ? "Kies eers terrein" : "Kies gebou..."}
                  isSearchable
                  isDisabled={!newTicket.site_id}
                  options={buildingOptions}
                  value={buildingOptions.find((option) => String(option.value) === String(newTicket.building_id)) || null}
                  onChange={(selected) => setNewTicket({ ...newTicket, building_id: selected ? String(selected.value) : "", room_id: "", asset_id: "" })}
                />
              </div>
            </div>

            <div className="input-row">
              <div className="input-group">
                <label>Lokaal</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder={!newTicket.building_id ? "Kies eers gebou" : "Kies lokaal..."}
                  isSearchable
                  isDisabled={!newTicket.building_id}
                  options={roomOptions}
                  value={roomOptions.find((option) => String(option.value) === String(newTicket.room_id)) || null}
                  onChange={(selected) => setNewTicket({ ...newTicket, room_id: selected ? String(selected.value) : "", asset_id: "" })}
                />
              </div>
              <div className="input-group">
                <label>Bate</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder={!newTicket.room_id ? "Kies eers lokaal" : "Kies bate..."}
                  isSearchable
                  isDisabled={!newTicket.room_id}
                  options={assetOptions}
                  value={assetOptions.find((option) => String(option.value) === String(newTicket.asset_id)) || null}
                  onChange={(selected) => setNewTicket({ ...newTicket, asset_id: selected ? String(selected.value) : "" })}
                />
              </div>
            </div>

            <div className="input-row">
              <div className="input-group">
                <label>Beskrywing</label>
                <textarea value={newTicket.description} onChange={(e) => setNewTicket({ ...newTicket, description: e.target.value })} />
              </div>
              <div className="input-group">
                <label>Status</label>
                <select value={newTicket.status} onChange={(e) => setNewTicket({ ...newTicket, status: e.target.value })}>
                  <option value="Wag">Wag</option>
                  <option value="Oop">Oop</option>
                  <option value="Bevestig">Bevestig</option>
                  <option value="Besig">Besig</option>
                  <option value="Opgelos">Opgelos</option>
                  <option value="Gesluit">Gesluit</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleAddTicket}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default TicketPage;