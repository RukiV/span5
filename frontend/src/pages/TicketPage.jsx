import React, { useState, useEffect, useRef, useMemo } from "react";
import { Link, useNavigate } from "react-router-dom";
import Select from "react-select";
import { IoTrashOutline } from "react-icons/io5";
import { renderBreadcrumb, CascadeControl, CascadeIndicatorsContainer, NoCascadeClearIndicator } from "../components/controlHelpers";
import { apiClient } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import { useToast } from '../components/Toast/useToast';
import useColumnSort from "../hooks/useColumnSort";
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import '../styles/App.css';
import "../styles/Ticket.css";
import { buildFlatLocationOptions } from './locationSearchUtils';
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import ResizableTh from "../components/ResizableTh";
import useAiSuggestions from "../hooks/useAiSuggestions";
import AiSuggestPanel from "../components/AiSuggestPanel";
import ImportExportModal from "../components/DataTransfer/ImportExportModal";
import useCascadeMenu from "../hooks/useCascadeMenu";
import { getDeleteErrorMessage, confirmCascade, batchDelete } from "../utils/deleteUtils";


function TicketPage() {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { user, hasRight } = useCurrentUser();
  const navigate = useNavigate();
  const MAX_TICKET_IMAGES = 3;
  const [showImportWizard, setShowImportWizard] = useState(false);
  
  // State vir foutkaartjies-lys
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");        // Soek op titel/beskrywing
  const [filterColumn, setFilterColumn] = useState("all");
  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: null });
  const TICKET_COLUMNS = [
    { key: 'id', label: 'ID', render: (t) => t.fault_id, sortKey: 'id', defaultVisible: true },
    { key: 'title', label: 'Titel', render: (t) => extractTitle(t.fault_description), sortKey: 'title', defaultVisible: true },
    { key: 'category', label: 'Kategorie', render: (t) => t.fault_type || '-', sortKey: 'category', defaultVisible: true },
    { key: 'priority', label: 'Prioriteit', render: (t) => t.fault_priority || '-', sortKey: 'priority', defaultVisible: true },
    { key: 'status', label: 'Status', render: (t) => translateStatus(t.fault_status), sortKey: 'status', defaultVisible: true },
    { key: 'asset_id', label: 'Bate ID', render: (t) => t.asset_id || '-', sortKey: 'asset_id', defaultVisible: false },
    { key: 'room_id', label: 'Lokaal ID', render: (t) => t.room_id || '-', sortKey: 'room_id', defaultVisible: false },
    { key: 'building_id', label: 'Gebou ID', render: (t) => t.building_id || '-', sortKey: 'building_id', defaultVisible: false },
    { key: 'location_id', label: 'Terrein ID', render: (t) => t.location_id || '-', sortKey: 'location_id', defaultVisible: false },
    { key: 'reported', label: 'Datum', render: (t) => t.fault_reportdatetime ? new Date(t.fault_reportdatetime).toLocaleDateString('af-ZA') : '-', sortKey: 'reported', defaultVisible: false },
    { key: 'updated', label: 'Opgedateer', render: (t) => t.fault_updatedatetime ? new Date(t.fault_updatedatetime).toLocaleDateString('af-ZA') : '-', sortKey: 'updated', defaultVisible: false },
  ];
  const colVis = useColumnVisibility('ticket-page', TICKET_COLUMNS);
  const colWidths = useColumnWidths('ticket-page', TICKET_COLUMNS);
  const colPickerRef = useRef(null);
  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const [roomFilter, setRoomFilter] = useState("");
  const filterCascade = useCascadeMenu();
  const modalCascadeMenu = useCascadeMenu();
  
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
  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, rooms, assets), [terrains, buildings, rooms, assets]);
  
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

  // AI-veldvoorstelle: kategorie/prioriteit uit titel+beskrywing (reëls).
  // Die vorm se vertoonwaardes is Afrikaans — map die enjin se EN-enum hier.
  const FAULT_TYPE_EN_AF = { REPAIR: 'Herstel', MAINTENANCE: 'Onderhoud', INSPECTION: 'Inspeksie', INSTALLATION: 'Installasie' };
  const FAULT_PRIO_EN_AF = { LOW: 'Laag', MEDIUM: 'Medium', HIGH: 'Hoog' };
  const aiSuggestions = useAiSuggestions({
    context: 'fault',
    values: {
      title: newTicket.title,
      description: newTicket.description,
      fault_type: newTicket.category,
      fault_priority: newTicket.priority,
    },
  });
  const { suggestions: faultSuggestions, loading: aiLoading, filled: aiFilled, error: aiError } = aiSuggestions;

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
      showToast({ type: 'error', title: 'Fout', message: "Fout by laai van foutkaartjies: " + (error.response?.data?.detail || error.message) });
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
      showToast({ type: 'warning', title: 'Waarskuwing', message: `Jy kan maksimaal ${MAX_TICKET_IMAGES} beelde per foutkaartjie oplaai.` });
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

  const handleRemoveSelectedPreview = async (index) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie beeld verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;

    setSelectedImageFiles((prev) => prev.filter((_, itemIndex) => itemIndex !== index));
    setSelectedImagePreviewUrls((prev) => {
      const urlToRevoke = prev[index];
      if (urlToRevoke) {
        URL.revokeObjectURL(urlToRevoke);
      }
      return prev.filter((_, itemIndex) => itemIndex !== index);
    });
  };

  const handleDeleteExistingImage = async (imageId) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie beeld verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;

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
        showToast({ type: 'success', title: 'Sukses', message: "Foutkaartjie suksesvol opgedateer!" });
      } else {
        const response = await apiClient.tickets.create(payload);
        ticketId = response?.data?.fault_id ?? response?.data?.id ?? null;
        showToast({ type: 'success', title: 'Sukses', message: "Foutkaartjie suksesvol geskep!" });
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
      showToast({ type: 'error', title: 'Fout', message: "Fout by besparing van foutkaartjie:\n" + errorMsg });
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
    const confirmed = await confirmCascade(confirm, { entityLabel: "foutkaartjie", childrenLabel: "werkopdragte" });
    if (!confirmed) return;
    try {
      await apiClient.tickets.delete(ticketId);
      fetchTickets();
    } catch (error) {
      console.error("Error deleting ticket:", error);
      showToast({ type: 'error', title: 'Fout', message: getDeleteErrorMessage(error, "Fout tydens verwydering van foutkaartjie.") });
    }
  };

  const [selectedIds, setSelectedIds] = useState([]);
  const toggleAll = () => {
    setSelectedIds(allSelected ? [] : filteredTickets.map((x) => x.fault_id));
  };
  const toggleOne = (id) => {
    setSelectedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };
  const handleDeleteSelected = () => {
    batchDelete({
      ids: selectedIds,
      apiDelete: apiClient.tickets.delete,
      confirm,
      showToast,
      entityLabel: "foutkaartjies",
      childrenLabel: "werkopdragte",
      refresh: fetchTickets,
      errorFallback: "Fout tydens verwydering van foutkaartjie.",
    }).then(() => setSelectedIds([]));
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
      if (!sortKey) return 0;
      const dir = sortDirection === 'asc' ? 1 : -1;
      if (sortKey === 'id') return (Number(a.fault_id || 0) - Number(b.fault_id || 0)) * dir;
      if (sortKey === 'title') return String(extractTitle(a.fault_description)).localeCompare(String(extractTitle(b.fault_description)), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'status') return String(translateStatus(a.fault_status)).localeCompare(String(translateStatus(b.fault_status)), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'priority') return String(a.fault_priority || '').localeCompare(String(b.fault_priority || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'category') return String(a.fault_type || '').localeCompare(String(b.fault_type || ''), 'af', { sensitivity: 'base' }) * dir;
      return 0;
    });
  const allSelected = filteredTickets.length > 0 && selectedIds.length === filteredTickets.length;

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
    <div className="main">
      <div className="content">
          <div className="controls">
            <div className="controls-left">
              <div className="control-input-shell">
                <input
                  type="text"
                  placeholder="Soek..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <Select
                className="react-select-container"
                classNamePrefix="react-select"
                value={[
                  { value: "all", label: "Alle kolomme" }, { value: "id", label: "ID" },
                  { value: "title", label: "Titel" }, { value: "asset_id", label: "Bate ID" },
                  { value: "room_id", label: "Lokaal ID" }, { value: "building_id", label: "Gebou ID" },
                  { value: "location_id", label: "Terrein ID" }, { value: "category", label: "Kategorie" },
                  { value: "priority", label: "Prioriteit" }, { value: "status", label: "Status" },
                ].find((option) => option.value === filterColumn)}
                onChange={(selected) => setFilterColumn(selected?.value || "all")}
                options={[
                  { value: "all", label: "Alle kolomme" }, { value: "id", label: "ID" },
                  { value: "title", label: "Titel" }, { value: "asset_id", label: "Bate ID" },
                  { value: "room_id", label: "Lokaal ID" }, { value: "building_id", label: "Gebou ID" },
                  { value: "location_id", label: "Terrein ID" }, { value: "category", label: "Kategorie" },
                  { value: "priority", label: "Prioriteit" }, { value: "status", label: "Status" },
                ]}
                isSearchable={false}
              />
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
                 return (
                   <div className="control-cascade-stack" ref={filterCascade.containerRef}>
                     <div className="control-cascade-breadcrumb">
                       {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 3 })}
                     </div>
                     <Select
                      className="react-select-container"
                      classNamePrefix="react-select"
                       placeholder={["Kies Terrein...","Kies Gebou...","Kies Lokaal...","Filter voltooi"][cascadeCount]}
                       isClearable
                       isDisabled={cascadeCount >= 3}
                       closeMenuOnSelect={false}
                       menuIsOpen={filterCascade.menuIsOpen}
                       onMenuOpen={filterCascade.onMenuOpen}
                       onMenuClose={filterCascade.onMenuClose}
                       components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} />, IndicatorsContainer: CascadeIndicatorsContainer, ClearIndicator: NoCascadeClearIndicator }}
                      styles={{
                        container: (base) => ({ ...base, minWidth: '260px' }),
                        control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                        valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                        singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                      }}
                      options={allLocationOptions}
                      filterOption={(option, rawInput) => {
                        if (rawInput) {
                          if (cascadeCount === 0)
                            return option.data._cascadeLevel <= 3 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 1)
                            return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 3 && String(option.data._fields.location_id) === String(terrainFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 2)
                            return option.data._cascadeLevel >= 2 && option.data._cascadeLevel <= 3 && String(option.data._fields.building_id) === String(buildingFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 3)
                            return option.data._cascadeLevel >= 3 && option.data._cascadeLevel <= 3 && String(option.data._fields.room_id) === String(roomFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        }
                        if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                        if (cascadeCount === 1) return option.data._cascadeLevel === 1 && String(option.data._parentId) === String(terrainFilter);
                        if (cascadeCount === 2) return option.data._cascadeLevel === 2 && String(option.data._parentId) === String(buildingFilter);
                        return false;
                      }}
                      value={currentDisplayValue}
                      onChange={(selectedOption) => {
                        if (!selectedOption) { setTerrainFilter(''); setBuildingFilter(''); setRoomFilter(''); return; }
                        const f = selectedOption._fields;
                        setTerrainFilter(f.location_id); setBuildingFilter(f.building_id); setRoomFilter(f.room_id);
                      }}
                    />
                  </div>
                );
              })()}
            </div>
            <div className="controls-right">
              {hasRight('faults.manage') && (
                <button
                  type="button"
                  className="btn-add"
                  style={{ marginLeft: '0.5rem' }}
                  onClick={() => setShowImportWizard(true)}
                >
                  ⇅ Invoer / Uitvoer rekords
                </button>
              )}
              <ColumnPicker
                ref={colPickerRef}
                columns={TICKET_COLUMNS}
                visibleColumns={colVis.visibleColumns}
                toggleColumn={colVis.toggleColumn}
                resetVisibility={colVis.resetVisibility}
                onResetWidths={colWidths.resetWidths}
              />
              <button className="btn-add" onClick={handleNewTicket}>+ Nuwe Foutkaartjie</button>
              {selectedIds.length > 0 && (
                <button className="btn-delete" style={{ marginLeft: '0.5rem' }} onClick={handleDeleteSelected}>
                  Verwyder Geselekteerde ({selectedIds.length})
                </button>
              )}
              {hasRight('faults.manage') && (
                <ImportExportModal
                  isOpen={showImportWizard}
                  onClose={() => setShowImportWizard(false)}
                  defaultEntity="fault"
                  onImported={fetchTickets}
                />
              )}
            </div>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th style={{ width: '36px', textAlign: 'center' }}>
                  <input type="checkbox" checked={allSelected} onChange={toggleAll} title="Kies alles" onClick={(e) => e.stopPropagation()} />
                </th>
                {colVis.visibleColumns.map((col) => (
                  <ResizableTh
                    key={col.key}
                    col={col}
                    colWidths={colWidths}
                    className={col.sortKey ? getSortClass(col.sortKey) : ''}
                    onClick={() => col.sortKey && handleSort(col.sortKey)}
                    onContextMenu={(e) => colPickerRef.current?.openAt(e)}
                  >
                    {col.label}{col.sortKey && getSortIndicator(col.sortKey)}
                  </ResizableTh>
                ))}
                <th style={{ width: '250px' }}>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredTickets.length === 0 ? (
                <tr><td colSpan={colVis.visibleColumns.length + 2} style={{ textAlign: 'center', padding: '20px' }}>Geen foutkaartjies gevind</td></tr>
              ) : (
                filteredTickets.map((ticket) => (
                  <tr key={ticket.fault_id} onClick={() => handleEditTicket(ticket)} style={{ cursor: "pointer" }}>
                    <td style={{ textAlign: 'center' }} onClick={e => e.stopPropagation()}>
                      <input type="checkbox" checked={selectedIds.includes(ticket.fault_id)} onChange={() => toggleOne(ticket.fault_id)} />
                    </td>
                    {colVis.visibleColumns.map((col) => (
                      <td key={col.key}>{col.render(ticket)}</td>
                    ))}
                    <td onClick={e => e.stopPropagation()}>
                      <button className="btn-add" onClick={() => handleCreateWorkOrder(ticket)} style={{ marginRight: '0.25rem' }}>Skep Werkopdrag</button>
                      <button className="btn-delete" title="Verwyder" onClick={() => handleDeleteTicket(ticket.fault_id)}><IoTrashOutline size={18} /></button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
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
                  <option value="Onderhoud">Onderhoud</option>
                  <option value="Herstel">Herstel</option>
                  <option value="Inspeksie">Inspeksie</option>
                  <option value="Installasie">Installasie</option>
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
                  const currentDisplayValue = cascadeCount === 0 ? null
                    : cascadeCount === 1 && newTicket.location_id ? { value: newTicket.location_id, label: terrains?.find(t => String(t.location_id) === String(newTicket.location_id))?.location_name || newTicket.location_id }
                    : cascadeCount === 2 && newTicket.building_id ? { value: newTicket.building_id, label: buildings?.find(b => String(b.building_id) === String(newTicket.building_id))?.building_name || newTicket.building_id }
                    : cascadeCount === 3 && newTicket.room_id ? { value: newTicket.room_id, label: rooms?.find(r => String(r.room_id) === String(newTicket.room_id))?.room_name || newTicket.room_id }
                    : cascadeCount === 4 && newTicket.asset_id ? { value: newTicket.asset_id, label: assets?.find(a => String(a.asset_id) === String(newTicket.asset_id))?.asset_name || newTicket.asset_id }
                    : null;
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
                   return (
                     <div ref={modalCascadeMenu.containerRef}>
                       {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 4, marginTop: "6px", marginBottom: "6px" })}
                      <Select
                        className="react-select-container"
                        classNamePrefix="react-select"
                        placeholder={
                          ["Kies Terrein...","Kies Gebou...","Kies Lokaal...","Kies Bate...","Ligging voltooi"][cascadeCount]
                        }
                        isClearable
                        isDisabled={cascadeCount >= 4}
                        closeMenuOnSelect={false}
                        menuIsOpen={modalCascadeMenu.menuIsOpen}
                        onMenuOpen={modalCascadeMenu.onMenuOpen}
                        onMenuClose={modalCascadeMenu.onMenuClose}
                        components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} />, IndicatorsContainer: CascadeIndicatorsContainer, ClearIndicator: NoCascadeClearIndicator }}
                        options={allLocationOptions}
                        styles={{
                          container: (base) => ({ ...base, minWidth: '260px' }),
                          control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                          valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                          singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                        }}
                        filterOption={(option, rawInput) => {
                          if (rawInput) {
                            if (cascadeCount === 0)
                              return option.data._cascadeLevel <= 3 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                            if (cascadeCount === 1)
                              return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 3 && String(option.data._fields.location_id) === String(newTicket.location_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                            if (cascadeCount === 2)
                              return option.data._cascadeLevel >= 2 && option.data._cascadeLevel <= 3 && String(option.data._fields.building_id) === String(newTicket.building_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                            if (cascadeCount === 3)
                              return option.data._cascadeLevel >= 3 && option.data._cascadeLevel <= 3 && String(option.data._fields.room_id) === String(newTicket.room_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          }
                          if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                          if (cascadeCount === 1) return option.data._cascadeLevel === 1 && String(option.data._parentId) === String(newTicket.location_id);
                          if (cascadeCount === 2) return option.data._cascadeLevel === 2 && String(option.data._parentId) === String(newTicket.building_id);
                          if (cascadeCount === 3) return option.data._cascadeLevel === 3 && String(option.data._parentId) === String(newTicket.room_id);
                          return false;
                        }}
                        value={currentDisplayValue}
                        onChange={(selectedOption) => {
                          if (!selectedOption) { setNewTicket(p => ({...p, location_id: "", building_id: "", room_id: "", asset_id: ""})); return; }
                          setNewTicket(p => ({...p, ...selectedOption._fields}));
                          setInvalidFields(prev => { const next = {...prev}; delete next.location_id; return next; });
                          const labels = ["Terrein","Gebou","Lokaal","Bate"];
                          const label = labels[selectedOption._cascadeLevel] || "";
                          setCascadeToast(`✓ ${label} suksesvol geselekteer`);
                          setTimeout(() => setCascadeToast(null), 2000);
                        }}
/>
                     </div>
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
            <AiSuggestPanel
              suggestions={faultSuggestions}
              loading={aiLoading}
              filled={aiFilled}
              error={aiError}
              labels={{ fault_type: 'Kategorie', fault_priority: 'Prioriteit' }}
              onUse={(key, s) => {
                if (key === 'fault_type') {
                  const af = FAULT_TYPE_EN_AF[s.value] || s.value;
                  setNewTicket(p => ({ ...p, category: af }));
                  setInvalidFields(prev => { const next = {...prev}; delete next.category; return next; });
                } else if (key === 'fault_priority') {
                  setNewTicket(p => ({ ...p, priority: FAULT_PRIO_EN_AF[s.value] || s.value }));
                }
              }}
            />
          </div>
        </div>
      )}
      {dialog}
    </div>
  );
}

export default TicketPage;