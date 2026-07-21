import React, { useState, useEffect, useRef } from "react";
import { Link, useNavigate } from "react-router-dom";
import Select, { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";
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
  const navigate = useNavigate();
  
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
  const [selectedImageFiles, setSelectedImageFiles] = useState([]);
  const [selectedImagePreviewUrls, setSelectedImagePreviewUrls] = useState([]);
  const [cascadeToast, setCascadeToast] = useState(null);
  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});
  
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
    image_id: "",
    image_id_2: "",
    image_id_3: "",
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
    let detectedBuildingId = ticket.building_id || "";
    let detectedSiteId = ticket.location_id || "";

    if (!detectedRoomId && ticket.asset_id) {
      const associatedAsset = assets.find((asset) => Number(asset.asset_id) === Number(ticket.asset_id));
      if (associatedAsset) {
        detectedRoomId = associatedAsset.room_id;
      }
    }

    if (detectedRoomId && !detectedBuildingId) {
      const associatedRoom = rooms.find((room) => Number(room.room_id) === Number(detectedRoomId));
      if (associatedRoom) {
        detectedBuildingId = associatedRoom.building_id;

        }
    }

    if (detectedBuildingId && !detectedSiteId) {
      const associatedBuilding = buildings.find((building) => Number(building.building_id) === Number(detectedBuildingId));
      if (associatedBuilding) {
        detectedSiteId = associatedBuilding.location_id;
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
      image_id: ticket.image_id ? String(ticket.image_id) : "",
      image_id_2: ticket.image_id_2 ? String(ticket.image_id_2) : "",
      image_id_3: ticket.image_id_3 ? String(ticket.image_id_3) : "",
    }));
  };

  const getTicketImageUrl = (imageId) => {
    if (!imageId) return null;
    return apiClient.image?.getFileUrl ? apiClient.image.getFileUrl(imageId) : null;
  };

  const handleImageFilesChange = (event) => {
    const files = Array.from(event.target.files || []).slice(0, 3);
    setSelectedImageFiles(files);
    const previewUrls = files.map((file) => URL.createObjectURL(file));
    setSelectedImagePreviewUrls(previewUrls);
  };

  useEffect(() => {
    return () => {
      selectedImagePreviewUrls.forEach((url) => URL.revokeObjectURL(url));
    };
  }, [selectedImagePreviewUrls]);

  // Hanteer toevoeging van nuwe foutkaartjie of redigering van bestaande
  const handleAddTicket = async () => {
    try {
      const errors = {};
      if (!newTicket.title?.trim()) errors.title = true;
      if (!newTicket.category) errors.category = true;
      if (!newTicket.location_id) errors.location_id = true;
      if (!newTicket.description?.trim()) errors.description = true;
      if (Object.keys(errors).length > 0) {
        setInvalidFields(errors);
        const firstKey = Object.keys(errors)[0];
        fieldRefs.current[firstKey]?.scrollIntoView({ behavior: "smooth", block: "center" });
        fieldRefs.current[firstKey]?.focus();
        return;
      }
      setInvalidFields({});

      const payload = {
        fault_description: newTicket.title
          ? `${newTicket.title}${newTicket.description ? `: ${newTicket.description}` : ''}`
          : newTicket.description,
        fault_type: newTicket.category && newTicket.category.trim() ? newTicket.category : null,
        fault_status: newTicket.status,
        fault_priority: newTicket.priority,
        room_id: newTicket.room_id ? Number(newTicket.room_id) : null,
        asset_id: newTicket.asset_id ? Number(newTicket.asset_id) : null,building_id: newTicket.building_id ? Number(newTicket.building_id) : null,
        location_id: newTicket.location_id ? Number(newTicket.location_id) : null,
      };

      if (newTicket.image_id) {
        payload.image_id = Number(newTicket.image_id);
      }
      if (newTicket.image_id_2) {
        payload.image_id_2 = Number(newTicket.image_id_2);
      }
      if (newTicket.image_id_3) {
        payload.image_id_3 = Number(newTicket.image_id_3);
      }

      if (selectedImageFiles.length > 0) {
        const uploadedIds = [];
        for (const file of selectedImageFiles.slice(0, 3)) {
          const imageFormData = new FormData();
          imageFormData.append('file', file);
          const imageResponse = await apiClient.image.upload(imageFormData);
          if (imageResponse?.data?.image_id) {
            uploadedIds.push(imageResponse.data.image_id);
          }
        }
        if (uploadedIds.length > 0) {
          payload.image_id = uploadedIds[0] || payload.image_id;
          payload.image_id_2 = uploadedIds[1] || payload.image_id_2;
          payload.image_id_3 = uploadedIds[2] || payload.image_id_3;
        }
      }

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
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setNewTicket({ title: "", description: "", category: "", status: "Oop", priority: "Medium", location_id: "", building_id: "", room_id: "", asset_id: "", image_id: "", image_id_2: "", image_id_3: "" });
  };

  const handleNewTicket = () => {
    setIsEditing(false);
    setEditingId(null);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setNewTicket({ title: "", description: "", category: "", status: "Oop", priority: "Medium", location_id: "", building_id: "", room_id: "", asset_id: "", image_id: "", image_id_2: "", image_id_3: "" });
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

  const handleCreateWorkOrder = (ticket) => {
    navigate('/work-orders', { state: { ticket } });
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
      case "wag": return "status-wait";
      case "oop": return "status-open";
      case "bevestig": return "status-confirmed";
      case "besig": return "status-in-progress";
      case "opgelos": return "status-resolved";
      case "gesluit": return "status-closed";
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
                <option value="title">Titel</option><option value="asset_id">Bate ID</option>
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
                <th>ID</th>
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
                <tr key={ticket.fault_id} onClick={() => handleEditTicket(ticket)} style={{ cursor: "pointer" }}>
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
                  <td onClick={e => e.stopPropagation()}>
                    <button className="btn-add" onClick={() => handleCreateWorkOrder(ticket)} style={{ marginRight: '0.25rem' }}>Skep Werkopdrag</button>
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
                <label>Titel *</label>
                <input type="text" value={newTicket.title} ref={el => fieldRefs.current.title = el} className={invalidFields.title ? "field-invalid" : ""} onChange={(e) => { setNewTicket({ ...newTicket, title: e.target.value }); setInvalidFields(prev => { const next = {...prev}; delete next.title; return next; }); }} />
              </div>
              <div className="input-group">
                <label>Kategorie *</label>
                <select value={newTicket.category} ref={el => fieldRefs.current.category = el} className={invalidFields.category ? "field-invalid" : ""} onChange={(e) => { setNewTicket({ ...newTicket, category: e.target.value }); setInvalidFields(prev => { const next = {...prev}; delete next.category; return next; }); }}>
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
              <div className={invalidFields.location_id ? "input-group field-invalid" : "input-group"} style={{ position: "relative", flex: 1 }}>
                <label>Ligging *</label>
                {(() => {
                  const cascadeCount = [newTicket.location_id, newTicket.building_id, newTicket.room_id, newTicket.asset_id].filter(Boolean).length;
                  const clearFromLevel = (levelIndex) => {
                    if (levelIndex <= 0) setNewTicket(p => ({...p, location_id: "", building_id: "", room_id: "", asset_id: ""}));
                    else if (levelIndex === 1) setNewTicket(p => ({...p, building_id: "", room_id: "", asset_id: ""}));
                    else if (levelIndex === 2) setNewTicket(p => ({...p, room_id: "", asset_id: ""}));
                    else if (levelIndex === 3) setNewTicket(p => ({...p, asset_id: ""}));
                  };
                  const breadcrumbData = [{ level: -1, name: "Terreine" }];
                  if (newTicket.location_id) breadcrumbData.push({ level: 0, name: terrains?.find(t => String(t.location_id) === String(newTicket.location_id))?.location_name || newTicket.location_id });
                  if (newTicket.building_id) breadcrumbData.push({ level: 1, name: buildings?.find(b => String(b.building_id) === String(newTicket.building_id))?.building_name || newTicket.building_id });
                  if (newTicket.room_id) breadcrumbData.push({ level: 2, name: rooms?.find(r => String(r.room_id) === String(newTicket.room_id))?.room_name || newTicket.room_id });
                  if (newTicket.asset_id) breadcrumbData.push({ level: 3, name: assets?.find(a => String(a.asset_id) === String(newTicket.asset_id))?.asset_name || newTicket.asset_id });
                  const renderBreadcrumb = () => (
                    <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: "4px", fontSize: "13px", color: "#111827", marginTop: "6px", marginBottom: "6px" }}>
                      {breadcrumbData.map((item, i) => {
                        const isLast = i === breadcrumbData.length - 1;
                        const showArrow = isLast ? cascadeCount < 4 : true;
                        return (
                          <React.Fragment key={i}>
                            <button
                              type="button"
                              className="breadcrumb-btn"
                              onClick={() => clearFromLevel(item.level + 1)}
                              style={{
                                border: "none", cursor: "pointer", margin: "0",
                                color: "#111827", fontWeight: isLast ? 700 : 600, fontSize: "13px",
                                lineHeight: "1", display: "inline-flex", alignItems: "center",
                              }}
                            >{item.name}</button>
                            {showArrow && <span style={{ color: "#9ca3af", lineHeight: "1", display: "inline-flex", alignItems: "center" }}>›</span>}
                          </React.Fragment>
                        );
                      })}
                    </div>
                  );
                  const backBtnStyle = {
                    background: "#935e28", border: "none", borderRadius: "4px",
                    color: "#fff", cursor: "pointer", display: "flex",
                    alignItems: "center", padding: "4px 8px", margin: "2px",
                  };
                  const CascadeControl = ({ children, ...props }) => (
                    <components.Control {...props}>
                      {children}
                      {cascadeCount > 0 && (
                        <span
                          className="cascade-back-indicator"
                          onMouseDown={(e) => { e.stopPropagation(); e.preventDefault(); clearFromLevel(cascadeCount - 1); }}
                          title="Terug na vorige vlak"
                          style={backBtnStyle}
                        >
                          <IoReturnUpBack size={24} />
                        </span>
                      )}
                    </components.Control>
                  );
                  return (
                    <>
                      {renderBreadcrumb()}
                      <Select
                        className="react-select-container"
                        classNamePrefix="react-select"
                        placeholder={
                          ["Kies Terrein...","Kies Gebou...","Kies Lokaal...","Kies Bate...","Ligging voltooi"][cascadeCount]
                        }
                        isClearable
                        isDisabled={cascadeCount >= 4}
                        closeMenuOnSelect={false}
                        components={{ Control: CascadeControl }}
                        options={(() => {
                          if (cascadeCount === 0)
                            return (terrains || []).map((t) => ({ value: String(t.location_id), label: `${t.location_id} - ${t.location_name || t.location_desc || "Terrein"}` }));
                          if (cascadeCount === 1)
                            return (buildings || []).filter((b) => String(b.location_id) === String(newTicket.location_id)).map((b) => ({ value: String(b.building_id), label: `${b.building_id} - ${b.building_name || "Gebou"}` }));
                          if (cascadeCount === 2)
                            return (rooms || []).filter((r) => String(r.building_id) === String(newTicket.building_id)).map((r) => ({ value: String(r.room_id), label: `${r.room_id} - ${r.room_name || r.room_number || "Lokaal"}` }));
                          if (cascadeCount === 3)
                            return (assets || []).filter((a) => String(a.room_id) === String(newTicket.room_id)).map((a) => ({ value: String(a.asset_id), label: `${a.asset_id} - ${a.asset_name}` }));
                          return [];
                        })()}
                        value={null}
                        onChange={(selectedOption) => {
                          if (!selectedOption) return;
                          const labels = ["Terrein","Gebou","Lokaal","Bate"];
                          if (cascadeCount === 0)
                            setNewTicket(p => ({...p, location_id: selectedOption.value, building_id: "", room_id: "", asset_id: ""}));
                          else if (cascadeCount === 1)
                            setNewTicket(p => ({...p, building_id: selectedOption.value, room_id: "", asset_id: ""}));
                          else if (cascadeCount === 2)
                            setNewTicket(p => ({...p, room_id: selectedOption.value, asset_id: ""}));
                          else if (cascadeCount === 3)
                            setNewTicket(p => ({...p, asset_id: selectedOption.value}));
                          setInvalidFields(prev => { const next = {...prev}; delete next.location_id; return next; });
                          const label = labels[cascadeCount] || "";
                          setCascadeToast(`✓ ${label} suksesvol geselekteer`);
                          setTimeout(() => setCascadeToast(null), 2000);
                        }}
                      />
                    </>
                  );
                })()}
                {cascadeToast && (
                  <div style={{
                    position: "absolute",
                    top: "50%",
                    left: "50%",
                    transform: "translate(-50%, -50%)",
                    background: "#16a34a",
                    color: "#fff",
                    padding: "10px 24px",
                    borderRadius: "10px",
                    fontSize: "14px",
                    fontWeight: "600",
                    boxShadow: "0 4px 14px rgba(0,0,0,0.25)",
                    zIndex: 10,
                    textAlign: "center",
                    pointerEvents: "none",
                    whiteSpace: "nowrap",
                  }}>
                    {cascadeToast}
                  </div>
                )}
              </div>
            </div>

            <div className="input-row">
              <div className="input-group">
                <label>Beelde (maksimum 3)</label>
                <input type="file" accept="image/*" multiple onChange={handleImageFilesChange} />
                {selectedImagePreviewUrls.length > 0 && (
                  <div style={{ marginTop: '0.5rem', display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                    {selectedImagePreviewUrls.map((url, index) => (
                      <img key={index} src={url} alt={`Voorbeeld ${index + 1}`} style={{ width: '100px', height: '100px', objectFit: 'cover', borderRadius: '4px' }} />
                    ))}
                  </div>
                )}
                {selectedImagePreviewUrls.length === 0 && (
                  <div style={{ marginTop: '0.5rem', display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                    {[newTicket.image_id, newTicket.image_id_2, newTicket.image_id_3].filter(Boolean).map((id, index) => (
                      <div key={index} style={{ textAlign: 'center' }}>
                        <p style={{ margin: 0, fontSize: '0.9rem' }}>Huidige beeld {index + 1}</p>
                        <img src={getTicketImageUrl(id)} alt={`Huidige beeld ${index + 1}`} style={{ width: '100px', height: '100px', objectFit: 'cover', borderRadius: '4px' }} />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Beskrywing *</label>
                <textarea value={newTicket.description} ref={el => fieldRefs.current.description = el} className={invalidFields.description ? "field-invalid" : ""} onChange={(e) => { setNewTicket({ ...newTicket, description: e.target.value }); setInvalidFields(prev => { const next = {...prev}; delete next.description; return next; }); }} />
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