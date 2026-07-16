import React, { useState, useEffect, useRef } from "react";
import { Link, useSearchParams, useLocation } from "react-router-dom";
import { useMsal } from '@azure/msal-react';
import Select, { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";
import { assetsAPI, workOrdersAPI, contractorsAPI, quotesAPI, roomsAPI, ticketsAPI, buildingsAPI, locationAPI, usersAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';
import { loginRequest } from '../services/msalConfig';
import UserProfileHeader from '../components/UserProfileHeader';
import { normalizeWorkOrdersPayload } from './workOrderUtils';
import '../styles/App.css';
import "../styles/WorkOrder.css";

function WorkOrderPage() {
  // Haal admin-status vir beheer-opsies
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();
  const { instance } = useMsal();
  const location = useLocation();
  
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
  const [sortBy, setSortBy] = useState("id");              // Sorteer op veld
  const [sortDirection, setSortDirection] = useState("asc");
  
  // Modal en redigerings-state
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [pendingJobcardId, setPendingJobcardId] = useState(null);
  const [users, setUsers] = useState([]);
  const [quotes, setQuotes] = useState([]);
  const [selectedQuoteId, setSelectedQuoteId] = useState(null);
  const [contractors, setContractors] = useState([]);
  const [newQuote, setNewQuote] = useState({ contractor_id: "", amount: "", description: "" });
  const [quoteEditId, setQuoteEditId] = useState(null);
  const [quoteSelectionReasons, setQuoteSelectionReasons] = useState({});
  const [connectionType, setConnectionType] = useState("");
  const [connectionTargetId, setConnectionTargetId] = useState("");

  const [activeTab, setActiveTab] = useState("besonderhede");
  const [cascadeToast, setCascadeToast] = useState(null);
  const liggingRef = useRef(null);

  // Nuwe state spesifiek vir Terrein en Gebou interaktiewe dropdowns binne die modal
  const [selectedTerrein, setSelectedTerrein] = useState(null);
  const [selectedGebou, setSelectedGebou] = useState(null);
  
  // Vorm-data vir werksopdrag (uitgebreide velde)
  const [formData, setFormData] = useState({
    // Hoofinligting
    job_desc: "",                   // Hoofbeskrywing
    job_type: "",                   // Werksoort (maintenance, repair, inspection, installation, emergency)
    job_status: "Oop",              // Status (Oop, Wag, Voltooid)
    job_priority: "Normal",         // Prioriteit
    job_createddatetime: "",        // Skeppingsdatum
    job_scheduled_datetime: "",     // Geskeduleerde datum
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

  const [searchParams, setSearchParams] = useSearchParams();

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
      nature: ticket.fault_type || "",
      asset_id: ticket.asset_id ? String(ticket.asset_id) : "",
      room_id: detectedRoomId ? String(detectedRoomId) : "",
      building_id: detectedBuildingId ? String(detectedBuildingId) : "",
      location_id: detectedSiteId ? String(detectedSiteId) : "",
      fault_id: ticket.fault_id ? String(ticket.fault_id) : "",
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
    fetchContractors();
    fetchUsers();
  }, []);

  useEffect(() => {
    if (location.state?.ticket) {
      setShowModal(true);
      setIsEditing(false);
      setEditingId(null);
      applyTicketSelectionToForm(location.state.ticket);
    }
  }, [location.state?.ticket, assets, rooms, buildings, terrains]);

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

  const fetchContractors = async () => {
    try {
      const response = await contractorsAPI.getAll();
      const contractorList = response.data || [];
      setContractors(contractorList);
      return contractorList;
    } catch (error) {
      console.error("Fout by haal kontrakteurs:", error);
      return [];
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
      job_notes: details,
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
        const contractorList = contractors.length > 0 ? contractors : await fetchContractors();
        const quoteResponses = await Promise.allSettled(quoteIds.map((id) => quotesAPI.getById(id)));
        const loadedQuotes = quoteResponses
          .filter((result) => result.status === "fulfilled" && result.value)
          .map((result) => {
            const response = result.value;
            const quoteData = response.data || response;
            const contractor = contractorList.find((item) => item.contractor_id === Number(quoteData.contractor_id));
            return {
              id: quoteData.quote_id,
              contractor_id: quoteData.contractor_id ? Number(quoteData.contractor_id) : "",
              contractor_name: contractor?.contractor_name || "",
              amount: Number(quoteData.quote_price || 0),
              description: quoteData.quote_desc || "",
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

    setShowModal(true);
  }

  // Hanteer besparing van werksopdrag
  const handleSaveWorkOrder = async () => {
    try {
      if (!formData.job_desc && !formData.brief_description) {
        alert("Voer asseblief 'n beskrywing in.");
        return;
      }

      const payload = {
        job_desc: `${formData.brief_description}${formData.job_notes ? `: ${formData.job_notes}` : ''}`,
        job_type: formData.job_type || null,
        job_status: formData.job_status,
        job_priority: formData.job_priority || "Normal",
        nature: formData.nature || null,
        job_createddatetime: formatDateTimeForPayload(formData.job_createddatetime) || new Date().toISOString(),
        job_scheduled_datetime: formatDateTimeForPayload(formData.job_scheduled_datetime) || formatDateTimeForPayload(formData.job_createddatetime) || new Date().toISOString(),
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

      const savedWorkOrderResponse = isEditing
        ? await workOrdersAPI.update(editingId, payload)
        : await workOrdersAPI.create(payload);
      const savedWorkOrder = savedWorkOrderResponse?.data || savedWorkOrderResponse;
      const workOrderId = savedWorkOrder?.jobcard_id || editingId;

      if (quotes.some((quote) => !quote.contractor_id || !String(quote.description || "").trim())) {
        alert("Elke kwotasie moet 'n kontrakteur en 'n beskrywing hê.");
        return;
      }

      if (selectedQuoteId && !String(quoteSelectionReasons[selectedQuoteId] || "").trim()) {
        alert("Gee asseblief 'n rede waarom die gekose kwotasie gekies is.");
        return;
      }

      const createdQuoteIds = [];
      let selectedCreatedQuoteId = null;

      for (const quote of quotes) {
        const quotePayload = {
          quote_price: Number(quote.amount),
          quote_desc: quote.description || "Kwotasie",
          quote_date: new Date().toISOString().split('T')[0],
          quote_status: "Pending",
          quote_selection_reason: quoteSelectionReasons[quote.id] || null,
          contractor_id: quote.contractor_id ? Number(quote.contractor_id) : null,
        };

        const quoteResponse = await quotesAPI.create(quotePayload);
        const createdQuote = quoteResponse?.data || quoteResponse;
        const createdQuoteId = createdQuote?.quote_id ?? null;
        createdQuoteIds.push(createdQuoteId);

        if (selectedQuoteId && String(quote.id) === String(selectedQuoteId)) {
          selectedCreatedQuoteId = createdQuoteId;
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
      }
      
      handleCloseModal();
      fetchWorkOrders();
    } catch (error) {
      console.error("Fout by besparing:", error);
      alert("Fout tydens besparing. Probeer asseblief weer.");
    }
  };

  // ===== QUOTES FUNKSIES =====
  const handleAddQuote = () => {
    if (!newQuote.contractor_id || !newQuote.amount || !String(newQuote.description || "").trim()) {
      alert("Kies 'n kontrakteur, voer 'n bedrag in en gee 'n beskrywing vir die kwotasie.");
      return;
    }

    const contractor = contractors.find(c => c.contractor_id === Number(newQuote.contractor_id));
    const updatedQuote = {
      id: quoteEditId || Date.now(),
      contractor_id: newQuote.contractor_id ? Number(newQuote.contractor_id) : null,
      contractor_name: contractor ? contractor.contractor_name : "",
      amount: parseFloat(newQuote.amount),
      description: newQuote.description,
      createdAt: quoteEditId ? quotes.find((q) => q.id === quoteEditId)?.createdAt || new Date().toLocaleDateString('af-ZA') : new Date().toLocaleDateString('af-ZA'),
      selection_reason: quoteSelectionReasons[quoteEditId] || ""
    };

    if (quoteEditId) {
      setQuotes(quotes.map((quote) => (quote.id === quoteEditId ? updatedQuote : quote)));
      setQuoteEditId(null);
    } else {
      setQuotes([...quotes, updatedQuote]);
    }

    setNewQuote({ contractor_id: "", amount: "", description: "" });
  };

  const handleStartEditQuote = (quoteId) => {
    const quoteToEdit = quotes.find((quote) => quote.id === quoteId);
    if (!quoteToEdit) return;

    setNewQuote({
      contractor_id: quoteToEdit.contractor_id ? String(quoteToEdit.contractor_id) : "",
      amount: quoteToEdit.amount ? String(quoteToEdit.amount) : "",
      description: quoteToEdit.description || ""
    });
    setQuoteEditId(quoteId);
  };

  const handleCancelQuoteEdit = () => {
    setQuoteEditId(null);
    setNewQuote({ contractor_id: "", amount: "", description: "" });
  };

  const handleDeleteQuote = (quoteId) => {
    setQuotes(quotes.filter(q => q.id !== quoteId));
    setQuoteSelectionReasons((prev) => {
      const next = { ...prev };
      delete next[quoteId];
      return next;
    });
    if (selectedQuoteId === quoteId) {
      setSelectedQuoteId(null);
    }
    if (quoteEditId === quoteId) {
      setQuoteEditId(null);
      setNewQuote({ contractor_id: "", amount: "", description: "" });
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
    setQuotes([]);
    setSelectedQuoteId(null);
    setQuoteEditId(null);
    setQuoteSelectionReasons({});
    setNewQuote({ contractor_id: "", amount: "", description: "" });
    setConnectionType("");
    setConnectionTargetId("");
    setSelectedTerrein(null);
    setSelectedGebou(null);
    setFormData({
      job_desc: "",
      job_type: "",
      job_status: "Oop",
      job_priority: "Normal",
      job_createddatetime: "",
      job_scheduled_datetime: "",
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
    setFormData({
      job_desc: "",
      job_type: "",
      job_status: "Oop",
      job_priority: "Normal",
      job_createddatetime: new Date().toISOString().split('T')[0],
      job_scheduled_datetime: new Date().toISOString().slice(0, 16),
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
    if (!window.confirm("Is jy seker jy wil hierdie werksopdrag verwyder?")) {
      return;
    }
    try {
      await workOrdersAPI.delete(workOrderId);
      await deleteScheduledOutlookEventsForWorkOrder(workOrderId);
      fetchWorkOrders();
    } catch (error) {
      console.error("Fout by verwydering:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  // Filter en sorteer werksopdragte vir tabel
  const filteredWorkOrders = [...workOrders]
    .filter((order) => {
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
      switch (sortBy) {
        case "date":
          return new Date(b.job_createddatetime) - new Date(a.job_createddatetime);
        case "status":
          return (a.job_status || "").localeCompare(b.job_status || "");
        default:
          return (a.jobcard_id || 0) - (b.jobcard_id || 0);
      }
    });

  const translateStatus = (status) => {
    return status || "-";
  };

  const getStatusClass = (status) => {
    if (status === "Voltooid") return "status-completed";
    if (status === "Oop") return "status-open";
    if (status === "Wag") return "status-wait";
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
    return <div className="page-layout" style={{ display: "flex" }}><div className="main"><div className="content">Laai...</div></div></div>;
  }

  return (
    <div className="page-layout" style={{ display: "flex" }}>
      <Sidebar currentPath="/work-orders" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Bestuur Werksopdragte</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          {/* Beheer-reeks */}
          <div className="controls">
            <div className="controls-left">
              <input 
                type="text" 
                className="search-box"
                id="jobSearch" 
                placeholder="Soek op ID of Beskrywing..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              
              <select value={filterColumn} onChange={(e) => setFilterColumn(e.target.value)}>
                <option value="all">Alle kolomme</option>
                <option value="id">ID</option>
                <option value="description">Beskrywing</option>
                <option value="job_type">Werksoort</option>
                <option value="asset_id">Bate ID</option>
                <option value="room_id">Lokaal ID</option>
                <option value="building_id">Gebou ID</option>
                <option value="location_id">Terrein ID</option>
                <option value="fault_id">Terrein ID</option>
                <option value="scheduled">Datum</option>
                <option value="status">Status</option>
              </select>
            </div>

            <div className="controls-right">
              <select 
                className="sort-select"
                id="jobSort"
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
              >
                <option value="id">ID</option>
                <option value="date">Datum</option>
                <option value="status">Status</option>
              </select>

              <div style={{ display: 'flex', gap: '0.25rem' }}>
                <button type="button" className="btn-add" onClick={() => setSortDirection('asc')} style={{ minWidth: '40px', background: sortDirection === 'asc' ? '#935e28' : undefined }} title="Stygend">▲</button>
                <button type="button" className="btn-add" onClick={() => setSortDirection('desc')} style={{ minWidth: '40px', background: sortDirection === 'desc' ? '#935e28' : undefined }} title="Dalend">▼</button>
              </div>

              <button 
                type="button"
                className="btn-add" 
                id="addJobBtn"
                title="Voeg Nuwe Werksopdrag By"
                onClick={handleNewWorkOrder}
              >
                + Nuwe Werksopdrag
              </button>
            </div>
          </div>

          {/* Tabel van Werksopdragte */}
          <table className="standard-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Beskrywing</th>
                <th>Werksoort</th>
                <th>Bate ID</th>
                <th>Lokaal ID</th>
                <th>Gebou ID</th>
                <th>Terrein ID</th>
                <th>Fault ID</th>
                <th>Datum</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredWorkOrders.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: "center", padding: "20px" }}>Geen werksopdragte gevind</td>
                </tr>
              ) : (
                filteredWorkOrders.map((order) => (
                  <tr key={order.jobcard_id}>
                    <td>{order.jobcard_id}</td>
                    <td className="description-cell">{order.job_desc || "-"}</td>
                    <td>{order.job_type || "-"}</td>
                    <td>{order.asset_id || "-"}</td>
                    <td>{order.room_id || "-"}</td>
                    <td>{order.building_id || "-"}</td>
                    <td>{order.location_id || "-"}</td>
                    <td>{order.fault_id || "-"}</td>
                    <td>{order.job_scheduled_datetime ? new Date(order.job_scheduled_datetime).toLocaleString('af-ZA') : (order.job_createddatetime ? new Date(order.job_createddatetime).toLocaleString('af-ZA') : "-")}</td>
                    <td>
                      <span className={`status-badge ${getStatusClass(order.job_status)}`}>
                        {translateStatus(order.job_status)}
                      </span>
                    </td>
                    <td>
                      <button 
                        type="button"
                        className="btn-edit"
                        onClick={() => handleEditWorkOrder(order)}
                        title="Bekyk en wysig werksopdrag"
                      >
                        Bekyk
                      </button>
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
                    <div className="mri-fld"><span>Status</span>
                      <select
                        value={formData.job_status}
                        onChange={(e) => {
                          const newStatus = e.target.value;
                          setFormData(prev => ({
                            ...prev,
                            job_status: newStatus,
                            completed_date: (newStatus === "Voltooid" || newStatus === "COMPLETED") && !prev.completed_date
                              ? new Date().toISOString().split('T')[0]
                              : prev.completed_date,
                          }));
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
                    <div className="mri-fld"><span>Prioriteit</span>
                      <select value={formData.job_priority} onChange={(e) => setFormData({...formData, job_priority: e.target.value})}>
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
                    <div className="mri-fld"><span>Aard</span>
                      <select
                        value={formData.nature}
                        onChange={(e) => setFormData({...formData, nature: e.target.value})}
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
                    <div className="mri-fld"><span>Werksoort</span>
                      <select
                        value={formData.job_type}
                        onChange={(e) => setFormData({...formData, job_type: e.target.value})}
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
                  <span>Werksopdrag Beskrywing</span>
                  <textarea
                    className="mri-txt-area-large"
                    style={{ minHeight: "42px", maxHeight: "140px", overflow: "auto", resize: "vertical" }}
                    value={formData.brief_description}
                    onChange={(e) => setFormData({...formData, brief_description: e.target.value})}
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
                  const renderBreadcrumb = () => (
                    <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: "4px", fontSize: "13px", color: "#111827", marginTop: "6px", marginBottom: "6px" }}>
                      {breadcrumbData.map((item, i) => {
                        const isLast = i === breadcrumbData.length - 1;
                        const showArrow = isLast ? cascadeCount < 4 : true;
                        return (
                          <React.Fragment key={i}>
                            <button
                              type="button"
                              onClick={() => clearFromLevel(item.level + 1)}
                              style={{
                                background: "none", border: "none", cursor: "pointer", padding: "0", margin: "0",
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
                  const backBtnStyle = { background: "none", border: "none", color: "#111827", cursor: "pointer", display: "flex", alignItems: "center", padding: "0 4px" };
                  const CascadeControl = ({ children, ...props }) => (
                    <components.Control {...props}>
                      {children}
                      {cascadeCount > 0 && (
                        <span
                          className="cascade-back-indicator"
                          onMouseDown={(e) => { e.stopPropagation(); e.preventDefault(); clearFromLevel(cascadeCount - 1); }}
                          title="Vorige vlak"
                          style={backBtnStyle}
                        >
                          <IoReturnUpBack size={18} />
                        </span>
                      )}
                    </components.Control>
                  );
                  return (
                <div className="mri-row flex">
                  <div ref={liggingRef} className="mri-cell w-50 border-r" style={{ position: "relative" }}>
                    <div className="mri-fld-select mri-fld">
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
                        components={{ Control: CascadeControl }}
                        options={(() => {
                          if (cascadeCount === 0)
                            return (terrains || []).map((t) => ({ value: t.location_id, label: `${t.location_id} - ${t.location_name || t.location_desc || "Terrein"}` }));
                          if (cascadeCount === 1)
                            return (buildings || []).filter((b) => Number(b.location_id) === Number(formData.location_id)).map((b) => ({ value: b.building_id, label: `${b.building_id} - ${b.building_name || "Gebou"}` }));
                          if (cascadeCount === 2)
                            return (rooms || []).filter((r) => Number(r.building_id) === Number(formData.building_id)).map((r) => ({ value: r.room_id, label: `${r.room_id} - ${r.room_name || r.room_number || "Lokaal"}` }));
                          if (cascadeCount === 3)
                            return (assets || []).filter((a) => Number(a.room_id) === Number(formData.room_id)).map((a) => ({ value: a.asset_id, label: `${a.asset_id} - ${a.asset_name}` }));
                          return [];
                        })()}
                        value={null}
                        onChange={(selectedOption) => {
                          if (!selectedOption) return;
                          const labels = ["Terrein","Gebou","Lokaal","Bate"];
                          if (cascadeCount === 0)
                            setFormData((p) => ({...p, location_id: selectedOption.value, building_id: "", room_id: "", asset_id: ""}));
                          else if (cascadeCount === 1)
                            setFormData((p) => ({...p, building_id: selectedOption.value, room_id: "", asset_id: ""}));
                          else if (cascadeCount === 2)
                            setFormData((p) => ({...p, room_id: selectedOption.value, asset_id: ""}));
                          else if (cascadeCount === 3)
                            setFormData((p) => ({...p, asset_id: selectedOption.value}));
                          const label = labels[cascadeCount] || "";
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
                                asset_id: ticket?.asset_id || ""
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
                      value={formData.assigned_to
                        ? { value: formData.assigned_to, label: users.find((u) => Number(u.user_id) === Number(formData.assigned_to))?.user_name + " " + users.find((u) => Number(u.user_id) === Number(formData.assigned_to))?.user_surname || formData.assigned_to }
                        : null}
                      onChange={(selectedOption) => setFormData({ ...formData, assigned_to: selectedOption ? selectedOption.value : null })}
                      options={(users || []).map((u) => ({
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
                      value={(formData.cc_users || []).map((id) => {
                        const u = users.find((u) => Number(u.user_id) === Number(id));
                        return u ? { value: u.user_id, label: `${u.user_name} ${u.user_surname} (${u.user_email})` } : null;
                      }).filter(Boolean)}
                      onChange={(selectedOptions) => setFormData({
                        ...formData,
                        cc_users: (selectedOptions || []).map((opt) => opt.value)
                      })}
                      options={(users || []).map((u) => ({
                        value: u.user_id,
                        label: `${u.user_name} ${u.user_surname} (${u.user_email})`
                      }))}
                    />
                  </div>
                </div>
              </div>
              <div className="mri-row flex">
                <div className="mri-cell w-50 border-r">
                  <div className="mri-fld" style={{ position: "relative" }}><span>Geskeduleerde Datum en Tyd</span> 
                    <input 
                      type="datetime-local"
                      value={formData.job_scheduled_datetime}
                      onChange={(e) => setFormData({...formData, job_scheduled_datetime: e.target.value})}
                    />
                    {formData.job_scheduled_datetime && (
                      <button
                        type="button"
                        className="input-clear-btn"
                        onClick={() => setFormData({...formData, job_scheduled_datetime: ""})}
                      >×</button>
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
                        {contractors.map((contractor) => (
                          <option key={contractor.contractor_id} value={contractor.contractor_id}>
                            {contractor.contractor_name}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="mri-fld">
                      <span>Bedrag</span>
                      <input 
                        type="number" 
                        placeholder="Bedrag (R)"
                        value={newQuote.amount}
                        onChange={(e) => setNewQuote({...newQuote, amount: e.target.value})}
                        className="quote-input"
                      />
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
                  
                  <div className="mri-cell w-50">
                    <textarea 
                      placeholder="Beskrywing van Kwotasie"
                      value={newQuote.description}
                      onChange={(e) => setNewQuote({...newQuote, description: e.target.value})}
                      className="quote-textarea"
                    />
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
                        <th>Bedrag</th>
                        <th>Beskrywing</th>
                        <th>Datum</th>
                        <th>Gekies</th>
                        <th>Aksie</th>
                      </tr>
                    </thead>
                    <tbody>
                      {quotes.map((quote) => (
                        <tr key={quote.id} className={selectedQuoteId === quote.id ? "selected" : ""}>
                          <td>{quote.contractor_name || "-"}</td>
                          <td style={{ fontWeight: "700"}}>R {quote.amount.toFixed(2)}</td>
                          <td>{quote.description}</td>
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
                      <div>✓ Gekose Kwotasie: R {quotes.find(q => q.id === selectedQuoteId)?.amount.toFixed(2)} ({quotes.find(q => q.id === selectedQuoteId)?.contractor_name || 'Geen kontrakteur'})</div>
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

            {/* Knoppies */}
            <div className="modal-footer no-print">
              <button type="button" className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button type="button" className="btn-view" onClick={() => window.print()}>Druk Werksopdrag</button>
              <button type="button" className="btn-add" onClick={handleSaveWorkOrder}>Stoor Kaart</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default WorkOrderPage;