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
  const { isAdmin, user } = useCurrentUser();
  const logout = useLogout();
  const navigate = useNavigate();
  const MAX_TICKET_IMAGES = 3;
  
  // State vir foutkaartjies-lys
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");        // Soek op titel/beskrywing
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const [roomFilter, setRoomFilter] = useState("");
  
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
  const [ticketImages, setTicketImages] = useState([]);
  const [imagesToDelete, setImagesToDelete] = useState([]);
  const [activeImageViewer, setActiveImageViewer] = useState(null);
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
  });

  // Haal foutkaartjies wanneer blad laai
  useEffect(() => {
    Promise.all([fetchTickets(), fetchTerrains(), fetchBuildings(), fetchRooms(), fetchAssets()]);
  }, []);

  useEffect(() => {
    if (user?.role_id === 2 && user?.location_id) {
      setTerrainFilter(String(user.location_id));
    } else {
      setTerrainFilter("");
    }
  }, [user]);

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

  const fetchTicketImages = async (ticketId) => {
    if (!ticketId) {
      setTicketImages([]);
      return;
    }

    try {
      const response = await apiClient.image.getByParent("ticket", ticketId);
      setTicketImages(response.data || []);
    } catch (error) {
      console.error("Fout by laai van beeld-metadata:", error);
      setTicketImages([]);
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
    }));
  };

  const getTicketImageUrl = (imageId) => {
    if (!imageId) return null;
    return apiClient.image?.getFileUrl ? apiClient.image.getFileUrl(imageId) : null;
  };

  const handleImageFilesChange = (event) => {
    const files = Array.from(event.target.files || []);
    const remainingSlots = Math.max(0, MAX_TICKET_IMAGES - (selectedImageFiles.length + ticketImages.length));
    const incomingFiles = files.slice(0, remainingSlots);

    if (files.length > remainingSlots) {
      alert(`Jy kan maksimaal ${MAX_TICKET_IMAGES} beelde per foutkaartjie oplaai.`);
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

    setTicketImages((prev) => prev.filter((image) => image.image_id !== imageId));
    setImagesToDelete((prev) => (prev.includes(imageId) ? prev : [...prev, imageId]));
  };

  useEffect(() => {
    return () => {
      selectedImagePreviewUrls.forEach((url) => URL.revokeObjectURL(url));
    };
  }, []);

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
        asset_id: newTicket.asset_id ? Number(newTicket.asset_id) : null,
        building_id: newTicket.building_id ? Number(newTicket.building_id) : null,
        location_id: newTicket.location_id ? Number(newTicket.location_id) : null,
      };

      let ticketId = editingId;

      if (isEditing) {
        await apiClient.tickets.update(editingId, payload);
        alert("Foutkaartjie suksesvol opgedateer!");
      } else {
        const response = await apiClient.tickets.create(payload);
        ticketId = response?.data?.fault_id ?? response?.data?.id ?? null;
        alert("Foutkaartjie suksesvol geskep!");
      }

      if (isEditing) {
        for (const imageId of imagesToDelete) {
          await apiClient.image.delete(imageId);
        }
      }

      if (ticketId && selectedImageFiles.length > 0) {
        for (const file of selectedImageFiles.slice(0, MAX_TICKET_IMAGES)) {
          const imageFormData = new FormData();
          imageFormData.append('file', file);
          await apiClient.image.uploadForParent(ticketId, 'ticket', imageFormData);
        }
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
    setTicketImages([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewTicket({ title: "", description: "", category: "", status: "Oop", priority: "Medium", location_id: "", building_id: "", room_id: "", asset_id: "" });
  };

  const handleNewTicket = () => {
    setIsEditing(false);
    setEditingId(null);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setTicketImages([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
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
      if (terrainFilter && String(ticket.location_id) !== String(terrainFilter)) return false;
      if (buildingFilter && String(ticket.building_id) !== String(buildingFilter)) return false;
      if (roomFilter && String(ticket.room_id) !== String(roomFilter)) return false;
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
      fetchTicketImages(editingId);
    } else if (!showModal) {
      setTicketImages([]);
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
              {(() => {
                const cascadeCount = [terrainFilter, buildingFilter, roomFilter].filter(Boolean).length;
                const currentDisplayValue = cascadeCount === 0 ? null
                  : cascadeCount === 1 && terrainFilter ? { value: terrainFilter, label: terrains?.find(t => String(t.location_id) === terrainFilter)?.location_name || terrainFilter }
                  : cascadeCount === 2 && buildingFilter ? { value: buildingFilter, label: buildings?.find(b => String(b.building_id) === buildingFilter)?.building_name || buildingFilter }
                  : null;
                const clearFromLevel = (levelIndex) => {
                  if (levelIndex <= 0) { setTerrainFilter(''); setBuildingFilter(''); setRoomFilter(''); }
                  else if (levelIndex === 1) { setBuildingFilter(''); setRoomFilter(''); }
                  else if (levelIndex === 2) { setRoomFilter(''); }
                };
                const breadcrumbData = [{ level: -1, name: "Terreine" }];
                if (terrainFilter) breadcrumbData.push({ level: 0, name: terrains?.find(t => String(t.location_id) === terrainFilter)?.location_name || terrainFilter });
                if (buildingFilter) breadcrumbData.push({ level: 1, name: buildings?.find(b => String(b.building_id) === buildingFilter)?.building_name || buildingFilter });
                if (roomFilter) breadcrumbData.push({ level: 2, name: rooms?.find(r => String(r.room_id) === roomFilter)?.room_name || roomFilter });
                const renderBreadcrumb = () => (
                  <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: "4px", fontSize: "13px", color: "#111827", marginTop: "4px" }}>
                    {breadcrumbData.map((item, i) => {
                      const isLast = i === breadcrumbData.length - 1;
                      const showArrow = isLast ? cascadeCount < 3 : true;
                      return (
                        <React.Fragment key={i}>
                          <button type="button" onClick={() => clearFromLevel(item.level + 1)} style={{ background: "none", border: "none", cursor: "pointer", padding: "0", margin: "0", color: "#111827", fontWeight: isLast ? 700 : 600, fontSize: "13px", lineHeight: "1", display: "inline-flex", alignItems: "center" }}>{item.name}</button>
                          {showArrow && <span style={{ color: "#9ca3af", lineHeight: "1", display: "inline-flex", alignItems: "center" }}>›</span>}
                        </React.Fragment>
                      );
                    })}
                  </div>
                );
                const backBtnStyle = { background: "none", border: "none", color: "#111827", cursor: "pointer", display: "flex", alignItems: "center", padding: "0 4px" };
                const CascadeControl = ({ children, ...props }) => (
                  <components.Control {...props}>
                    {children}
                    {cascadeCount > 0 && (
                      <span className="cascade-back-indicator" onMouseDown={(e) => { e.stopPropagation(); e.preventDefault(); clearFromLevel(cascadeCount - 1); }} title="Vorige vlak" style={backBtnStyle}>
                        <IoReturnUpBack size={18} />
                      </span>
                    )}
                  </components.Control>
                );
                return (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                    {renderBreadcrumb()}
                    <Select
                      className="react-select-container"
                      classNamePrefix="react-select"
                      placeholder={["Kies Terrein...","Kies Gebou...","Kies Lokaal...","Filter voltooi"][cascadeCount]}
                      isClearable
                      isDisabled={cascadeCount >= 3}
                      components={{ Control: CascadeControl }}
                      styles={{ container: (base) => ({ ...base, minWidth: '260px' }) }}
                      options={(() => {
                        if (cascadeCount === 0) return (terrains || []).map(t => ({ value: String(t.location_id), label: `${t.location_id} - ${t.location_name || "Terrein"}` }));
                        if (cascadeCount === 1) return (buildings || []).filter(b => String(b.location_id) === terrainFilter).map(b => ({ value: String(b.building_id), label: `${b.building_id} - ${b.building_name || "Gebou"}` }));
                        if (cascadeCount === 2) return (rooms || []).filter(r => String(r.building_id) === buildingFilter).map(r => ({ value: String(r.room_id), label: `${r.room_id} - ${r.room_name || "Lokaal"}` }));
                        return [];
                      })()}
                      value={currentDisplayValue}
                      onChange={(selectedOption) => {
                        if (!selectedOption) return;
                        if (cascadeCount === 0) { setTerrainFilter(selectedOption.value); setBuildingFilter(''); setRoomFilter(''); }
                        else if (cascadeCount === 1) { setBuildingFilter(selectedOption.value); setRoomFilter(''); }
                        else if (cascadeCount === 2) { setRoomFilter(selectedOption.value); }
                      }}
                    />
                  </div>
                );
              })()}
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

      {activeImageViewer && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', zIndex: 1100, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '2rem' }}>
          <div style={{ background: '#fff', borderRadius: '8px', maxWidth: 'min(90vw, 1200px)', maxHeight: '90vh', padding: '2rem', position: 'relative', boxShadow: '0 12px 30px rgba(0,0,0,0.25)' }}>
            <span className="close" onClick={() => setActiveImageViewer(null)} style={{ position: 'absolute', top: '0.75rem', right: '0.75rem', cursor: 'pointer' }}>&times;</span>
            <img src={activeImageViewer.src} alt="Vergrote beeld" style={{ width: '100%', maxHeight: '75vh', objectFit: 'contain', display: 'block', marginTop: '2rem' }} />
            <div style={{ marginTop: '0.75rem', display: 'flex', justifyContent: 'center', gap: '0.5rem' }}>
              {activeImageViewer.type === 'preview' ? (
                <button type="button" className="btn-delete" onClick={() => {
                  handleRemoveSelectedPreview(activeImageViewer.index);
                  setActiveImageViewer(null);
                }}>Verwyder</button>
              ) : (
                <button type="button" className="btn-delete" onClick={() => {
                  handleDeleteExistingImage(activeImageViewer.imageId);
                  setActiveImageViewer(null);
                }}>Verwyder</button>
              )}
            </div>
          </div>
        </div>
      )}

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
                <label>Beelde (Maksimum {MAX_TICKET_IMAGES})</label>
                <input type="file" accept="image/*" multiple onChange={handleImageFilesChange} />

                {selectedImagePreviewUrls.length > 0 && (
                  <div style={{ marginTop: '0.75rem' }}>
                    <p style={{ margin: '0 0 0.35rem', fontSize: '0.9rem', fontWeight: 600 }}>Nuwe seleksies</p>
                    <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                      {selectedImagePreviewUrls.map((url, index) => (
                        <div key={`${url}-${index}`} className="record-image-card" style={{ textAlign: 'center' }}>
                          <img
                            src={url}
                            alt={`Voorbeeld ${index + 1}`}
                            className="ticket-image-thumb"
                            onClick={() => setActiveImageViewer({ type: 'preview', src: url, index })}
                            style={{ width: '100px', height: '100px', objectFit: 'cover', borderRadius: '4px', cursor: 'zoom-in' }}
                          />
                          <div style={{ marginTop: '0.25rem' }}>
                            <button type="button" className="btn-delete" onClick={() => handleRemoveSelectedPreview(index)} style={{ marginLeft: '0.25rem' }}>Verwyder</button>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {ticketImages.length > 0 && (
                  <div style={{ marginTop: '0.75rem' }}>
                    <p style={{ margin: '0 0 0.35rem', fontSize: '0.9rem', fontWeight: 600 }}>Bestaande beelde</p>
                    <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                      {ticketImages.map((image, index) => (
                        <div key={image.image_id ?? index} className="record-image-card" style={{ textAlign: 'center' }}>
                          <img
                            src={getTicketImageUrl(image.image_id)}
                            alt={`Huidige beeld ${index + 1}`}
                            className="ticket-image-thumb"
                            onClick={() => setActiveImageViewer({ type: 'existing', src: getTicketImageUrl(image.image_id), imageId: image.image_id, index })}
                            style={{ width: '100px', height: '100px', objectFit: 'cover', borderRadius: '4px', cursor: 'zoom-in' }}
                          />
                          <div style={{ marginTop: '0.25rem' }}>
                            <button type="button" className="btn-delete" onClick={() => handleDeleteExistingImage(image.image_id)} style={{ marginLeft: '0.25rem' }}>Verwyder</button>
                          </div>
                        </div>
                      ))}
                    </div>
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