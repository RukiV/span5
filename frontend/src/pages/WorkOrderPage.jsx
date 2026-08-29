import React, { useState, useEffect, useRef, useMemo } from "react";
import { Link, useSearchParams, useLocation } from "react-router-dom";
import { useMsal } from '@azure/msal-react';
import Select, { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";
import { renderBreadcrumb, CascadeControl } from "../components/controlHelpers";
import { apiClient, assetsAPI, workOrdersAPI, quotesAPI, roomsAPI, ticketsAPI, buildingsAPI, locationAPI, usersAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import { loginRequest } from '../services/msalConfig';
import { normalizeWorkOrdersPayload } from './workOrderUtils';
import { buildFlatLocationOptions } from './locationSearchUtils';
import { useToast } from '../components/Toast/useToast';
import '../styles/App.css';
import "../styles/WorkOrder.css";
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import ResizableTh from "../components/ResizableTh";
import useAiSuggestions from "../hooks/useAiSuggestions";
import AiSuggestPanel from "../components/AiSuggestPanel";
import ImportExportModal from "../components/DataTransfer/ImportExportModal";
import useCascadeMenu from "../hooks/useCascadeMenu";

function WorkOrderPage() {
  const { confirm, dialog } = useConfirmDialog();
  const { showToast } = useToast();
  const { user, hasRight } = useCurrentUser();
  const { instance } = useMsal();
  const location = useLocation();
  const [showImportWizard, setShowImportWizard] = useState(false);
  
  // State vir werksopdragte-lys
  const [workOrders, setWorkOrders] = useState([]);
  const [assets, setAssets] = useState([]);               // Bates vir toekenning
  const [rooms, setRooms] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");        // Soek op ID/Beskrywing
  const [filterColumn, setFilterColumn] = useState("all");
  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: 'id' });

  const WORKORDER_COLUMNS = [
    { key: 'id', label: 'ID', render: (o) => o.jobcard_id, sortKey: 'id', defaultVisible: true },
    { key: 'description', label: 'Beskrywing', render: (o) => o.job_desc || '-', sortKey: 'description', defaultVisible: true },
    { key: 'type', label: 'Werksoort', render: (o) => o.job_type || '-', sortKey: 'type', defaultVisible: true },
    { key: 'priority', label: 'Prioriteit', render: (o) => o.job_priority || '-', sortKey: 'priority', defaultVisible: false },
    { key: 'asset_id', label: 'Bate ID', render: (o) => o.asset_id || '-', sortKey: 'asset_id', defaultVisible: false },
    { key: 'fault_id', label: 'Fault ID', render: (o) => o.fault_id || '-', sortKey: 'fault_id', defaultVisible: false },
    { key: 'location_id', label: 'Terrein ID', render: (o) => o.location_id || '-', sortKey: 'location_id', defaultVisible: false },
    { key: 'building_id', label: 'Gebou ID', render: (o) => o.building_id || '-', sortKey: 'building_id', defaultVisible: false },
    { key: 'room_id', label: 'Lokaal ID', render: (o) => o.room_id || '-', sortKey: 'room_id', defaultVisible: false },
    { key: 'date', label: 'Datum', render: (o) => o.job_scheduled_datetime ? new Date(o.job_scheduled_datetime).toLocaleDateString('af-ZA') : (o.job_createddatetime ? new Date(o.job_createddatetime).toLocaleDateString('af-ZA') : '-'), sortKey: 'date', defaultVisible: true },
    { key: 'status', label: 'Status', render: (o) => <span className={`status-badge ${getStatusClass(o.job_status)}`}>{translateStatus(o.job_status)}</span>, sortKey: 'status', defaultVisible: true },
    { key: 'assigned', label: 'Toegewys', render: (o) => o.assigned_to || '-', sortKey: 'assigned', defaultVisible: false },
    { key: 'nature', label: 'Aard', render: (o) => o.nature || '-', sortKey: 'nature', defaultVisible: false },
    { key: 'created', label: 'Geskep', render: (o) => o.job_createddatetime ? new Date(o.job_createddatetime).toLocaleDateString('af-ZA') : '-', sortKey: 'created', defaultVisible: false },
    { key: 'finished', label: 'Voltooi', render: (o) => o.job_finisheddatetime ? new Date(o.job_finisheddatetime).toLocaleDateString('af-ZA') : '-', sortKey: 'finished', defaultVisible: false },
  ];
  const colVis = useColumnVisibility('workorder-page', WORKORDER_COLUMNS);
  const colWidths = useColumnWidths('workorder-page', WORKORDER_COLUMNS);
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
  const [pendingJobcardId, setPendingJobcardId] = useState(null);
  const [users, setUsers] = useState([]);
  const [quotes, setQuotes] = useState([]);
  const [selectedQuoteId, setSelectedQuoteId] = useState(null);
  const [newQuote, setNewQuote] = useState({ contractor_id: "" });
  const [quoteEditId, setQuoteEditId] = useState(null);
  const [quoteSelectionReasons, setQuoteSelectionReasons] = useState({});
  const [connectionType, setConnectionType] = useState("");
  const [connectionTargetId, setConnectionTargetId] = useState("");

  const [activeTab, setActiveTab] = useState("besonderhede");
  const [cascadeToast, setCascadeToast] = useState(null);
  const [showSchedulerPopup, setShowSchedulerPopup] = useState(false);
  const [tempSchedule, setTempSchedule] = useState({ date: '', startH: '08', startTens: '0', startOnes: '0', endH: '09', endTens: '0', endOnes: '0' });
  const [scheduleViewMonth, setScheduleViewMonth] = useState(new Date().getMonth());
  const [scheduleViewYear, setScheduleViewYear] = useState(new Date().getFullYear());
  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});
  const liggingRef = useRef(null);

  const MAX_JOB_IMAGES = 3;
  const [jobImages, setJobImages] = useState([]);
  const [ticketImages, setTicketImages] = useState([]);
  const [selectedImageFiles, setSelectedImageFiles] = useState([]);
  const [selectedImagePreviewUrls, setSelectedImagePreviewUrls] = useState([]);
  const [imagesToDelete, setImagesToDelete] = useState([]);
  const [activeImageViewer, setActiveImageViewer] = useState(null);

  const [quoteDocuments, setQuoteDocuments] = useState({});
  const [quotePdfFiles, setQuotePdfFiles] = useState({});
  const [quotePdfPreviewUrls, setQuotePdfPreviewUrls] = useState({});

  // Nuwe state spesifiek vir Terrein en Gebou interaktiewe dropdowns binne die modal
  const [selectedTerrein, setSelectedTerrein] = useState(null);
  const [selectedGebou, setSelectedGebou] = useState(null);

  // Beheer dubbel-submissie: verhoed spam-klikke op "Stoor Kaart" en hou 'n
  // stabiele idempotensie-sleutel per modaal-oop vir dedup op die backend.
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [idempotencyKey, setIdempotencyKey] = useState(null);
  
  // Vorm-data vir werksopdrag (uitgebreide velde)
  const [formData, setFormData] = useState({
    // Hoofinligting
    job_desc: "",                   // Hoofbeskrywing
    job_type: "",                   // Werksoort (maintenance, repair, inspection, installation, emergency)
    job_status: "",                  // Status (Oop, Wag, Voltooid)
    job_priority: "",                // Prioriteit
    job_createddatetime: "",        // Skeppingsdatum
    job_scheduled_datetime: "",     // Geskeduleerde datum
    job_scheduled_end_datetime: "", // Geskeduleerde einddatum
    job_schedule_type: "enkel",     // Herhalingstipe

    // Aanspreekpunt-inligting
    contact_name: "",               // Naam van persoon
    contact_email: "",              // E-pos
    contact_phone: "",              // Telefoonnommer
    
    // Asset en Lokasie
    asset_id: "",                   // Bate-ID
    room_id: "",                    // Kamer/Lokasie
    building_id: "",
    location_id: "",
    fault_id: "",
    
    // Werk-inligting
    nature: "",                     // Aard van werk
    brief_description: "",          // Kort Beskrywing
    job_notes: "",                  // Gedetailleerde aantekeninge
    
    // Voltooiings-inligting
    authorized_by: "",              // Goedgekeur deur
    completed_date: "",             // Voltooide datum
    cost_recovery_notes: "",        // Kostetoerekening-aantekeninge

    // Toewysing
    assigned_to: null,              // Verantwoordelike gebruiker (user_id)
    cc_users: [],                   // CC gebruikers (array van user_id's)
  });

  // AI-veldvoorstelle: werksoort/prioriteit uit die beskrywing (reëls-klassifiseerder).
  // Die vorm gebruik Afrikaanse vertoonwaardes — map die enjin se EN-enum hier.
  const JOB_TYPE_EN_AF = { REPAIR: 'Herstel', MAINTENANCE: 'Onderhoud', INSPECTION: 'Inspeksie', INSTALLATION: 'Installasie' };
  const JOB_PRIO_EN_AF = { LOW: 'Laag', MEDIUM: 'Normal', HIGH: 'Hoog' };
  const aiSuggestions = useAiSuggestions({
    context: 'job',
    values: {
      job_desc: formData.job_desc,
      job_type: formData.job_type,
      job_priority: formData.job_priority,
      nature: formData.nature,
      job_status: formData.job_status,
    },
  });
  const { suggestions: jobSuggestions, loading: aiLoading, filled: aiFilled, error: aiError } = aiSuggestions;

  const [searchParams, setSearchParams] = useSearchParams();

  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, rooms, assets), [terrains, buildings, rooms, assets]);

  // Voeg 'n gebruiker by die CC-lys (sonder duplikate); ongeldige id's word geïgnoreer.
  const addCcUser = (cc, userId) => {
    const list = Array.isArray(cc) ? cc : [];
    const id = Number(userId);
    if (id && !list.includes(id)) return [...list, id];
    return list;
  };

  const applyTicketSelectionToForm = (ticket) => {
    if (!ticket) return;

    const description = ticket.fault_description || "";
    const colonIndex = description.indexOf(":");
    const briefDesc = colonIndex > 0 ? description.substring(0, colonIndex).trim() : description;
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

    setFormData((prev) => ({
      ...prev,
      job_desc: description,
      job_type: normalizeWorkTypeValue(ticket.fault_type) || "",
      job_priority: normalizePriorityValue(ticket.fault_priority) || "Normal",
      job_status: "Oop",
      brief_description: briefDesc,
      job_notes: details,
      nature: ticket.nature || "",
      asset_id: ticket.asset_id ? String(ticket.asset_id) : "",
      room_id: detectedRoomId ? String(detectedRoomId) : "",
      building_id: detectedBuildingId ? String(detectedBuildingId) : "",
      location_id: detectedSiteId ? String(detectedSiteId) : "",
      fault_id: ticket.fault_id ? String(ticket.fault_id) : "",
      cc_users: addCcUser(prev.cc_users, ticket.user_id),
    }));

    setConnectionType("fault");
    setConnectionTargetId(String(ticket.fault_id || ""));

    if (detectedRoomId) {
      const matchingRoom = rooms.find((room) => String(room.room_id) === String(detectedRoomId));
      if (matchingRoom) {
        setSelectedTerrein(matchingRoom.terrein ? { value: matchingRoom.terrein, label: matchingRoom.terrein } : null);
        setSelectedGebou(matchingRoom.gebou ? { value: matchingRoom.gebou, label: matchingRoom.gebou } : null);
      }
    } else {
      setSelectedTerrein(null);
      setSelectedGebou(null);
    }
  };

  // Haal almal data wanneer blad laai
  useEffect(() => {
    const requestedJobcardId = searchParams.get('jobcard_id');
    const requestedSearch = searchParams.get('search');
    if (requestedJobcardId) {
      setPendingJobcardId(Number(requestedJobcardId));
    }
    if (requestedSearch) {
      setSearchTerm(requestedSearch);
    }
    fetchWorkOrders();
    fetchAssets();
    fetchRooms();
    fetchBuildings();
    fetchTerrains();
    fetchTickets();
    fetchUsers();
  }, []);

  useEffect(() => {
    if (location.state?.ticket) {
      setShowModal(true);
      setIsEditing(false);
      setEditingId(null);
      applyTicketSelectionToForm(location.state.ticket);
      const faultId = location.state.ticket.fault_id;
      if (faultId) fetchTicketImages(faultId);
    }
  }, [location.state?.ticket, assets, rooms, buildings, terrains]);

  useEffect(() => {
    if (user?.role_id === 2 && user?.location_id) {
      setTerrainFilter(String(user.location_id));
    } else {
      setTerrainFilter("");
    }
  }, [user]);

  useEffect(() => {
    return () => {
      selectedImagePreviewUrls.forEach((url) => URL.revokeObjectURL(url));
      Object.values(quotePdfPreviewUrls).forEach((url) => URL.revokeObjectURL(url));
    };
  }, []);

  const fetchTerrains = async () => {
    try {
      const response = await locationAPI.getAll();
      setTerrains(response.data || []);
    } catch (error) {
      console.error("Fout by haal terreine:", error);
    }
  };

  const fetchBuildings = async () => {
    try {
      const response = await buildingsAPI.getAll();
      setBuildings(response.data || []);
    } catch (error) {
      console.error("Fout by haal geboue:", error);
    }
  };

  const fetchRooms = async () => {
    try {
      const response = await roomsAPI.getAll();
      setRooms(response.data || []);
    } catch (error) {
      console.error("Fout by haal lokale:", error);
    }
  };

  const fetchTickets = async () => {
    try {
      const response = await ticketsAPI.getAll();
      setTickets(response.data || []);
    } catch (error) {
      console.error("Fout by haal foutkaartjies:", error);
    }
  };

  const fetchUsers = async () => {
    try {
      const response = await usersAPI.getAll();
      setUsers(response.data || []);
    } catch (error) {
      console.error("Fout by haal gebruikers:", error);
    }
  };

  const fetchJobImages = async (jobcardId) => {
    if (!jobcardId) {
      setJobImages([]);
      return;
    }
    try {
      const response = await apiClient.image.getByParent("job", jobcardId);
      setJobImages(response.data || []);
    } catch (error) {
      console.error("Fout by laai van werksopdrag-beelde:", error);
      setJobImages([]);
    }
  };

  const fetchTicketImages = async (faultId) => {
    if (!faultId) {
      setTicketImages([]);
      return;
    }
    try {
      const response = await apiClient.image.getByParent("ticket", faultId);
      setTicketImages(response.data || []);
    } catch (error) {
      console.error("Fout by laai van foutkaartjie-beelde:", error);
      setTicketImages([]);
    }
  };

  const getJobImageUrl = (imageId) => {
    if (!imageId) return null;
    return apiClient.image?.getFileUrl ? apiClient.image.getFileUrl(imageId) : null;
  };

  const handleImageFilesChange = (event) => {
    const files = Array.from(event.target.files || []);
    const remainingSlots = Math.max(0, MAX_JOB_IMAGES - (selectedImageFiles.length + jobImages.length));
    const incomingFiles = files.slice(0, remainingSlots);

    if (files.length > remainingSlots) {
      showToast({ type: 'warning', title: `Jy kan maksimaal ${MAX_JOB_IMAGES} beelde per werksopdrag oplaai.` });
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
      if (urlToRevoke) URL.revokeObjectURL(urlToRevoke);
      return prev.filter((_, itemIndex) => itemIndex !== index);
    });
  };

  const handleDeleteExistingImage = async (imageId) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie beeld verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;

    setJobImages((prev) => prev.filter((image) => image.image_id !== imageId));
    setImagesToDelete((prev) => (prev.includes(imageId) ? prev : [...prev, imageId]));
  };

  const fetchQuoteDocuments = async (quoteId) => {
    if (!quoteId) return [];
    try {
      const response = await apiClient.documents.getByQuote(quoteId);
      return response.data || [];
    } catch (error) {
      console.error("Fout by laai van kwotasie-dokumente:", error);
      return [];
    }
  };

  const viewQuotePdf = async (documentId) => {
    if (!documentId) return;
    try {
      const response = await apiClient.get(`/documents/${documentId}/file`, { responseType: 'blob' });
      const blob = new Blob([response.data], { type: response.headers['content-type'] || 'application/pdf' });
      const url = URL.createObjectURL(blob);
      window.open(url, '_blank');
      setTimeout(() => URL.revokeObjectURL(url), 60000);
    } catch (error) {
      console.error("Fout by laai van PDF:", error);
      showToast({ type: 'error', title: 'Kon nie PDF laai nie.' });
    }
  };

  const handleQuotePdfSelect = (quoteId, event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    if (file.type !== "application/pdf") {
      showToast({ type: 'warning', title: 'Slegs PDF-lêers word toegelaat.' });
      event.target.value = "";
      return;
    }
    setQuotePdfFiles((prev) => ({ ...prev, [quoteId]: file }));
    setQuotePdfPreviewUrls((prev) => {
      if (prev[quoteId]) URL.revokeObjectURL(prev[quoteId]);
      return { ...prev, [quoteId]: URL.createObjectURL(file) };
    });
    event.target.value = "";
  };

  const handleQuotePdfDelete = async (quoteId) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie PDF verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;
    setQuotePdfFiles((prev) => {
      const next = { ...prev };
      delete next[quoteId];
      return next;
    });
    setQuotePdfPreviewUrls((prev) => {
      const next = { ...prev };
      if (next[quoteId]) URL.revokeObjectURL(next[quoteId]);
      delete next[quoteId];
      return next;
    });
    const docs = quoteDocuments[quoteId];
    if (docs && docs.length > 0) {
      const doc = docs[0];
      apiClient.documents.delete(doc.document_id).catch(() => {});
      setQuoteDocuments((prev) => {
        const next = { ...prev };
        delete next[quoteId];
        return next;
      });
    }
  };

  // Haal werksopdragte-lys van backend
  const fetchWorkOrders = async () => {
    setLoading(true);
    try {
      const response = await workOrdersAPI.getAll();
      const payload = response?.data ?? response;
      setWorkOrders(normalizeWorkOrdersPayload(payload));

      if (pendingJobcardId) {
        const matchingOrder = payload.find((payload) => payload.jobcard_id === pendingJobcardId);
        if (matchingOrder) {
          handleEditWorkOrder(matchingOrder);
          setSearchParams({});
        }
      }
    } catch (error) {
      console.error("Fout by haal werksopdragte:", error);
      setWorkOrders([]);
    } finally {
      setLoading(false);
    }
  };

  // Haal bates-lys vir dropdown-keuse
  const fetchAssets = async () => {
    try {
      const response = await assetsAPI.getAll();
      setAssets(response.data);
    } catch (error) {
      console.error("Fout by haal bates:", error);
    }
  };

  // Hulpfunksie: Formateer datetime na date-only (YYYY-MM-DD)
  const formatDateForInput = (dateString) => {
    if (!dateString) return "";
    return dateString.split('T')[0];
  };

  const formatDateTimeForInput = (value) => {
    if (!value) return "";

    if (typeof value === "string") {
      const trimmed = value.trim();
      if (!trimmed) return "";
      if (trimmed.includes("T")) return trimmed.slice(0, 16);
      if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return `${trimmed}T00:00`;

      const parsed = new Date(trimmed);
      if (!Number.isNaN(parsed.getTime())) {
        return parsed.toISOString().slice(0, 16);
      }

      return trimmed;
    }

    if (value instanceof Date) {
      return value.toISOString().slice(0, 16);
    }

    return "";
  };

  const formatDateTimeForPayload = (value) => {
    if (!value) return null;
    if (typeof value === "string" && value.includes("T")) return value;
    if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) return `${value}T00:00:00`;
    return value;
  };

  const parseQuoteIds = (value) => {
    if (!value) return [];
    return String(value)
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean)
      .map((item) => Number(item))
      .filter((item) => !Number.isNaN(item));
  };

  const normalizeWorkTypeValue = (value) => {
    const normalized = String(value || "").trim().toLowerCase();
    if (["maintenance", "onderhoud", "instandhouding"].includes(normalized)) return "Onderhoud";
    if (["repair", "herstel", "herstelwerk"].includes(normalized)) return "Herstel";
    if (["inspection", "inspeksie"].includes(normalized)) return "Inspeksie";
    if (["installation", "installasie"].includes(normalized)) return "Installasie";
    return String(value || "").trim();
  };

  const normalizePriorityValue = (value) => {
    const normalized = String(value || "").trim().toLowerCase();
    if (["laag", "low"].includes(normalized)) return "Laag";
    if (["normal", "medium", "normaal"].includes(normalized)) return "Normal";
    if (["hoog", "high"].includes(normalized)) return "Hoog";
    if (["dringend", "urgent"].includes(normalized)) return "Dringend";
    return String(value || "").trim() || "Normal";
  };

  const getTicketDisplayTitle = (ticket) => {
    const rawValue = ticket?.fault_title || ticket?.title || ticket?.fault_desc || ticket?.fault_description || ticket?.description || "";
    const text = String(rawValue || "").trim();
    if (!text) return "Foutkaartjie";

    const colonIndex = text.indexOf(":");
    return colonIndex > 0 ? text.substring(0, colonIndex).trim() : text;
  };

  const getTicketOptionLabel = (ticket) => {
    const ticketId = ticket?.fault_id ?? ticket?.id ?? "";
    const title = getTicketDisplayTitle(ticket);
    return ticketId ? `${ticketId} - ${title}` : title;
  };

  const getMicrosoftAccessToken = async () => {
    let msAccessToken = sessionStorage.getItem('ms_access_token');
    if (msAccessToken) return msAccessToken;

    const account = instance.getActiveAccount();
    if (!account) {
      throw new Error('No active Microsoft account');
    }

    const response = await instance.acquireTokenSilent({ ...loginRequest, account });
    msAccessToken = response.accessToken;
    sessionStorage.setItem('ms_access_token', msAccessToken);
    return msAccessToken;
  };

  const buildCalendarMarker = (workOrderId) => `FBS-WO-${workOrderId}`;

  const deleteScheduledOutlookEventsForWorkOrder = async (workOrderId) => {
    if (!workOrderId) return;

    try {
      const msAccessToken = await getMicrosoftAccessToken();
      const marker = buildCalendarMarker(workOrderId);
      const response = await fetch(
        'https://graph.microsoft.com/v1.0/me/events?$top=100&$select=id,subject,bodyPreview',
        {
          headers: {
            Authorization: `Bearer ${msAccessToken}`,
          },
        }
      );

      if (!response.ok) return;

      const data = await response.json();
      for (const event of data.value || []) {
        const subject = event.subject || '';
        const body = event.bodyPreview || '';
        if (subject.includes(marker) || body.includes(marker)) {
          await fetch(`https://graph.microsoft.com/v1.0/me/events/${event.id}`, {
            method: 'DELETE',
            headers: {
              Authorization: `Bearer ${msAccessToken}`,
            },
          });
        }
      }
    } catch (error) {
      console.warn('Kon Outlook-afsprake vir werksopdrag nie verwyder nie:', error);
    }
  };

  const createScheduledOutlookEventForWorkOrder = async (workOrderId, workOrderData) => {
    if (!workOrderId || !workOrderData?.job_scheduled_datetime) return;

    try {
      const msAccessToken = await getMicrosoftAccessToken();
      const marker = buildCalendarMarker(workOrderId);
      const subject = `${marker} ${workOrderData.job_desc || 'Werksopdrag'}`;
      const startDateTime = String(workOrderData.job_scheduled_datetime).replace(' ', 'T');
      const start = new Date(startDateTime);
      const end = new Date(start.getTime() + 60 * 60 * 1000);
      const startValue = `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}-${String(start.getDate()).padStart(2, '0')}T${String(start.getHours()).padStart(2, '0')}:${String(start.getMinutes()).padStart(2, '0')}:00`;
      const endValue = `${end.getFullYear()}-${String(end.getMonth() + 1).padStart(2, '0')}-${String(end.getDate()).padStart(2, '0')}T${String(end.getHours()).padStart(2, '0')}:${String(end.getMinutes()).padStart(2, '0')}:00`;

      const payload = {
        subject,
        body: {
          contentType: 'HTML',
          content: `<p>Werksopdrag ID: ${workOrderId}</p><p>${workOrderData.job_desc || 'Werksopdrag'}</p>`,
        },
        start: {
          dateTime: startValue,
          timeZone: 'South Africa Standard Time',
        },
        end: {
          dateTime: endValue,
          timeZone: 'South Africa Standard Time',
        },
      };

      if (workOrderData.job_schedule_type === 'weekliks') {
        payload.recurrence = {
          pattern: {
            type: 'weekly',
            interval: 1,
            daysOfWeek: [start.toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase()],
          },
          range: {
            type: 'noEnd',
            startDate: `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}-${String(start.getDate()).padStart(2, '0')}`,
          },
        };
      } else if (workOrderData.job_schedule_type === 'maandeliks') {
        payload.recurrence = {
          pattern: {
            type: 'absoluteMonthly',
            interval: 1,
            dayOfMonth: start.getDate(),
          },
          range: {
            type: 'noEnd',
            startDate: `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}-${String(start.getDate()).padStart(2, '0')}`,
          },
        };
      } else if (workOrderData.job_schedule_type === 'jaarliks') {
        payload.recurrence = {
          pattern: {
            type: 'absoluteYearly',
            interval: 1,
            dayOfMonth: start.getDate(),
            month: start.getMonth() + 1,
          },
          range: {
            type: 'noEnd',
            startDate: `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}-${String(start.getDate()).padStart(2, '0')}`,
          },
        };
      }

      await fetch('https://graph.microsoft.com/v1.0/me/events', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${msAccessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });
    } catch (error) {
      console.warn('Kon Outlook-afspraak vir werksopdrag nie skep nie:', error);
    }
  };

  // Hanteer redigering van werksopdrag
  async function handleEditWorkOrder(order) {
    setIsEditing(true);
    setEditingId(order.jobcard_id);

    // Ontleed beskrywing
    const description = order.job_desc || "";
    const colonIndex = description.indexOf(":");
    const briefDesc = colonIndex > 0 ? description.substring(0, colonIndex).trim() : description;
    const details = colonIndex > 0 ? description.substring(colonIndex + 1).trim() : "";

    setFormData({
      job_desc: description,
      job_type: normalizeWorkTypeValue(order.job_type) || "",
      job_status: order.job_status,
      job_priority: order.job_priority || "Normal",
      job_createddatetime: formatDateForInput(order.job_createddatetime),
      job_scheduled_datetime: formatDateTimeForInput(order.job_scheduled_datetime || order.job_createddatetime),
      job_scheduled_end_datetime: formatDateTimeForInput(order.job_scheduled_end_datetime) || "",
      job_schedule_type: order.job_schedule_type || "enkel",
      contact_name: order.contact_name || "",
      contact_email: order.contact_email || "",
      contact_phone: order.contact_phone || "",
      asset_id: order.asset_id || "",
      room_id: order.room_id || "",
      building_id: order.building_id || "",
      location_id: order.location_id || "",
      fault_id: order.fault_id || "",
      nature: order.nature || "",
      brief_description: briefDesc,
      // Kontrakteur-werknotas kom uit die aparte job_notes-veld (sodat notas wat
      // deur kontrakteurs op die mobiele app gestoor is, hier ook gesien word);
      // val terug op die ou job_desc-inbedding ("brief: notes") vir ou rekords.
      job_notes: order.job_notes || details,
      authorized_by: order.authorized_by || "",
      completed_date: formatDateForInput(order.job_finisheddatetime),
      cost_recovery_notes: order.cost_recovery_notes || "",
      assigned_to: order.assigned_to ? Number(order.assigned_to) : null,
      cc_users: order.cc_users
        ? String(order.cc_users).split(",").map((id) => Number(id.trim())).filter((id) => !isNaN(id))
        : [],
    });

    // Stel koppelings-tipe vas
    if (order.asset_id) {
      setConnectionType("asset");
      setConnectionTargetId(String(order.asset_id));
      // Probeer terrein en gebou vooraf kies op grond van die bate se lokaal
      const matchingAsset = assets.find(a => String(a.asset_id) === String(order.asset_id));
      if (matchingAsset && matchingAsset.room_id) {
        const matchingRoom = rooms.find(r => String(r.room_id) === String(matchingAsset.room_id));
        if (matchingRoom) {
          setSelectedTerrein(matchingRoom.terrein ? { value: matchingRoom.terrein, label: matchingRoom.terrein } : null);
          setSelectedGebou(matchingRoom.gebou ? { value: matchingRoom.gebou, label: matchingRoom.gebou } : null);
        }
      }
    } else if (order.room_id) {
      setConnectionType("room");
      setConnectionTargetId(String(order.room_id));
      const matchingRoom = rooms.find(r => String(r.room_id) === String(order.room_id));
      if (matchingRoom) {
        setSelectedTerrein(matchingRoom.terrein ? { value: matchingRoom.terrein, label: matchingRoom.terrein } : null);
        setSelectedGebou(matchingRoom.gebou ? { value: matchingRoom.gebou, label: matchingRoom.gebou } : null);
      }
    } else if (order.fault_id) {
      setConnectionType("fault");
      setConnectionTargetId(String(order.fault_id));
      setSelectedTerrein(null);
      setSelectedGebou(null);
    } else {
      setConnectionType("");
      setConnectionTargetId("");
      setSelectedTerrein(null);
      setSelectedGebou(null);
    }

    const quoteIds = parseQuoteIds(order.quote_ids || (order.quote_id ? String(order.quote_id) : ""));

    if (quoteIds.length > 0) {
      try {
        const contractorUsers = users.filter(u => u.role_id === 4);
        const quoteResponses = await Promise.allSettled(quoteIds.map((id) => quotesAPI.getById(id)));
        const loadedQuotes = quoteResponses
          .filter((result) => result.status === "fulfilled" && result.value)
          .map((result) => {
            const response = result.value;
            const quoteData = response.data || response;
            const contractorUser = contractorUsers.find((u) => u.user_id === Number(quoteData.contractor_id));
            return {
              id: quoteData.quote_id,
              dbId: quoteData.quote_id,
              contractor_id: quoteData.contractor_id ? Number(quoteData.contractor_id) : "",
              contractor_name: contractorUser ? contractorUser.user_name + " " + contractorUser.user_surname : "",
              createdAt: quoteData.quote_date || new Date().toLocaleDateString('af-ZA'),
              selection_reason: quoteData.quote_selection_reason || ""
            };
          });
        setQuotes(loadedQuotes);
        const loadedReasonMap = Object.fromEntries(
          loadedQuotes.map((quote) => [quote.id, quote.selection_reason || ""])
        );
        setQuoteSelectionReasons((prev) => ({ ...prev, ...loadedReasonMap }));
        const selectedQuoteFromOrder = order.quote_id ? Number(order.quote_id) : null;
        setSelectedQuoteId(
          loadedQuotes.some((quote) => quote.id === selectedQuoteFromOrder)
            ? selectedQuoteFromOrder
            : loadedQuotes[0]?.id ?? null
        );
      } catch (error) {
        console.error("Fout by laai kwotasies:", error);
        setQuotes([]);
        setSelectedQuoteId(null);
      }
    } else {
      setQuotes([]);
      setSelectedQuoteId(null);
    }

    fetchJobImages(order.jobcard_id);
    if (order.fault_id) {
      fetchTicketImages(order.fault_id);
    }

    const docsMap = {};
    for (const qId of quoteIds) {
      if (qId) {
        const docs = await fetchQuoteDocuments(qId);
        if (docs.length > 0) docsMap[qId] = docs;
      }
    }
    setQuoteDocuments(docsMap);

    setShowModal(true);
  }

  // Hanteer besparing van werksopdrag
  const handleSaveWorkOrder = async () => {
    try {
      const errors = {};
      if (!formData.job_status) errors.job_status = true;
      if (!formData.job_priority) errors.job_priority = true;
      if (!formData.nature) errors.nature = true;
      if (!formData.job_type) errors.job_type = true;
      if (!formData.brief_description?.trim()) errors.brief_description = true;
      if (!formData.location_id) errors.location_id = true;
      if (Object.keys(errors).length > 0) {
        setInvalidFields(errors);
        const firstKey = Object.keys(errors)[0];
        fieldRefs.current[firstKey]?.scrollIntoView({ behavior: "smooth", block: "center" });
        fieldRefs.current[firstKey]?.focus();
        return;
      }
      setInvalidFields({});

      if (isSubmitting) return;
      setIsSubmitting(true);

      const payload = {
        job_desc: `${formData.brief_description}${formData.job_notes ? `: ${formData.job_notes}` : ''}`,
        job_type: formData.job_type || null,
        job_status: formData.job_status,
        job_priority: formData.job_priority || "Normal",
        nature: formData.nature || null,
        job_notes: formData.job_notes || null,
        job_createddatetime: formatDateTimeForPayload(formData.job_createddatetime) || new Date().toISOString(),
        job_scheduled_datetime: formatDateTimeForPayload(formData.job_scheduled_datetime) || formatDateTimeForPayload(formData.job_createddatetime) || new Date().toISOString(),
        job_scheduled_end_datetime: formatDateTimeForPayload(formData.job_scheduled_end_datetime) || null,
        job_schedule_type: formData.job_schedule_type || "enkel",
        asset_id: formData.asset_id ? Number(formData.asset_id) : null,
        room_id: formData.room_id ? Number(formData.room_id) : null,
        building_id: formData.building_id ? Number(formData.building_id) : null,
        location_id: formData.location_id ? Number(formData.location_id) : null,
        fault_id: formData.fault_id ? Number(formData.fault_id) : null,
        job_finisheddatetime: formatDateTimeForPayload(formData.completed_date),
        assigned_to: formData.assigned_to ? Number(formData.assigned_to) : null,
        cc_users: formData.cc_users && formData.cc_users.length > 0
          ? formData.cc_users.join(",")
          : null,
      };

      let savedWorkOrderResponse;
      let savedWorkOrder;
      let workOrderId;

      if (isEditing) {
        savedWorkOrderResponse = await workOrdersAPI.update(editingId, payload);
        savedWorkOrder = savedWorkOrderResponse?.data || savedWorkOrderResponse;
        workOrderId = savedWorkOrder?.jobcard_id || editingId;
      } else {
        // Stabiliseer die sleutel vir die volle modaal-oop: dieselfde
        // X-Idempotency-Key word hergebruik vir alle pogings sodat spam-klikke
        // (met 'n nuwe job_createddatetime per klik) op die backend gededupeer word.
        const key = idempotencyKey
          || (typeof crypto !== 'undefined' && crypto.randomUUID
            ? crypto.randomUUID()
            : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`);
        if (!idempotencyKey) setIdempotencyKey(key);
        savedWorkOrderResponse = await workOrdersAPI.create(payload, { headers: { 'X-Idempotency-Key': key } });
        savedWorkOrder = savedWorkOrderResponse?.data || savedWorkOrderResponse;
        workOrderId = savedWorkOrder?.jobcard_id || editingId;
      }

      if (quotes.some((quote) => !quote.contractor_id || !(quotePdfFiles[quote.id] || quoteDocuments[quote.id]?.[0]))) {
        showToast({ type: 'warning', title: "Elke kwotasie moet 'n kontrakteur en 'n PDF-dokument hê." });
        return;
      }

      if (selectedQuoteId && !String(quoteSelectionReasons[selectedQuoteId] || "").trim()) {
        showToast({ type: 'warning', title: "Gee asseblief 'n rede waarom die gekose kwotasie gekies is." });
        return;
      }

      const createdQuoteIds = [];
      let selectedCreatedQuoteId = null;
      const failedQuotes = [];

      for (const quote of quotes) {
        const quotePayload = {
          quote_date: new Date().toISOString().split('T')[0],
          quote_status: "Pending",
          quote_selection_reason: quoteSelectionReasons[quote.id] || null,
          contractor_id: quote.contractor_id ? Number(quote.contractor_id) : null,
        };

        try {
          let createdQuoteId;
          if (quote.dbId) {
            await quotesAPI.update(quote.dbId, quotePayload);
            createdQuoteId = quote.dbId;
          } else {
            const quoteResponse = await quotesAPI.create(quotePayload);
            const createdQuote = quoteResponse?.data || quoteResponse;
            createdQuoteId = createdQuote?.quote_id ?? null;
          }
          createdQuoteIds.push(createdQuoteId);

          if (selectedQuoteId && String(quote.id) === String(selectedQuoteId)) {
            selectedCreatedQuoteId = createdQuoteId;
          }
        } catch (quoteErr) {
          console.error("Fout by stoor van kwotasie:", quoteErr);
          failedQuotes.push(quote);
          createdQuoteIds.push(null);
        }
      }

      if (workOrderId) {
        const persistedQuoteIds = createdQuoteIds.filter(Boolean).join(",");
        await workOrdersAPI.update(workOrderId, {
          quote_id: selectedCreatedQuoteId ? Number(selectedCreatedQuoteId) : null,
          quote_ids: persistedQuoteIds || null,
        });

        if (payload.job_scheduled_datetime) {
          await deleteScheduledOutlookEventsForWorkOrder(workOrderId);
          await createScheduledOutlookEventForWorkOrder(workOrderId, payload);
        }

        if (isEditing) {
          for (const imageId of imagesToDelete) {
            await apiClient.image.delete(imageId);
          }
        }

        if (selectedImageFiles.length > 0) {
          for (const file of selectedImageFiles.slice(0, MAX_JOB_IMAGES)) {
            const formData = new FormData();
            formData.append("file", file);
            await apiClient.image.uploadForParent(workOrderId, "job", formData);
          }
        }

        const uploadedQuoteDocIds = [];
        for (const quote of quotes) {
          const createdQuoteId = createdQuoteIds[quotes.indexOf(quote)];
          if (createdQuoteId && quotePdfFiles[quote.id]) {
            try {
              const pdfFormData = new FormData();
              pdfFormData.append("file", quotePdfFiles[quote.id]);
              await apiClient.documents.create(createdQuoteId, pdfFormData);
              uploadedQuoteDocIds.push(createdQuoteId);
            } catch (pdfErr) {
              console.error("Fout by laai van PDF op:", pdfErr);
              showToast({ type: 'error', title: 'Kon nie PDF oplaai nie. Kyk die console vir foute.' });
            }
          }
        }

        if (uploadedQuoteDocIds.length > 0) {
          const freshDocs = {};
          for (const qId of uploadedQuoteDocIds) {
            const docs = await fetchQuoteDocuments(qId);
            if (docs.length > 0) freshDocs[qId] = docs;
          }
          setQuoteDocuments((prev) => ({ ...prev, ...freshDocs }));
        }
      }

      if (failedQuotes.length > 0) {
        showToast({ type: 'error', title: `${failedQuotes.length} kwotasie(s) kon nie gestoor word nie.` });
      }
      
      handleCloseModal();
      fetchWorkOrders();
    } catch (error) {
      console.error("Fout by besparing:", error);
      showToast({ type: 'error', title: 'Fout tydens besparing. Probeer asseblief weer.' });
    } finally {
      // Stel die submissie-vlag altyd terug, ook by vroeë returns of foute.
      setIsSubmitting(false);
    }
  };

  // ===== QUOTES FUNKSIES =====
  const handleAddQuote = () => {
    if (!newQuote.contractor_id || !quotePdfFiles[quoteEditId || "new"]) {
      showToast({ type: 'warning', title: "Kies 'n kontrakteur en laai 'n PDF op vir die kwotasie." });
      return;
    }

    const contractorUser = users.find(u => u.user_id === Number(newQuote.contractor_id));
    const existingQuote = quoteEditId ? quotes.find((q) => q.id === quoteEditId) : null;
    const updatedQuote = {
      id: quoteEditId || Date.now(),
      dbId: existingQuote?.dbId ?? null,
      contractor_id: newQuote.contractor_id ? Number(newQuote.contractor_id) : null,
      contractor_name: contractorUser ? contractorUser.user_name + " " + contractorUser.user_surname : "",
      createdAt: existingQuote?.createdAt || new Date().toLocaleDateString('af-ZA'),
      selection_reason: quoteSelectionReasons[quoteEditId] || ""
    };

    if (quoteEditId) {
      setQuotes(quotes.map((quote) => (quote.id === quoteEditId ? updatedQuote : quote)));
      setQuotePdfFiles((prev) => {
        const next = { ...prev };
        if (next["new"]) {
          next[quoteEditId] = next["new"];
          delete next["new"];
        }
        return next;
      });
      setQuotePdfPreviewUrls((prev) => {
        const next = { ...prev };
        if (next["new"]) {
          next[quoteEditId] = next["new"];
          delete next["new"];
        }
        return next;
      });
      setQuoteEditId(null);
    } else {
      const newId = updatedQuote.id;
      setQuotes([...quotes, updatedQuote]);
      setQuotePdfFiles((prev) => {
        const next = { ...prev };
        if (next["new"]) {
          next[newId] = next["new"];
          delete next["new"];
        }
        return next;
      });
      setQuotePdfPreviewUrls((prev) => {
        const next = { ...prev };
        if (next["new"]) {
          next[newId] = next["new"];
          delete next["new"];
        }
        return next;
      });
    }

    setNewQuote({ contractor_id: "" });
  };

  const handleStartEditQuote = (quoteId) => {
    const quoteToEdit = quotes.find((quote) => quote.id === quoteId);
    if (!quoteToEdit) return;

    setNewQuote({
      contractor_id: quoteToEdit.contractor_id ? String(quoteToEdit.contractor_id) : ""
    });
    setQuoteEditId(quoteId);
  };

  const handleCancelQuoteEdit = () => {
    setQuoteEditId(null);
    setQuotePdfFiles((prev) => {
      const next = { ...prev };
      delete next["new"];
      return next;
    });
    setQuotePdfPreviewUrls((prev) => {
      const next = { ...prev };
      if (next["new"]) URL.revokeObjectURL(next["new"]);
      delete next["new"];
      return next;
    });
    setNewQuote({ contractor_id: "" });
  };

  const handleDeleteQuote = (quoteId) => {
    setQuotes(quotes.filter(q => q.id !== quoteId));
    setQuoteSelectionReasons((prev) => {
      const next = { ...prev };
      delete next[quoteId];
      return next;
    });
    setQuotePdfFiles((prev) => {
      const next = { ...prev };
      delete next[quoteId];
      return next;
    });
    setQuotePdfPreviewUrls((prev) => {
      const next = { ...prev };
      if (next[quoteId]) URL.revokeObjectURL(next[quoteId]);
      delete next[quoteId];
      return next;
    });
    if (selectedQuoteId === quoteId) {
      setSelectedQuoteId(null);
    }
    if (quoteEditId === quoteId) {
      setQuoteEditId(null);
      setNewQuote({ contractor_id: "" });
    }
  };

  const handleSelectQuote = (quoteId) => {
    const nextSelectedId = quoteId === selectedQuoteId ? null : quoteId;
    setSelectedQuoteId(nextSelectedId);
    if (nextSelectedId) {
      if (!quoteSelectionReasons[nextSelectedId]) {
        setQuoteSelectionReasons((prev) => ({ ...prev, [nextSelectedId]: "" }));
      }
    }
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setIdempotencyKey(null);
    setIsSubmitting(false);
    setQuotes([]);
    setSelectedQuoteId(null);
    setQuoteEditId(null);
    setQuoteSelectionReasons({});
    setNewQuote({ contractor_id: "" });
    setJobImages([]);
    setTicketImages([]);
    setSelectedImageFiles([]);
    selectedImagePreviewUrls.forEach((url) => URL.revokeObjectURL(url));
    setSelectedImagePreviewUrls([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setQuoteDocuments({});
    setQuotePdfFiles({});
    setQuotePdfPreviewUrls((prev) => { Object.values(prev).forEach((u) => URL.revokeObjectURL(u)); return {}; });
    setConnectionType("");
    setConnectionTargetId("");
    setSelectedTerrein(null);
    setSelectedGebou(null);
    setInvalidFields({});
    setFormData({
      job_desc: "",
      job_type: "",
      job_status: "",
      job_priority: "",
      job_createddatetime: "",
      job_scheduled_datetime: "",
      job_scheduled_end_datetime: "",
      job_schedule_type: "enkel",
      contact_name: "",
      contact_email: "",
      contact_phone: "",
      asset_id: "",
      room_id: "",
      building_id: "",
      location_id: "",
      fault_id: "",
      nature: "",
      brief_description: "",
      job_notes: "",
      authorized_by: "",
      completed_date: "",
      cost_recovery_notes: "",
      assigned_to: null,
      cc_users: [],
    });
  };

  const handleNewWorkOrder = () => {
    setIsEditing(false);
    setEditingId(null);
    setSelectedTerrein(null);
    setSelectedGebou(null);
    setInvalidFields({});
    setJobImages([]);
    setTicketImages([]);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setQuoteDocuments({});
    setQuotePdfFiles({});
    setQuotePdfPreviewUrls((prev) => { Object.values(prev).forEach((u) => URL.revokeObjectURL(u)); return {}; });
    setFormData({
      job_desc: "",
      job_type: "",
      job_status: "",
      job_priority: "",
      job_createddatetime: new Date().toISOString().split('T')[0],
      job_scheduled_datetime: new Date().toISOString().slice(0, 16),
      job_scheduled_end_datetime: new Date(Date.now() + 3600000).toISOString().slice(0, 16),
      job_schedule_type: "enkel",
      contact_name: "",
      contact_email: "",
      contact_phone: "",
      asset_id: "",
      room_id: "",
      building_id: "",
      location_id: "",
      fault_id: "",
      nature: "",
      brief_description: "",
      job_notes: "",
      authorized_by: "",
      completed_date: "",
      cost_recovery_notes: "",
      assigned_to: null,
      cc_users: [],
    });
    setConnectionType("");
    setConnectionTargetId("");
    setShowModal(true);
  };

  const handleDeleteWorkOrder = async (workOrderId) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie werksopdrag verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;
    try {
      await workOrdersAPI.delete(workOrderId);
      await deleteScheduledOutlookEventsForWorkOrder(workOrderId);
      fetchWorkOrders();
    } catch (error) {
      console.error("Fout by verwydering:", error);
      showToast({ type: 'error', title: 'Fout tydens verwydering. Probeer asseblief weer.' });
    }
  };

  // Filter en sorteer werksopdragte vir tabel
  const filteredWorkOrders = [...workOrders]
    .filter((order) => {
      if (terrainFilter && String(order.location_id) !== terrainFilter) return false;
      if (buildingFilter && String(order.building_id) !== buildingFilter) return false;
      if (roomFilter && String(order.room_id) !== roomFilter) return false;

      const query = searchTerm.trim().toLowerCase();
      const description = order.job_desc || "";
      if (!query) return true;
      const values = {
        description,
        id: String(order.jobcard_id),
        job_type: order.job_type,
        asset_id: String(order.asset_id || ""),
        room_id: String(order.room_id || ""),
        building_id: String(order.building_id || ""),
        location_id: String(order.location_id || ""),
        scheduled: order.job_scheduled_datetime,
        status: order.job_status,
      };
      const matchesColumn = filterColumn === 'all'
        ? Object.values(values).some((value) => String(value || '').toLowerCase().includes(query))
        : String(values[filterColumn] || '').toLowerCase().includes(query);
      return matchesColumn;
    })
    .sort((a, b) => {
      if (!sortKey) return 0;
      const dir = sortDirection === 'asc' ? 1 : -1;
      switch (sortKey) {
        case "date":
          return (new Date(a.job_createddatetime) - new Date(b.job_createddatetime)) * dir;
        case "status":
          return String(a.job_status || "").localeCompare(String(b.job_status || ""), 'af', { sensitivity: 'base' }) * dir;
        case "description":
          return String(a.job_desc || "").localeCompare(String(b.job_desc || ""), 'af', { sensitivity: 'base' }) * dir;
        case "type":
          return String(a.job_type || "").localeCompare(String(b.job_type || ""), 'af', { sensitivity: 'base' }) * dir;
        case "asset_id":
          return (Number(a.asset_id || 0) - Number(b.asset_id || 0)) * dir;
        case "fault_id":
          return (Number(a.fault_id || 0) - Number(b.fault_id || 0)) * dir;
        default:
          return (Number(a.jobcard_id || 0) - Number(b.jobcard_id || 0)) * dir;
      }
    });

  const translateStatus = (status) => {
    return status || "-";
  };

  const getStatusClass = (status) => {
    if (status === "Voltooid") return "status-completed";
    if (status === "Oop") return "status-open";
    if (status === "Wag") return "status-wait";
    if (status === "Geskeduleer") return "status-scheduled";
    return "status-default";
  };

  // Unieke Terrein Opsies opgebou vanaf kamers
  const uniqueTerreine = [...new Set(rooms.map(r => r.terrein).filter(Boolean))];
  const terreinOptions = uniqueTerreine.map(t => ({ value: t, label: t }));

  // Unieke Geboue opsies gebaseer op gekose Terrein
  const gefilterdeGeboue = selectedTerrein 
    ? [...new Set(rooms.filter(r => r.terrein === selectedTerrein.value).map(r => r.gebou).filter(Boolean))]
    : [];
  const gebouOptions = gefilterdeGeboue.map(g => ({ value: g, label: g }));

  // Lokale (Rooms) gefiltreer op basis van gekose Terrein en Gebou
  const gefilterdeRooms = rooms.filter(r => {
    if (selectedTerrein && r.terrein !== selectedTerrein.value) return false;
    if (selectedGebou && r.gebou !== selectedGebou.value) return false;
    return true;
  });
  const roomOptions = gefilterdeRooms.map(r => ({
    value: String(r.room_id),
    label: `${r.room_number || r.room_id} - ${r.room_name || r.room_desc || 'Lokaal'}`
  }));

  // Bates gefiltreer op lokasies indien gekies
  const gefilterdeAssets = assets.filter(a => {
    if (!a.room_id) return !selectedTerrein; // as terrein gekies is maar bate het nie 'n lokaal nie, verberg dit
    const assetRoom = rooms.find(r => String(r.room_id) === String(a.room_id));
    if (!assetRoom) return false;
    if (selectedTerrein && assetRoom.terrein !== selectedTerrein.value) return false;
    if (selectedGebou && assetRoom.gebou !== selectedGebou.value) return false;
    return true;
  });
  const assetOptions = gefilterdeAssets.map(a => ({
    value: String(a.asset_id),
    label: `${a.asset_id} - ${a.asset_name}`
  }));

  // Foutkaartjies dropdown opsies
  const ticketOptions = tickets.map(t => ({
    value: String(t.fault_id),
    label: `${t.fault_id} - ${t.fault_desc || t.fault_title || 'Foutkaartjie'}`
  }));



  if (loading) {
    return <div className="main"><div className="content">Laai...</div></div>;
  }

  return (
    <div className="main">
      <div className="content">
          <div className="controls">
            <div className="controls-left">
              <div className="control-input-shell">
                <input
                  type="text"
                  id="jobSearch"
                  placeholder="Soek op ID of Beskrywing..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              
              <Select
                className="react-select-container"
                classNamePrefix="react-select"
                value={[
                  { value: "all", label: "Alle kolomme" }, { value: "id", label: "ID" },
                  { value: "description", label: "Beskrywing" }, { value: "job_type", label: "Werksoort" },
                  { value: "asset_id", label: "Bate ID" }, { value: "room_id", label: "Lokaal ID" },
                  { value: "building_id", label: "Gebou ID" }, { value: "location_id", label: "Terrein ID" },
                  { value: "fault_id", label: "Fout ID" }, { value: "scheduled", label: "Datum" },
                  { value: "status", label: "Status" },
                ].find((option) => option.value === filterColumn)}
                onChange={(selected) => setFilterColumn(selected?.value || "all")}
                options={[
                  { value: "all", label: "Alle kolomme" }, { value: "id", label: "ID" },
                  { value: "description", label: "Beskrywing" }, { value: "job_type", label: "Werksoort" },
                  { value: "asset_id", label: "Bate ID" }, { value: "room_id", label: "Lokaal ID" },
                  { value: "building_id", label: "Gebou ID" }, { value: "location_id", label: "Terrein ID" },
                  { value: "fault_id", label: "Fout ID" }, { value: "scheduled", label: "Datum" },
                  { value: "status", label: "Status" },
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
                       components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} /> }}
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
                        if (!selectedOption) return;
                        const f = selectedOption._fields;
                        setTerrainFilter(f.location_id); setBuildingFilter(f.building_id); setRoomFilter(f.room_id);
                      }}
                    />
                  </div>
                );
              })()}
            </div>

            <div className="controls-right">
              <ColumnPicker
                ref={colPickerRef}
                columns={colVis.columnDefs}
                visibleColumns={colVis.visibleColumns}
                toggleColumn={colVis.toggleColumn}
                resetVisibility={colVis.resetVisibility}
                onResetWidths={colWidths.resetWidths}
              />
              <button
                type="button"
                className="btn-add"
                id="addJobBtn"
                title="Voeg Nuwe Werksopdrag By"
                onClick={handleNewWorkOrder}
              >
                + Nuwe Werksopdrag
              </button>
              {hasRight('jobs.manage') && (
                <button
                  type="button"
                  className="btn-add"
                  style={{ marginLeft: '0.5rem' }}
                  onClick={() => setShowImportWizard(true)}
                >
                  ⇅ Invoer / Uitvoer rekords
                </button>
              )}
              {hasRight('jobs.manage') && (
                <ImportExportModal
                  isOpen={showImportWizard}
                  onClose={() => setShowImportWizard(false)}
                  defaultEntity="job"
                  onImported={fetchWorkOrders}
                />
              )}
            </div>
          </div>

          {/* Tabel van Werksopdragte */}
          <table className="standard-table">
            <thead>
              <tr>
                {colVis.visibleColumns.map((col) => (
                  <ResizableTh
                    key={col.key}
                    col={col}
                    colWidths={colWidths}
                    className={col.sortKey ? getSortClass(col.sortKey) : ''}
                    onClick={col.sortKey ? () => handleSort(col.sortKey) : undefined}
                    onContextMenu={(e) => { e.preventDefault(); colPickerRef.current?.openAt(e); }}
                  >
                    {col.label}{col.sortKey ? getSortIndicator(col.sortKey) : ''}
                  </ResizableTh>
                ))}
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredWorkOrders.length === 0 ? (
                <tr>
                  <td colSpan={colVis.visibleColumns.length + 1} style={{ textAlign: "center", padding: "20px" }}>Geen werksopdragte gevind</td>
                </tr>
              ) : (
                filteredWorkOrders.map((order) => (
                  <tr key={order.jobcard_id} onClick={() => handleEditWorkOrder(order)} style={{ cursor: "pointer" }}>
                    {colVis.visibleColumns.map((col) => (
                      <td key={col.key}>{col.render(order)}</td>
                    ))}
                    <td onClick={e => e.stopPropagation()}>
                      <button 
                        type="button"
                        className="btn-delete"
                        onClick={() => handleDeleteWorkOrder(order.jobcard_id)}
                        title="Verwyder werksopdrag"
                      >
                        Verwyder
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
{/* MODAL: Werksopdrag-Kaart */}
      {showModal && (
        <div className="modal">
          <div className="modal-content-workorder" style={{ position: "relative" }} onClick={(e) => e.stopPropagation()}>
            {/* Header */}
            <div className="modal-header">
                <h3>Werksopdrag Kaart</h3>
                {isEditing && (
                  <div className="mri-job-no">
                    <input 
                      type="text" 
                      className="inp-bold-large"
                      value={editingId}
                      readOnly
                    />
                  </div>
                )}
                <span className="close no-print" onClick={handleCloseModal}>&times;</span>
            </div>

            {/* Tab Navbar */}
            <div style={{ display: "flex", flexWrap: "wrap", gap: "2px", marginBottom: "12px", borderBottom: "2px solid #dee2e6" }}>
              {[
                { key: "besonderhede", label: "Besonderhede" },
                { key: "kwotasies", label: "Kwotasies" },
                { key: "skedulering", label: "Skedulering & Toewysing" },
                { key: "kontrakteurWerknotas", label: "Kontrakteur Werknotas" },
              ].map((tab) => (
                <button
                  key={tab.key}
                  type="button"
                  style={{
                    padding: "8px 16px",
                    border: "none",
                    cursor: "pointer",
                    fontWeight: activeTab === tab.key ? "700" : "400",
                    color: activeTab === tab.key ? "#007bff" : "#495057",
                    borderBottom: activeTab === tab.key ? "3px solid #007bff" : "3px solid transparent",
                    background: "none",
                    fontSize: "14px",
                  }}
                  onClick={() => setActiveTab(tab.key)}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            {/* Vorm — slegs vir besonderhede en skedulering tabs */}
            {(activeTab === "besonderhede" || activeTab === "skedulering") && (
            <form className="mri-border-box" onSubmit={(e) => e.preventDefault()}>
              {activeTab === "besonderhede" && (
              <>
                {/* Rye 1-2: Status + Prioriteit / Aard + Werksoort */}
                <div className="mri-row flex">
                  <div className="mri-cell w-50 border-r">
                    <div className="mri-fld"><span>Status *</span>
                      <select
                        ref={el => fieldRefs.current.job_status = el}
                        className={invalidFields.job_status ? "field-invalid" : ""}
                        value={formData.job_status}
                        onChange={(e) => {
                          const newStatus = e.target.value;
                          const applyStatus = () => {
                            setFormData(prev => ({
                              ...prev,
                              job_status: newStatus,
                              completed_date: (newStatus === "Voltooid" || newStatus === "COMPLETED") && !prev.completed_date
                                ? new Date().toISOString().split('T')[0]
                                : prev.completed_date,
                            }));
                            setInvalidFields(p => { const n = {...p}; delete n.job_status; return n; });
                          };
                          if ((newStatus === "Voltooid" || newStatus === "COMPLETED") && formData.job_status !== newStatus) {
                            confirm({
                              message: "Is jy seker jy wil hierdie werksopdrag as voltooi merk?",
                              confirmLabel: "Ja, voltooi",
                              cancelLabel: "Kanselleer"
                            }).then((ok) => { if (ok) applyStatus(); });
                          } else {
                            applyStatus();
                          }
                        }}
                      >
                        <option value="">Kies...</option>
                        <option value="Wag">Wag</option>
                        <option value="Oop">Oop</option>
                        <option value="Besig">Besig</option>
                        <option value="Voltooid">Voltooid</option>
                        <option value="Gekanselleer">Gekanselleer</option>
                      </select>
                    </div>
                  </div>
                  <div className="mri-cell w-50">
                    <div className="mri-fld"><span>Prioriteit *</span>
                      <select
                        ref={el => fieldRefs.current.job_priority = el}
                        className={invalidFields.job_priority ? "field-invalid" : ""}
                        value={formData.job_priority}
                        onChange={(e) => {
                          setFormData({...formData, job_priority: e.target.value});
                          setInvalidFields(p => { const n = {...p}; delete n.job_priority; return n; });
                        }}
                        >
                        <option value="">Kies...</option>
                        <option value="Laag">Laag</option>
                        <option value="Normal">Normal</option>
                        <option value="Hoog">Hoog</option>
                        <option value="Dringend">Dringend</option>
                      </select>
                    </div>
                  </div>
                </div>
                <div className="mri-row flex">
                  <div className="mri-cell w-50 border-r">
                    <div className="mri-fld"><span>Aard *</span>
                      <select
                        ref={el => fieldRefs.current.nature = el}
                        className={invalidFields.nature ? "field-invalid" : ""}
                        value={formData.nature}
                        onChange={(e) => {
                          setFormData({...formData, nature: e.target.value});
                          setInvalidFields(p => { const n = {...p}; delete n.nature; return n; });
                        }}
                      >
                        <option value="">Kies...</option>
                        <option value="Elektries">Elektries</option>
                        <option value="Meganies">Meganies</option>
                        <option value="Siviel">Siviel</option>
                        <option value="Buite">Buite</option>
                        <option value="Algemeen">Algemeen</option>
                      </select>
                    </div>
                  </div>
                  <div className="mri-cell w-50">
                    <div className="mri-fld"><span>Werksoort *</span>
                      <select
                        ref={el => fieldRefs.current.job_type = el}
                        className={invalidFields.job_type ? "field-invalid" : ""}
                        value={formData.job_type}
                        onChange={(e) => {
                          setFormData({...formData, job_type: e.target.value});
                          setInvalidFields(p => { const n = {...p}; delete n.job_type; return n; });
                        }}
                      >
                        <option value="">Kies...</option>
                        <option value="Onderhoud">Onderhoud</option>
                        <option value="Herstel">Herstel</option>
                        <option value="Inspeksie">Inspeksie</option>
                        <option value="Installasie">Installasie</option>
                      </select>
                    </div>
                  </div>
                </div>

                {/* Auto-groeiende beskrywing */}
                <div className="mri-fld" style={{ marginBottom: "24px" }}>
                  <span>Werksopdrag Beskrywing *</span>
                  <textarea
                    ref={el => fieldRefs.current.brief_description = el}
                    className={`mri-txt-area-large${invalidFields.brief_description ? " field-invalid" : ""}`}
                    style={{ minHeight: "42px", maxHeight: "140px", overflow: "auto", resize: "vertical" }}
                    value={formData.brief_description}
                    onChange={(e) => {
                      setFormData({...formData, brief_description: e.target.value});
                      setInvalidFields(p => { const n = {...p}; delete n.brief_description; return n; });
                    }}
                    onInput={(e) => { e.target.style.height = "auto"; e.target.style.height = Math.min(e.target.scrollHeight, 140) + "px"; }}
                    placeholder="Kort beskrywing van werk"
                  />
                </div>

                {/* Ligging & Koppeling + Foutkaartjie —50% elk */}
                {(() => {
                  const cascadeCount = [formData.location_id, formData.building_id, formData.room_id, formData.asset_id].filter(Boolean).length;
                  const clearFromLevel = (levelIndex) => {
                    if (levelIndex <= 0) setFormData(p => ({...p, location_id: "", building_id: "", room_id: "", asset_id: ""}));
                    else if (levelIndex === 1) setFormData(p => ({...p, building_id: "", room_id: "", asset_id: ""}));
                    else if (levelIndex === 2) setFormData(p => ({...p, room_id: "", asset_id: ""}));
                    else if (levelIndex === 3) setFormData(p => ({...p, asset_id: ""}));
                  };
                  const breadcrumbData = [{ level: -1, name: "Terreine" }];
                  if (formData.location_id) breadcrumbData.push({ level: 0, name: terrains?.find(t => Number(t.location_id) === Number(formData.location_id))?.location_name || formData.location_id });
                  if (formData.building_id) breadcrumbData.push({ level: 1, name: buildings?.find(b => Number(b.building_id) === Number(formData.building_id))?.building_name || formData.building_id });
                  if (formData.room_id) breadcrumbData.push({ level: 2, name: rooms?.find(r => Number(r.room_id) === Number(formData.room_id))?.room_name || formData.room_id });
                  if (formData.asset_id) breadcrumbData.push({ level: 3, name: assets?.find(a => Number(a.asset_id) === Number(formData.asset_id))?.asset_name || formData.asset_id });
                  const breadcrumbBaseStyle = {
                    border: "none", cursor: "pointer",
                    margin: "0",
                    color: "#111827", fontSize: "13px",
                    lineHeight: "1", display: "inline-flex", alignItems: "center",
                  };
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
                                ...breadcrumbBaseStyle,
                                fontWeight: isLast ? 700 : 600,
                              }}
                            >{item.name}</button>
                            {showArrow && <span style={{ color: "#9ca3af", lineHeight: "1", display: "inline-flex", alignItems: "center", margin: 0 }}>›</span>}
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
                        <>
                          <span style={{ color: "#ccc", userSelect: "none", display: "inline-flex", alignItems: "center" }}>|</span>
                          <span
                            className="cascade-back-btn"
                            onMouseDown={(e) => { e.stopPropagation(); e.preventDefault(); clearFromLevel(cascadeCount - 1); }}
                            title="Terug na vorige vlak"
                            style={backBtnStyle}
                          >
                            <IoReturnUpBack size={24} />
                          </span>
                        </>
                      )}
                    </components.Control>
                  );
                  return (
                <div className={`mri-row flex${invalidFields.location_id ? " field-invalid" : ""}`}>
                  <div ref={liggingRef} className="mri-cell w-50 border-r" style={{ position: "relative" }}>
                    <div ref={modalCascadeMenu.containerRef} className="mri-fld-select mri-fld">
                      <span className="select-label">Ligging & Koppeling</span>
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
                        menuIsOpen={modalCascadeMenu.menuIsOpen}
                        onMenuOpen={modalCascadeMenu.onMenuOpen}
                        onMenuClose={modalCascadeMenu.onMenuClose}
                        components={{ Control: CascadeControl }}
                        options={allLocationOptions}
                        styles={{
                          control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                          valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                          singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                        }}
                        filterOption={(option, rawInput) => {
                        if (rawInput) {
                          if (cascadeCount === 0)
                            return option.data._cascadeLevel <= 3 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 1)
                            return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 3 && String(option.data._fields.location_id) === String(formData.location_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 2)
                            return option.data._cascadeLevel >= 2 && option.data._cascadeLevel <= 3 && String(option.data._fields.building_id) === String(formData.building_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 3)
                            return option.data._cascadeLevel >= 3 && option.data._cascadeLevel <= 3 && String(option.data._fields.room_id) === String(formData.room_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        }
                        if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                        if (cascadeCount === 1) return option.data._cascadeLevel === 1 && String(option.data._parentId) === String(formData.location_id);
                        if (cascadeCount === 2) return option.data._cascadeLevel === 2 && String(option.data._parentId) === String(formData.building_id);
                        if (cascadeCount === 3) return option.data._cascadeLevel === 3 && String(option.data._parentId) === String(formData.room_id);
                        return false;
                        }}
                        value={null}
                        onChange={(selectedOption) => {
                          if (!selectedOption) return;
                          setFormData((p) => ({...p, ...selectedOption._fields}));
                          const labels = ["Terrein","Gebou","Lokaal","Bate"];
                          const label = labels[selectedOption._cascadeLevel] || "";
                          setCascadeToast(`✓ ${label} suksesvol geselekteer`);
                          setTimeout(() => setCascadeToast(null), 2000);
                        }}
                      />
                    </div>
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
                  <div className="mri-cell w-50">
                    <div className="mri-fld-select mri-fld">
                      <span className="select-label">Foutkaartjie Verwysing</span>
                      {renderBreadcrumb()}
                      <Select
                        className="react-select-container"
                        classNamePrefix="react-select"
                        placeholder="Soek/Kies Foutkaartjie..."
                        isClearable
                        components={{ Control: CascadeControl }}
                        styles={{
                          control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                          valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                          singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                        }}
                        filterOption={(option, rawInput) => {
                          if (!rawInput) return true;
                          return option.label.toLowerCase().includes(rawInput.toLowerCase());
                        }}
                        value={formData.fault_id ? { value: formData.fault_id, label: getTicketOptionLabel((tickets || []).find((ticket) => Number(ticket.fault_id) === Number(formData.fault_id))) } : null}
                            onChange={(selectedOption) => {
                              if (!selectedOption) {
                                setFormData({
                                  ...formData,
                                  fault_id: "",
                                  job_type: "",
                                  job_priority: "Normal",
                                  brief_description: "",
                                  location_id: "",
                                  building_id: "",
                                  room_id: "",
                                  asset_id: ""
                                });
                                return;
                              }
                              const ticket=(tickets||[]).find(t=>Number(t.fault_id)===Number(selectedOption.value));
                              setFormData({
                                ...formData,
                                fault_id: ticket?.fault_id || "",
                                job_type: normalizeWorkTypeValue(ticket?.fault_type) || "",
                                job_priority: normalizePriorityValue(ticket?.fault_priority) || "Normal",
                                brief_description: getTicketDisplayTitle(ticket),
                                location_id: ticket?.location_id || "",
                                building_id: ticket?.building_id || "",
                                room_id: ticket?.room_id || "",
                                asset_id: ticket?.asset_id || "",
                                cc_users: addCcUser(formData.cc_users, ticket?.user_id)
                              });
                            }}
                            options={(tickets || []).filter(ticket=>{
                              if(formData.location_id && Number(ticket.location_id)!==Number(formData.location_id)) return false;
                              if(formData.building_id && Number(ticket.building_id)!==Number(formData.building_id)) return false;
                              if(formData.room_id && Number(ticket.room_id)!==Number(formData.room_id)) return false;
                              if(formData.asset_id && Number(ticket.asset_id)!==Number(formData.asset_id)) return false;
                              return true;
                            }).map((ticket) => ({
                              value: ticket.fault_id,
                              label: getTicketOptionLabel(ticket)
                            }))}
                          />
                    </div>
                  </div>
                </div>
                  );
                })()}
              </>
              )}
              {activeTab === "skedulering" && (
              <>
              <div className="mri-row flex">
                <div className="mri-cell w-50 border-r">
                  <div className="mri-fld">
                    <span>Verantwoordelik</span>
                    <Select
                      className="react-select-container"
                      classNamePrefix="react-select"
                      placeholder="Kies gebruiker..."
                      isClearable
                      styles={{
                        control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                        valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                        singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                      }}
                      value={formData.assigned_to
                        ? { value: formData.assigned_to, label: users.find((u) => Number(u.user_id) === Number(formData.assigned_to))?.user_name + " " + users.find((u) => Number(u.user_id) === Number(formData.assigned_to))?.user_surname || formData.assigned_to }
                        : null}
                      onChange={(selectedOption) => setFormData({ ...formData, assigned_to: selectedOption ? selectedOption.value : null })}
                      // Verantwoordelik: slegs FK (2) en Admin (3). Die huidige
                      // toegewysde gebruiker bly sigbaar selfs as hulle nie FK/Admin is.
                      options={(users || [])
                        .filter((u) => u.role_id === 2 || u.role_id === 3 || Number(u.user_id) === Number(formData.assigned_to))
                        .map((u) => ({
                          value: u.user_id,
                          label: `${u.user_name} ${u.user_surname} (${u.user_email})`
                        }))}
                    />
                  </div>
                </div>
                <div className="mri-cell w-50">
                  <div className="mri-fld">
                    <span>CC (Kennisgewing)</span>
                    <Select
                      className="react-select-container"
                      classNamePrefix="react-select"
                      placeholder="Kies gebruikers om CC..."
                      isMulti
                      styles={{
                        control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                        valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                        singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                      }}
                      value={(formData.cc_users || []).map((id) => {
                        const u = users.find((u) => Number(u.user_id) === Number(id));
                        return u ? { value: u.user_id, label: `${u.user_name} ${u.user_surname} (${u.user_email})` } : null;
                      }).filter(Boolean)}
                      onChange={(selectedOptions) => setFormData({
                        ...formData,
                        cc_users: (selectedOptions || []).map((opt) => opt.value)
                      })}
                      // CC-lys: slegs FK (2) en Admin (3) mag gekies word.
                      // Reeds-gekose gebruikers (bv. die foutkaartjie-skepper,
                      // selfs 'n student) bly sigbaar en word behou.
                      options={(users || [])
                        .filter((u) => u.role_id === 2 || u.role_id === 3 || (formData.cc_users || []).some((id) => Number(id) === Number(u.user_id)))
                        .map((u) => ({
                          value: u.user_id,
                          label: `${u.user_name} ${u.user_surname} (${u.user_email})`
                        }))}
                    />
                  </div>
                </div>
              </div>
              <div className="mri-row flex">
                <div className="mri-cell w-50 border-r">
                  <div className="mri-fld" style={{ position: "relative" }}>
                    <span>Geskeduleerde Datum & Tyd</span>
                    <button
                      type="button"
                      className="btn-add"
                      style={{ width: '100%', textAlign: 'left', padding: '8px 12px', fontSize: '13px', background: formData.job_scheduled_datetime ? '#e5e5e5' : '#fff', color: '#111827', border: '1px solid #ccc', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
                      onClick={() => {
                        const dt = formData.job_scheduled_datetime;
                        const date = dt ? dt.split('T')[0] : new Date().toISOString().split('T')[0];
                        const startTime = dt ? dt.split('T')[1]?.slice(0, 5) || '08:00' : '08:00';
                        const endTime = formData.job_scheduled_end_datetime
                          ? formData.job_scheduled_end_datetime.split('T')[1]?.slice(0, 5) || '09:00'
                          : '09:00';
                        const startParts = startTime.split(':');
                        const endParts = endTime.split(':');
                        setTempSchedule({
                          date,
                          startH: startParts[0] || '08',
                          startTens: startParts[1]?.[0] || '0',
                          startOnes: startParts[1]?.[1] || '0',
                          endH: endParts[0] || '09',
                          endTens: endParts[1]?.[0] || '0',
                          endOnes: endParts[1]?.[1] || '0',
                        });
                        const d = new Date(date);
                        setScheduleViewMonth(d.getMonth());
                        setScheduleViewYear(d.getFullYear());
                        setShowSchedulerPopup(true);
                      }}
                    >
                      <span>
                        {formData.job_scheduled_datetime
                          ? `${new Date(formData.job_scheduled_datetime).toLocaleDateString('af-ZA')} ${formData.job_scheduled_datetime.split('T')[1]?.slice(0, 5) || ''} - ${formData.job_scheduled_end_datetime?.split('T')[1]?.slice(0, 5) || 'geen eindtyd'}`
                          : 'Kies Datum & Tyd...'}
                      </span>
                      <span>📅</span>
                    </button>
                    {formData.job_scheduled_datetime && (
                      <button
                        type="button"
                        className="input-clear-btn"
                        onClick={() => setFormData({...formData, job_scheduled_datetime: "", job_scheduled_end_datetime: ""})}
                      >×</button>
                    )}
                    {showSchedulerPopup && (
                      <>
                        <div style={{
                          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 99,
                          background: 'transparent',
                        }}
                          onClick={() => {
                            const start = `${tempSchedule.date}T${tempSchedule.startH}:${tempSchedule.startTens}${tempSchedule.startOnes}`;
                            const end = `${tempSchedule.date}T${tempSchedule.endH}:${tempSchedule.endTens}${tempSchedule.endOnes}`;
                            setFormData(p => ({ ...p, job_scheduled_datetime: start, job_scheduled_end_datetime: end }));
                            setShowSchedulerPopup(false);
                          }}
                        />
                        <div style={{
                          position: 'absolute', top: '100%', left: 0, zIndex: 100,
                          background: '#fff', border: '1px solid #d4c4b0', borderRadius: '8px',
                          boxShadow: '0 8px 24px rgba(0,0,0,0.15)', padding: '16px', width: '320px',
                        }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                            <button type="button" onClick={() => {
                              const d = new Date(scheduleViewYear, scheduleViewMonth - 1);
                              setScheduleViewMonth(d.getMonth());
                              setScheduleViewYear(d.getFullYear());
                            }} style={{ border: 'none', background: 'none', cursor: 'pointer', fontSize: '16px' }}>◀</button>
                            <span style={{ fontWeight: 600 }}>
                              {new Date(scheduleViewYear, scheduleViewMonth).toLocaleDateString('af-ZA', { month: 'long', year: 'numeric' })}
                            </span>
                            <button type="button" onClick={() => {
                              const d = new Date(scheduleViewYear, scheduleViewMonth + 1);
                              setScheduleViewMonth(d.getMonth());
                              setScheduleViewYear(d.getFullYear());
                            }} style={{ border: 'none', background: 'none', cursor: 'pointer', fontSize: '16px' }}>▶</button>
                          </div>
                          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '2px', textAlign: 'center', fontSize: '12px', marginBottom: '8px' }}>
                            {['Ma','Di','Wo','Do','Vr','Sa','So'].map(d => <div key={d} style={{ fontWeight: 600, padding: '4px 0' }}>{d}</div>)}
                            {(() => {
                              const first = new Date(scheduleViewYear, scheduleViewMonth, 1);
                              const startDay = (first.getDay() + 6) % 7;
                              const daysInMonth = new Date(scheduleViewYear, scheduleViewMonth + 1, 0).getDate();
                              const cells = [];
                              for (let i = 0; i < startDay; i++) cells.push(<div key={`e${i}`} />);
                              for (let d = 1; d <= daysInMonth; d++) {
                                const dateStr = `${scheduleViewYear}-${String(scheduleViewMonth + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
                                const isSelected = dateStr === tempSchedule.date;
                                cells.push(
                                  <div key={d}
                                    onClick={() => setTempSchedule(p => ({ ...p, date: dateStr }))}
                                    style={{
                                      padding: '4px 0', cursor: 'pointer', borderRadius: '4px',
                                      background: isSelected ? '#935e28' : 'transparent',
                                      color: isSelected ? '#fff' : '#111827',
                                      fontWeight: isSelected ? 700 : 400,
                                    }}
                                  >{d}</div>
                                );
                              }
                              return cells;
                            })()}
                          </div>
                        <div style={{ display: 'flex', gap: '8px', marginBottom: '8px' }}>
                          <div style={{ flex: 1 }}>
                            <label style={{ fontSize: '11px', fontWeight: 600 }}>Begin-tyd</label>
                            <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
                              <select size={3} value={tempSchedule.startH}
                                onChange={e => setTempSchedule(p => ({ ...p, startH: e.target.value }))}
                                style={{ flex: 1, padding: '2px', border: '1px solid #ccc', borderRadius: '4px', textAlign: 'center', fontFamily: 'inherit', background: '#fff' }}>
                                {Array.from({length: 24}, (_, i) => String(i).padStart(2, '0')).map(h =>
                                  <option key={h} value={h}>{h}</option>
                                )}
                              </select>
                              <span style={{ fontWeight: 600, fontSize: '16px' }}>:</span>
                              <select size={3} value={`${tempSchedule.startTens}${tempSchedule.startOnes}`}
                                onChange={e => {
                                  const v = e.target.value;
                                  setTempSchedule(p => ({ ...p, startTens: v[0], startOnes: v[1] }));
                                }}
                                style={{ flex: 2, padding: '2px', border: '1px solid #ccc', borderRadius: '4px', textAlign: 'center', fontFamily: 'inherit', background: '#fff' }}>
                                {Array.from({length: 60}, (_, i) => String(i).padStart(2, '0')).map(m =>
                                  <option key={m} value={m}>{m}</option>
                                )}
                              </select>
                            </div>
                          </div>
                          <div style={{ flex: 1 }}>
                            <label style={{ fontSize: '11px', fontWeight: 600 }}>Eind-tyd</label>
                            <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
                              <select size={3} value={tempSchedule.endH}
                                onChange={e => setTempSchedule(p => ({ ...p, endH: e.target.value }))}
                                style={{ flex: 1, padding: '2px', border: '1px solid #ccc', borderRadius: '4px', textAlign: 'center', fontFamily: 'inherit', background: '#fff' }}>
                                {Array.from({length: 24}, (_, i) => String(i).padStart(2, '0')).map(h =>
                                  <option key={h} value={h}>{h}</option>
                                )}
                              </select>
                              <span style={{ fontWeight: 600, fontSize: '16px' }}>:</span>
                              <select size={3} value={`${tempSchedule.endTens}${tempSchedule.endOnes}`}
                                onChange={e => {
                                  const v = e.target.value;
                                  setTempSchedule(p => ({ ...p, endTens: v[0], endOnes: v[1] }));
                                }}
                                style={{ flex: 2, padding: '2px', border: '1px solid #ccc', borderRadius: '4px', textAlign: 'center', fontFamily: 'inherit', background: '#fff' }}>
                                {Array.from({length: 60}, (_, i) => String(i).padStart(2, '0')).map(m =>
                                  <option key={m} value={m}>{m}</option>
                                )}
                              </select>
                            </div>
                          </div>
                        </div>
                          <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                            <button type="button" className="btn-cancel" onClick={() => setShowSchedulerPopup(false)}
                              style={{ padding: '6px 16px', borderRadius: '4px', border: '1px solid #ccc', background: '#f5f5f5', cursor: 'pointer' }}>
                              Kanselleer
                            </button>
                          </div>
                        </div>
                      </>
                    )}
                  </div>
                </div>
                <div className="mri-cell w-50">
                  <div className="mri-fld"><span>Herhaling</span> 
                    <select 
                      value={formData.job_schedule_type}
                      onChange={(e) => setFormData({...formData, job_schedule_type: e.target.value})}
                    >
                      <option value="enkel">Enkel</option>
                      <option value="weekliks">Weekliks</option>
                      <option value="maandeliks">Maandeliks</option>
                      <option value="jaarliks">Jaarliks</option>
                    </select>
                  </div>
                </div>
              </div>
              </>
              )}
            </form>
            )}

            {activeTab === "kontrakteurWerknotas" && (
              <>
              <div className="mri-border-box">
                <div className="mri-fld">
                  <span>Beelde</span>
                  <input type="file" accept="image/*" multiple onChange={handleImageFilesChange} />
                  <div className="image-preview-grid" style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', marginTop: '0.5rem' }}>
                    {ticketImages.length > 0 && (
                      <div style={{ width: '100%' }}>
                        <p style={{ margin: '0.5rem 0 0.35rem', fontSize: '0.9rem', fontWeight: 600, color: '#6b3f1d' }}>Foutkaartjie Beelde (alleen-lees)</p>
                        <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                          {ticketImages.map((image) => (
                            <div key={image.image_id} className="record-image-card" style={{ textAlign: 'center', opacity: 0.8 }}>
                              <img
                                src={getJobImageUrl(image.image_id)}
                                alt={image.filename || "Foutkaartjie-beeld"}
                                className="record-image-thumb"
                                style={{ width: '100px', height: '100px', objectFit: 'cover', borderRadius: '4px', cursor: 'zoom-in' }}
                                onClick={() => setActiveImageViewer(getJobImageUrl(image.image_id))}
                              />
                              <div style={{ fontSize: '0.7rem', color: '#888', marginTop: '0.15rem' }}>Foutkaartjie</div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                    {jobImages.map((image) => (
                      <div key={image.image_id} className="record-image-card" style={{ textAlign: 'center' }}>
                        <img
                          src={getJobImageUrl(image.image_id)}
                          alt={image.filename || "Werksopdrag-beeld"}
                          className="record-image-thumb"
                          style={{ width: '100px', height: '100px', objectFit: 'cover', borderRadius: '4px', cursor: 'zoom-in' }}
                          onClick={() => setActiveImageViewer(getJobImageUrl(image.image_id))}
                        />
                        <button type="button" className="btn-delete" style={{ fontSize: '0.75rem', padding: '2px 6px', marginTop: '0.25rem' }} onClick={() => handleDeleteExistingImage(image.image_id)}>Verwyder</button>
                      </div>
                    ))}
                    {selectedImagePreviewUrls.map((url, index) => (
                      <div key={`${url}-${index}`} className="record-image-card" style={{ textAlign: 'center' }}>
                        <img
                          src={url}
                          alt={`Voorgestelde beeld ${index + 1}`}
                          className="record-image-thumb"
                          style={{ width: '100px', height: '100px', objectFit: 'cover', borderRadius: '4px', cursor: 'zoom-in' }}
                          onClick={() => setActiveImageViewer(url)}
                        />
                        <button type="button" className="btn-delete" style={{ fontSize: '0.75rem', padding: '2px 6px', marginTop: '0.25rem' }} onClick={() => handleRemoveSelectedPreview(index)}>Verwyder</button>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
              <div className="mri-border-box">
                <div className="mri-fld">
                  <span>Kontrakteur Werknotas</span>
                  <textarea 
                    className="mri-txt-area-large"
                    style={{ minHeight: "42px", maxHeight: "140px", overflow: "auto", resize: "vertical" }}
                    value={formData.job_notes}
                    onChange={(e) => setFormData({...formData, job_notes: e.target.value})}
                    onInput={(e) => { e.target.style.height = "auto"; e.target.style.height = Math.min(e.target.scrollHeight, 140) + "px"; }}
                    placeholder="Gedetailleerde beskrywing van werk wat gedoen moet word..."
                  />
                </div>
              </div>
              </>
            )}

            {activeTab === "kwotasies" && (
              <div className="mri-border-box">
              <div className="quote-form">
                <h4 className="quote-form-title">Voeg Nuwe Kwotasie By</h4>
                <div className="mri-row">
                  <div className="mri-cell w-50">
                    <div className="mri-fld">
                      <span>Kontrakteur</span>
                      <select
                        value={newQuote.contractor_id}
                        onChange={(e) => setNewQuote({...newQuote, contractor_id: e.target.value})}
                        className="quote-input"
                      >
                        <option value="">Kies Kontrakteur</option>
                        {users.filter(u => u.role_id === 4).map((user) => (
                          <option key={user.user_id} value={user.user_id}>
                            {user.user_name} {user.user_surname}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="mri-fld">
                      <span>PDF Kwotasie</span>
                      <input
                        type="file"
                        accept="application/pdf"
                        onChange={(e) => handleQuotePdfSelect(quoteEditId || "new", e)}
                        className="quote-input"
                      />
                      {(quotePdfFiles[quoteEditId || "new"] || quoteDocuments[quoteEditId]?.[0]) && (
                        <div style={{ fontSize: '0.8rem', marginTop: '0.25rem' }}>
                          {quotePdfFiles[quoteEditId || "new"] ? (
                            <>
                              <span style={{ color: '#16a34a' }}>✓ {quotePdfFiles[quoteEditId || "new"].name}</span>
                              {quotePdfPreviewUrls[quoteEditId || "new"] && (
                                <button type="button" className="btn-view" onClick={() => window.open(quotePdfPreviewUrls[quoteEditId || "new"], '_blank')} style={{ marginLeft: '0.5rem' }}>Bekyk</button>
                              )}
                              <button type="button" className="btn-delete" onClick={() => handleQuotePdfDelete(quoteEditId || "new")} style={{ marginLeft: '0.5rem' }}>Verwyder</button>
                            </>
                          ) : quoteDocuments[quoteEditId]?.[0] && (
                            <>
                              <span style={{ color: '#666' }}>{quoteDocuments[quoteEditId][0].filename}</span>
                              <button type="button" className="btn-view" onClick={() => viewQuotePdf(quoteDocuments[quoteEditId][0].document_id)} style={{ marginLeft: '0.5rem' }}>Bekyk</button>
                              <button type="button" className="btn-delete" onClick={() => handleQuotePdfDelete(quoteEditId)} style={{ marginLeft: '0.5rem' }}>Verwyder</button>
                            </>
                          )}
                        </div>
                      )}
                    </div>
                    <button 
                      type="button"
                      onClick={handleAddQuote}
                      className="btn-add"
                    >
                      {quoteEditId ? 'Stoor Wysiging' : 'Voeg By'}
                    </button>
                    {quoteEditId && (
                      <button
                        type="button"
                        className="btn-add"
                        style={{ marginLeft: 8, background: '#6c757d' }}
                        onClick={handleCancelQuoteEdit}
                      >
                        Kanselleer Wysiging
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* Kwotasies Tabel */}
              {quotes.length > 0 && (
                <div className="quote-table-wrap">
                  <table className="standard-table">
                    <thead>
                      <tr>
                        <th>Kontrakteur</th>
                        <th>PDF</th>
                        <th>Datum</th>
                        <th>Gekies</th>
                        <th>Aksie</th>
                      </tr>
                    </thead>
                    <tbody>
                      {quotes.map((quote) => (
                        <tr key={quote.id} className={selectedQuoteId === quote.id ? "selected" : ""}>
                          <td>{quote.contractor_name || "-"}</td>
                          <td style={{ textAlign: 'center', whiteSpace: 'nowrap' }}>
                            {quoteDocuments[quote.id]?.[0] ? (
                              <>
                                <button type="button" className="btn-view" onClick={() => viewQuotePdf(quoteDocuments[quote.id][0].document_id)}>Bekyk</button>
                                <button type="button" className="btn-delete" onClick={() => handleQuotePdfDelete(quote.id)}>Verwyder</button>
                              </>
                            ) : quotePdfFiles[quote.id] ? (
                              <>
                                <span style={{ fontSize: '0.8rem', color: '#16a34a', marginRight: '0.5rem' }}>{quotePdfFiles[quote.id].name}</span>
                                {quotePdfPreviewUrls[quote.id] && (
                                  <button type="button" className="btn-view" onClick={() => window.open(quotePdfPreviewUrls[quote.id], '_blank')}>Bekyk</button>
                                )}
                                <button type="button" className="btn-delete" onClick={() => handleQuotePdfDelete(quote.id)}>Verwyder</button>
                              </>
                            ) : (
                              <span style={{ color: '#999', fontSize: '0.8rem' }}>-</span>
                            )}
                          </td>
                          <td>{quote.createdAt}</td>
                          <td>
                            <input 
                              type="radio" 
                              className="selectedQuote"
                              checked={selectedQuoteId === quote.id}
                              onChange={() => handleSelectQuote(quote.id)}
                            />
                          </td>
                          <td>
                            <button 
                              type="button"
                              onClick={() => handleStartEditQuote(quote.id)}
                              className="btn-edit"
                            >
                              Wysig
                            </button>
                            <button 
                              type="button"
                              onClick={() => handleDeleteQuote(quote.id)}
                              className="btn-delete"
                            >
                              Verwyder
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {selectedQuoteId && (
                    <div className="quote-summary">
                      <div>✓ Gekose Kwotasie: {quotes.find(q => q.id === selectedQuoteId)?.contractor_name || 'Geen kontrakteur'}</div>
                      <textarea
                        className="quote-reason-textarea"
                        placeholder="Gee 'n rede waarom hierdie kwotasie gekies is"
                        value={quoteSelectionReasons[selectedQuoteId] || ""}
                        onChange={(e) => setQuoteSelectionReasons((prev) => ({ ...prev, [selectedQuoteId]: e.target.value }))}
                      />
                    </div>
                  )}
                </div>
              )}
              {quotes.length === 0 && (
                <div className="quote-empty">
                  Geen kwotasies bygevoeg nie
                </div>
              )}
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

            {/* Knoppies */}
            <div className="modal-footer no-print">
              <button type="button" className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button type="button" className="btn-view" onClick={() => window.print()}>Druk Werksopdrag</button>
              <button type="button" className="btn-add" onClick={handleSaveWorkOrder} disabled={isSubmitting}>
                {isSubmitting ? 'Besig om te stoor...' : 'Stoor Kaart'}
              </button>
            </div>
            <AiSuggestPanel
              suggestions={jobSuggestions}
              loading={aiLoading}
              filled={aiFilled}
              error={aiError}
              labels={{ job_type: 'Werksoort', job_priority: 'Prioriteit' }}
              onUse={(key, s) => {
                if (key === 'job_type') {
                  const af = JOB_TYPE_EN_AF[s.value] || s.value;
                  setFormData(p => ({ ...p, job_type: af }));
                  setInvalidFields(p => { const n = { ...p }; delete n.job_type; return n; });
                } else if (key === 'job_priority') {
                  const af = JOB_PRIO_EN_AF[s.value] || s.value;
                  setFormData(p => ({ ...p, job_priority: af }));
                  setInvalidFields(p => { const n = { ...p }; delete n.job_priority; return n; });
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

export default WorkOrderPage;