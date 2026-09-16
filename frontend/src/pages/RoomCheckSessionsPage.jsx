import React, { useState, useEffect, useRef, useMemo } from "react";
import RawSelect from "react-select";
import Select from "react-select";
import { IoTrashOutline, IoPencil } from "react-icons/io5";
import { MdHistory } from "react-icons/md";
import { renderBreadcrumb, CascadeControl, CascadeIndicatorsContainer, NoCascadeClearIndicator } from "../components/controlHelpers";
import { useSearchParams } from "react-router-dom";
import { roomChecksAPI, roomsAPI, usersAPI, locationAPI, buildingsAPI, assetsAPI, ticketsAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import { useToast } from "../components/Toast/useToast";
import { useConfirmDialog } from "../components/Modal/useConfirmDialog";
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import useColumnWidths from "../hooks/useColumnWidths";
import usePagination from "../hooks/usePagination";
import Pagination from "../components/Pagination/Pagination";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import SortPicker from "../components/ColumnPicker/SortPicker";
import FilterPicker from "../components/ColumnPicker/FilterPicker";
import ResizableTh from "../components/ResizableTh";
import { buildFlatLocationOptions } from "./locationSearchUtils";
import useCascadeMenu from "../hooks/useCascadeMenu";
import useFilterState from "../hooks/useFilterState";
import "../styles/App.css";
import "../styles/Rooms.css";
import "../components/Modal/Modal.css";
import { getDeleteErrorMessage, confirmCascade, batchDelete } from "../utils/deleteUtils";

const idemKey = () => (window.crypto && crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`);

const STATUS_LABELS = {
  scheduled: "Geskeduleer",
  completed: "Voltooi",
  cancelled: "Gekanselleer",
};

function statusBadge(status) {
  const color =
    status === "completed" ? "#2e7d32" :
    status === "cancelled" ? "#9e9e9e" :
    "#ed6c02";
  return (
    <span style={{
      padding: "3px 8px", borderRadius: 12, fontSize: 11,
      fontWeight: 700, color, backgroundColor: color + "22",
    }}>
      {STATUS_LABELS[status] || status}
    </span>
  );
}

function RoomCheckSessionsPage() {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { user, rights } = useCurrentUser();
  const canManage = (rights || []).includes("room_checks.manage");

  const [searchParams, setSearchParams] = useSearchParams();

  const [sessions, setSessions] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [assignableUsers, setAssignableUsers] = useState([]);
  const [assets, setAssets] = useState([]);
  const [loading, setLoading] = useState(true);

  const filterPersist = useFilterState({ storageKey: "sessions-page" });
  const [searchTerm, setSearchTerm] = useState(() => filterPersist.value.search);
  const [filterColumn, setFilterColumn] = useState("all");
  const [statusFilter, setStatusFilter] = useState(() => filterPersist.value.status || "");

  const SESSION_COLUMNS = [
    { key: "room", label: "Lokaal", render: (s) => s.room_name || `Lokaal #${s.room_id}`, sortKey: "room", defaultVisible: true },
    { key: "user", label: "Toegewys aan", render: (s) => s.assigned_user_name || `Gebruiker #${s.assigned_user_id}`, sortKey: "user", defaultVisible: true },
    { key: "datetime", label: "Datum en tyd", render: (s) => formatDate(s.scheduled_datetime || s.completed_datetime), sortKey: "datetime", defaultVisible: true },
    { key: "status", label: "Status", render: (s) => {
      const early = completedEarlyTimes(s);
      return (
        <span style={{ display: "inline-flex", alignItems: "center", gap: 6, flexWrap: "wrap" }}>
          {statusBadge(s.status)}
          {early && (
            <span
              title={`Geskeduleer: ${formatDate(early.scheduled.toISOString())} • Voltooi: ${formatDate(early.completed.toISOString())}`}
              style={{ padding: "3px 8px", borderRadius: 12, fontSize: 11, fontWeight: 700, color: "#b45309", backgroundColor: "#b4530922" }}
            >
              Vroeër voltooi
            </span>
          )}
        </span>
      );
    }, sortKey: "status", defaultVisible: true },
    { key: "id", label: "ID", render: (s) => s.session_id, sortKey: "id", defaultVisible: false },
  ];
  const { sorts, addSort, removeSort, toggleDirection, moveSort, clearSorts, applySort } = useColumnSort({
    columns: SESSION_COLUMNS,
    storageKey: "sessions-page",
    defaultSorts: [{ key: "datetime", direction: "desc" }],
  });
  const colVis = useColumnVisibility("sessions-page", SESSION_COLUMNS);
  const colWidths = useColumnWidths("sessions-page", SESSION_COLUMNS);
  const colPickerRef = useRef(null);

  const [terrainFilter, setTerrainFilter] = useState(() => filterPersist.value.location_id);
  const [buildingFilter, setBuildingFilter] = useState(() => filterPersist.value.building_id);
  const [roomFilter, setRoomFilter] = useState(() => filterPersist.value.room_id);
  const [cascadeToast, setCascadeToast] = useState(null);
  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, rooms, []), [terrains, buildings, rooms]);
  const formCascade = useCascadeMenu();

  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [formLocationId, setFormLocationId] = useState("");
  const [formBuildingId, setFormBuildingId] = useState("");
  const [formRoomId, setFormRoomId] = useState(null);
  const [formUserId, setFormUserId] = useState(null);
  const [formDateTime, setFormDateTime] = useState("");
  const [saving, setSaving] = useState(false);
  const [isViewMode, setIsViewMode] = useState(false);

  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [historySession, setHistorySession] = useState(null);
  const [historyChecks, setHistoryChecks] = useState([]);
  const [loadingHistory, setLoadingHistory] = useState(false);

  const [showCheckModal, setShowCheckModal] = useState(false);
  const [checkStage, setCheckStage] = useState("pick");
  const [checkRoom, setCheckRoom] = useState(null);
  const [checkItems, setCheckItems] = useState([]);
  const [checkSaving, setCheckSaving] = useState(false);
  const [faultFormFor, setFaultFormFor] = useState(null);
  const [faultDesc, setFaultDesc] = useState("");
  const [faultType, setFaultType] = useState("");
  const [faultPriority, setFaultPriority] = useState("Medium");
  const checkCascade = useCascadeMenu();
  const [checkLocationId, setCheckLocationId] = useState("");
  const [checkBuildingId, setCheckBuildingId] = useState("");
  const [checkRoomId, setCheckRoomId] = useState(null);

  useEffect(() => {
    const init = async () => {
      try {
        const [sessionsRes, roomsRes, usersRes, terrainsRes, buildingsRes, assetsRes] = await Promise.all([
          roomChecksAPI.sessions.getAll({}),
          roomsAPI.getAll(),
          usersAPI.getAssignable(),
          locationAPI.getAll(),
          buildingsAPI.getAll(),
          assetsAPI.getAll(),
        ]);
        setSessions(sessionsRes.data || []);
        setRooms(roomsRes.data || []);
        setAssignableUsers(usersRes.data || []);
        setTerrains(terrainsRes.data || []);
        setBuildings(buildingsRes.data || []);
        setAssets(assetsRes.data || []);
      } catch (err) {
        console.error("Fout met inisialisering:", err);
        showToast({ type: "error", title: "Fout", message: "Kon nie data laai nie." });
      } finally {
        setLoading(false);
      }
    };
    init();
  }, []);

  useEffect(() => {
    if (loading) return;
    const id = setInterval(() => fetchSessions(), 30000);
    const onFocus = () => fetchSessions();
    window.addEventListener("focus", onFocus);
    return () => {
      clearInterval(id);
      window.removeEventListener("focus", onFocus);
    };
  }, [loading]);

  useEffect(() => {
    if (!loading && searchParams.get("scheduleRoom")) {
      const targetRoomId = searchParams.get("scheduleRoom");
      openCreate();
      preselectRoom(Number(targetRoomId));
      setSearchParams({}, { replace: true });
    }
  }, [loading, searchParams, rooms, buildings, terrains]);

  useEffect(() => {
    if (!loading && searchParams.get("checkRoom")) {
      const targetRoomId = Number(searchParams.get("checkRoom"));
      const room = roomById(targetRoomId);
      openCheckRunner(targetRoomId, room ? room.room_name : `Lokaal #${targetRoomId}`);
      setSearchParams({}, { replace: true });
    }
  }, [loading, searchParams, assets, rooms, buildings]);

  useEffect(() => {
    filterPersist.set({
      search: searchTerm,
      location_id: terrainFilter,
      building_id: buildingFilter,
      room_id: roomFilter,
      status: statusFilter,
    });
  }, [filterPersist, searchTerm, terrainFilter, buildingFilter, roomFilter, statusFilter]);

  const preselectRoom = (roomId) => {
    const room = rooms.find((r) => r.room_id === roomId);
    if (!room) return;
    setFormRoomId(roomId);
    const building = buildings.find((b) => b.building_id === room.building_id);
    if (building) {
      setFormBuildingId(building.building_id);
      setFormLocationId(building.location_id);
    }
  };

  const fetchSessions = async () => {
    try {
      const response = await roomChecksAPI.sessions.getAll({});
      setSessions(response.data || []);
    } catch (err) {
      console.error("Fout met laai van skedules:", err);
      showToast({ type: "error", title: "Fout", message: "Kon nie lokaal-kontroles laai nie." });
    }
  };

  const openCreate = () => {
    setIsViewMode(false);
    setEditing(null);
    setFormLocationId("");
    setFormBuildingId("");
    setFormRoomId(null);
    setFormUserId(null);
    setFormDateTime("");
    setShowForm(true);
  };

  const openEdit = (s) => {
    setIsViewMode(true);
    setEditing(s);
    setFormRoomId(s.room_id);
    setFormUserId(s.assigned_user_id);
    setFormDateTime(s.scheduled_datetime ? s.scheduled_datetime.slice(0, 16) : "");
    const room = rooms.find((r) => r.room_id === s.room_id);
    if (room) {
      const building = buildings.find((b) => b.building_id === room.building_id);
      if (building) {
        setFormBuildingId(building.building_id);
        setFormLocationId(building.location_id);
      } else {
        setFormBuildingId("");
        setFormLocationId("");
      }
    } else {
      setFormBuildingId("");
      setFormLocationId("");
    }
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!formRoomId || !formUserId) {
      showToast({ type: "warning", title: "Waarskuwing", message: "Kies asseblief 'n lokaal en 'n gebruiker." });
      return;
    }
    setSaving(true);
    try {
      const payload = {
        room_id: formRoomId,
        assigned_user_id: formUserId,
        scheduled_datetime: formDateTime ? new Date(formDateTime).toISOString() : null,
      };
      if (editing) {
        await roomChecksAPI.sessions.update(editing.session_id, payload);
        showToast({ type: "success", title: "Sukses", message: "Skedule opgedateer." });
      } else {
        await roomChecksAPI.sessions.create(payload);
        showToast({ type: "success", title: "Sukses", message: "Skedule geskep." });
      }
      setShowForm(false);
      await fetchSessions();
    } catch (err) {
      console.error("Fout met stoor van skedule:", err);
      const detail = err?.response?.data?.detail;
      showToast({
        type: "error",
        title: "Fout",
        message: detail || "Kon nie die skedule stoor nie.",
      });
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (s) => {
    const confirmed = await confirmCascade(confirm, { entityLabel: "skedule", childrenLabel: "kontroles" });
    if (!confirmed) return;
    try {
      await roomChecksAPI.sessions.delete(s.session_id);
      showToast({ type: "success", title: "Sukses", message: "Skedule verwyder." });
      await fetchSessions();
    } catch (err) {
      console.error("Fout met verwydering:", err);
      showToast({ type: "error", title: "Fout", message: getDeleteErrorMessage(err, "Kon nie die skedule verwyder nie.") });
    }
  };

  const [selectedIds, setSelectedIds] = useState([]);
  const toggleOne = (id) => {
    setSelectedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };
  const handleDeleteSelected = () => {
    batchDelete({
      ids: selectedIds,
      apiDelete: roomChecksAPI.sessions.delete,
      confirm,
      showToast,
      entityLabel: "skedules",
      childrenLabel: "kontroles",
      refresh: fetchSessions,
      errorFallback: "Kon nie die skedule verwyder nie.",
    }).then(() => setSelectedIds([]));
  };

  const handleViewHistory = async (s) => {
    setHistorySession(s);
    setShowHistoryModal(true);
    setLoadingHistory(true);
    try {
      const response = await roomChecksAPI.getByRoom(s.room_id);
      setHistoryChecks(response.data || []);
    } catch (error) {
      console.error("Error fetching room checks:", error);
      setHistoryChecks([]);
    } finally {
      setLoadingHistory(false);
    }
  };

  const roomById = (rid) => rooms.find((r) => String(r.room_id) === String(rid)) || null;

  const buildCheckItems = (rid) =>
    assets
      .filter((a) => String(a.room_id) === String(rid))
      .map((asset) => ({ asset, status: "pending", faultId: null }));

  const openCheckRunner = (rid, name) => {
    setCheckRoom({ room_id: rid, room_name: name });
    setCheckItems(buildCheckItems(rid));
    setFaultFormFor(null);
    setFaultDesc("");
    setFaultType("");
    setCheckStage("run");
    setShowCheckModal(true);
  };

  const startCheckFromSession = (s) => {
    const room = roomById(s.room_id);
    openCheckRunner(s.room_id, s.room_name || (room ? room.room_name : `Lokaal #${s.room_id}`));
  };

  const openCheckPicker = () => {
    setCheckLocationId("");
    setCheckBuildingId("");
    setCheckRoomId(null);
    setCheckRoom(null);
    setCheckItems([]);
    setCheckStage("pick");
    setShowCheckModal(true);
  };

  const selectCheckOption = (selectedOption) => {
    if (!selectedOption) {
      setCheckLocationId("");
      setCheckBuildingId("");
      setCheckRoomId(null);
      return;
    }
    const f = selectedOption._fields;
    if (!f.room_id) {
      setCheckLocationId(f.location_id);
      setCheckBuildingId(f.building_id);
      setCheckRoomId(null);
      return;
    }
    const rid = Number(f.room_id);
    setCheckLocationId(f.location_id);
    setCheckBuildingId(f.building_id);
    setCheckRoomId(rid);
    const room = roomById(rid);
    openCheckRunner(rid, room ? room.room_name : `Lokaal #${rid}`);
  };

  const confirmItem = (id) =>
    setCheckItems((prev) => prev.map((i) => (i.asset.asset_id === id ? { ...i, status: "confirmed" } : i)));

  const revealItem = (id) =>
    setCheckItems((prev) => prev.map((i) => (i.asset.asset_id === id ? { ...i, status: "pending", faultId: null } : i)));

  const locationContextForRoom = (rid) => {
    const room = roomById(rid);
    const building = room
      ? buildings.find((b) => String(b.building_id) === String(room.building_id))
      : null;
    return {
      room_id: room ? room.room_id : null,
      building_id: room?.building_id ?? null,
      location_id: building ? building.location_id : null,
    };
  };

  const ticketCreateAuto = async (asset) => {
    try {
      const res = await ticketsAPI.create({
        fault_description: "Bate is nie in lokaal gevind tydens roetine kontrole nie",
        fault_type: "Onderhoud",
        fault_priority: "Medium",
        asset_id: asset.asset_id,
        ...locationContextForRoom(checkRoom.room_id),
      }, { headers: { "X-Idempotency-Key": idemKey() } });
      return res?.data?.fault_id || null;
    } catch (err) {
      console.error("Fout met skep van foutkaartjie:", err);
      showToast({ type: "error", title: "Fout", message: err?.response?.data?.detail || "Kon nie foutkaartjie skep nie." });
      return null;
    }
  };

  const ticketCreateFault = async (asset) => {
    try {
      const res = await ticketsAPI.create({
        fault_description: faultDesc.trim() || `Fout: ${asset.asset_name}`,
        fault_type: faultType || null,
        fault_priority: faultPriority,
        asset_id: asset.asset_id,
        ...locationContextForRoom(checkRoom.room_id),
      }, { headers: { "X-Idempotency-Key": idemKey() } });
      return res?.data?.fault_id || null;
    } catch (err) {
      console.error("Fout met skep van foutkaartjie:", err);
      showToast({ type: "error", title: "Fout", message: err?.response?.data?.detail || "Kon nie foutkaartjie skep nie." });
      return null;
    }
  };

  const markMissing = async (asset) => {
    const faultId = await ticketCreateAuto(asset);
    if (!faultId) return;
    setCheckItems((prev) =>
      prev.map((i) => (i.asset.asset_id === asset.asset_id ? { ...i, status: "missing", faultId } : i)),
    );
  };

  const submitFaultForm = async (asset) => {
    const faultId = await ticketCreateFault(asset);
    if (!faultId) return;
    setCheckItems((prev) =>
      prev.map((i) => (i.asset.asset_id === asset.asset_id ? { ...i, status: "fault_reported", faultId } : i)),
    );
    setFaultFormFor(null);
    setFaultDesc("");
    setFaultType("");
  };

  const handleCheckSave = async () => {
    if (checkItems.length === 0) {
      showToast({ type: "warning", title: "Waarskuwing", message: "Geen bates in hierdie lokaal om na te gaan nie." });
      return;
    }
    const pending = checkItems.filter((i) => i.status === "pending");
    if (pending.length > 0) {
      const ok = await confirm({
        title: "Voltooi kontrole",
        message: `${pending.length} bate(s) is nie nagegaan nie. Foutkaartjies sal outomaties geskep word.`,
        confirmLabel: "Skep foutkaartjies & voltooi",
        cancelLabel: "Kanselleer",
      });
      if (!ok) return;
    }
    setCheckSaving(true);
    try {
      const items = [...checkItems];
      for (const item of items) {
        if (item.status === "pending") {
          const faultId = await ticketCreateAuto(item.asset);
          if (faultId) {
            item.status = "missing";
            item.faultId = faultId;
          }
        }
      }
      const summary = items.map((i) => {
        const entry = {
          asset_id: i.asset.asset_id,
          status: i.status === "confirmed" ? "confirmed" : i.status === "missing" ? "missing" : "fault_reported",
        };
        if (i.faultId) entry.fault_id = i.faultId;
        return entry;
      });
      await roomChecksAPI.create({ room_id: checkRoom.room_id, summary: JSON.stringify(summary) }, { headers: { "X-Idempotency-Key": idemKey() } });
      showToast({ type: "success", title: "Sukses", message: "Kontrole voltooi. Gegeskduleerde kontrole vir die lokaal is afgehandel." });
      setShowCheckModal(false);
      setCheckItems([]);
      setCheckRoom(null);
      await fetchSessions();
    } catch (err) {
      console.error("Fout met stoor van kontrole:", err);
      showToast({ type: "error", title: "Fout", message: err?.response?.data?.detail || "Kon nie die kontrole stoor nie." });
    } finally {
      setCheckSaving(false);
    }
  };

  const CHECK_STATUS_META = {
    confirmed: { label: "Bevestig", color: "#16a34a" },
    fault_reported: { label: "Fout aangemeld", color: "#d97706" },
    missing: { label: "Vermis", color: "#dc2626" },
    pending: { label: "Hangend", color: "#6b7280" },
  };

  const renderCheckItem = (item) => {
    const meta = CHECK_STATUS_META[item.status] || CHECK_STATUS_META.pending;
    const editingFault = faultFormFor === item.asset.asset_id;
    return (
      <div key={item.asset.asset_id} style={{ padding: "10px 14px", borderBottom: "1px solid #e5e7eb" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontWeight: 600, fontSize: 14 }}>{item.asset.asset_name}</div>
            <div style={{ fontSize: 12, color: "#6b7280" }}>Kode: {item.asset.asset_serial || "-"}</div>
          </div>
          <span style={{ padding: "3px 8px", borderRadius: 12, fontSize: 11, fontWeight: 700, color: meta.color, backgroundColor: meta.color + "22", whiteSpace: "nowrap" }}>
            {meta.label}
          </span>
          {item.status === "pending" ? (
            <div style={{ display: "flex", gap: 6, flexShrink: 0 }}>
              <button className="btn-brown" onClick={() => confirmItem(item.asset.asset_id)}>Bevestig</button>
              <button className="btn-brown" onClick={() => markMissing(item.asset)}>Vermis</button>
              <button className="btn-brown" onClick={() => { setFaultFormFor(editingFault ? null : item.asset.asset_id); if (!editingFault) { setFaultDesc(""); setFaultType(""); } }}>
                Meld fout
              </button>
            </div>
          ) : (
            <button className="btn-brown" style={{ flexShrink: 0 }} onClick={() => revealItem(item.asset.asset_id)}>Herroep</button>
          )}
        </div>
        {editingFault && (
          <div style={{ marginTop: 10, padding: 12, background: "#f9fafb", borderRadius: 8 }}>
            <div className="input-group" style={{ marginBottom: 10 }}>
              <label style={{ fontWeight: 600, marginBottom: 4, display: "block" }}>Beskrywing</label>
              <textarea
                className="form-control"
                rows={2}
                value={faultDesc}
                onChange={(e) => setFaultDesc(e.target.value)}
                placeholder="Hoe lyk die fout (bv. beskadigde kode, kaput, ens.)?"
              />
            </div>
            <div style={{ display: "flex", gap: 10, marginBottom: 10 }}>
              <div style={{ flex: 1 }}>
                <label style={{ fontWeight: 600, marginBottom: 4, display: "block" }}>Tipe</label>
                <select className="form-control" value={faultType} onChange={(e) => setFaultType(e.target.value)}>
                  <option value="">- Kies tipe -</option>
                  <option value="Onderhoud">Onderhoud</option>
                  <option value="Herstel">Herstel</option>
                  <option value="Inspeksie">Inspeksie</option>
                  <option value="Installasie">Installasie</option>
                </select>
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ fontWeight: 600, marginBottom: 4, display: "block" }}>Prioriteit</label>
                <select className="form-control" value={faultPriority} onChange={(e) => setFaultPriority(e.target.value)}>
                  <option value="Laag">Laag</option>
                  <option value="Medium">Medium</option>
                  <option value="Hoog">Hoog</option>
                </select>
              </div>
            </div>
            <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
              <button className="btn-cancel" onClick={() => { setFaultFormFor(null); setFaultDesc(""); setFaultType(""); }}>Kanselleer</button>
              <button className="btn-add" onClick={() => submitFaultForm(item.asset)}>Skep foutkaartjie</button>
            </div>
          </div>
        )}
      </div>
    );
  };

  const formatDate = (iso) => {
    if (!iso) return "Geen datum";
    const d = new Date(iso);
    return `${String(d.getDate()).padStart(2, "0")}/${String(d.getMonth() + 1).padStart(2, "0")}/${d.getFullYear()} ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  };

  const completedEarlyTimes = (s) => {
    if (s.status !== "completed" || !s.completed_datetime || !s.scheduled_datetime) return null;
    const completed = new Date(s.completed_datetime);
    const scheduled = new Date(s.scheduled_datetime);
    if (isNaN(completed) || isNaN(scheduled) || completed >= scheduled) return null;
    return { scheduled, completed };
  };

  const scheduleableUsers = useMemo(() => {
    if (!user) return [];
    const selectedRoom = formRoomId ? rooms.find((r) => r.room_id === formRoomId) : null;
    let roomLocationId = null;
    if (selectedRoom) {
      const bld = buildings.find((b) => b.building_id === selectedRoom.building_id);
      if (bld) roomLocationId = String(bld.location_id);
    }
    return assignableUsers.filter((u) => {
      if (u.role_id === 1 || u.role_id === 4) return false;
      if (u.user_id === user.user_id) return true;
      if (u.role_id !== 5) return false;
      if (!roomLocationId) return false;
      return !u.location_id || String(u.location_id) === roomLocationId;
    });
  }, [assignableUsers, user, formRoomId, rooms, buildings]);

  const userOptions = scheduleableUsers.map((u) => ({
    value: u.user_id,
    label: `${u.user_name} ${u.user_surname}`.trim() || `Gebruiker ${u.user_id}`,
  }));

  // Wys slegs die mees onlangse skedule/kontrole per lokaal.
  const latestPerRoom = (() => {
    const newest = {};
    const recency = (s) => {
      if (s.status === "completed") {
        return new Date(s.completed_datetime || s.scheduled_datetime || 0).getTime();
      }
      return new Date(s.scheduled_datetime || s.created_at || 0).getTime();
    };
    for (const s of sessions) {
      const cur = newest[s.room_id];
      const t = recency(s);
      if (!cur || t > recency(cur) || (t === recency(cur) && s.session_id > cur.session_id)) {
        newest[s.room_id] = s;
      }
    }
    return Object.values(newest);
  })();

  const filteredSessions = applySort([...latestPerRoom]
    .filter((s) => {
      if (terrainFilter) {
        const room = rooms.find((r) => r.room_id === s.room_id);
        if (!room) return false;
        const bld = buildings.find((b) => String(b.building_id) === String(room.building_id));
        if (!bld || String(bld.location_id) !== String(terrainFilter)) return false;
      }
      if (buildingFilter) {
        const room = rooms.find((r) => r.room_id === s.room_id);
        if (!room || String(room.building_id) !== String(buildingFilter)) return false;
      }
      if (roomFilter && String(s.room_id) !== String(roomFilter)) return false;
      if (statusFilter && s.status !== statusFilter) return false;
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        room: s.room_name || "",
        user: s.assigned_user_name || "",
        datetime: formatDate(s.scheduled_datetime || s.completed_datetime),
        status: STATUS_LABELS[s.status] || s.status,
        id: String(s.session_id),
      };
      if (filterColumn === "all") {
        return Object.values(values).some((v) => String(v).toLowerCase().includes(query));
      }
      return String(values[filterColumn] || "").toLowerCase().includes(query);
    }),
    (s, key) => {
      switch (key) {
        case "room": return String(s.room_name || "");
        case "user": return String(s.assigned_user_name || "");
        case "datetime": return new Date(s.scheduled_datetime || s.completed_datetime || 0).getTime();
        case "status": return String(s.status || "");
        case "id": return Number(s.session_id || 0);
        default: return "";
      }
    },
  );
    const { currentPage, totalPages, paginatedData: paginatedSessions, goToPage } = usePagination(filteredSessions, 100);
  useEffect(() => { goToPage(1); }, [searchTerm, filterColumn, terrainFilter, buildingFilter, roomFilter, statusFilter, sorts, goToPage]);
  const allSelected = paginatedSessions.length > 0 && paginatedSessions.every((x) => selectedIds.includes(x.session_id));
  const toggleAll = () => {
    if (allSelected) {
      const pageIds = new Set(paginatedSessions.map((x) => x.session_id));
      setSelectedIds((prev) => prev.filter((id) => !pageIds.has(id)));
    } else {
      const pageIds = paginatedSessions.map((x) => x.session_id);
      setSelectedIds((prev) => [...new Set([...prev, ...pageIds])]);
    }
  };

  if (loading) {
    return <div className="main"><div className="content">Laai...</div></div>;
  }

  const pageContent = (
    <>
      <div className="controls controls--sticky">
        <div className="controls-left">
          <div className="control-input-shell">
            <input
              type="text"
              placeholder="Soek skedules..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <FilterPicker
            search={searchTerm}
            onSearch={setSearchTerm}
            filterColumn={filterColumn}
            onFilterColumnChange={setFilterColumn}
            filterColumnOptions={[
              { value: "all", label: "Alle kolomme" },
              { value: "room", label: "Lokaal" },
              { value: "user", label: "Toegewys aan" },
              { value: "datetime", label: "Datum en tyd" },
              { value: "status", label: "Status" },
            ]}
            terrainFilter={terrainFilter}
            buildingFilter={buildingFilter}
            roomFilter={roomFilter}
            onLocationChange={(loc, bld, room) => {
              setTerrainFilter(loc || "");
              setBuildingFilter(bld || "");
              setRoomFilter(room || "");
            }}
            locationOptions={allLocationOptions}
            maxLevel={3}
            lockedTerrain={user?.role_id === 2 ? String(user?.location_id || "") : null}
            statusValue={statusFilter}
            onStatusChange={(v) => setStatusFilter(v || "")}
            statusOptions={[
              { value: "scheduled", label: "Geskeduleer" },
              { value: "completed", label: "Voltooi" },
              { value: "cancelled", label: "Gekanselleer" },
            ]}
            onReset={() => {
              setSearchTerm("");
              setTerrainFilter("");
              setBuildingFilter("");
              setRoomFilter("");
              setStatusFilter("");
            }}
          />
          <SortPicker
            columns={SESSION_COLUMNS}
            sorts={sorts}
            onAdd={addSort}
            onRemove={removeSort}
            onToggleDirection={toggleDirection}
            onMove={moveSort}
            onClear={clearSorts}
          />
          <ColumnPicker
            ref={colPickerRef}
            columns={SESSION_COLUMNS}
            visibleColumns={colVis.visibleColumns}
            toggleColumn={colVis.toggleColumn}
            resetVisibility={colVis.resetVisibility}
            onResetWidths={colWidths.resetWidths}
          />
        </div>
        <div className="controls-right">
          {canManage && <button className="btn-add" onClick={openCreate}>+ Nuwe Skedule</button>}
          {canManage && <button className="btn-brown" style={{ marginLeft: '0.5rem' }} onClick={openCheckPicker}>Kontroleer Lokaal</button>}
          {selectedIds.length > 0 && (
            <button className="btn-delete" style={{ marginLeft: '0.5rem' }} onClick={handleDeleteSelected}>
              Verwyder Geselekteerde ({selectedIds.length})
            </button>
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
                onContextMenu={(e) => colPickerRef.current?.openAt(e)}
              >
                {col.label}
              </ResizableTh>
            ))}
            <th style={{ width: "250px" }}>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredSessions.length === 0 ? (
            <tr><td colSpan={colVis.visibleColumns.length + 2} style={{ textAlign: "center", padding: "20px" }}>Geen skedules gevind nie.</td></tr>
          ) : (
            paginatedSessions.map((s) => (
              <tr key={s.session_id} onClick={() => canManage && openEdit(s)} style={{ cursor: canManage ? "pointer" : "default" }}>
                <td style={{ textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
                  <input type="checkbox" checked={selectedIds.includes(s.session_id)} onChange={() => toggleOne(s.session_id)} />
                </td>
                {colVis.visibleColumns.map((col) => (
                  <td key={col.key}>{col.render(s)}</td>
                ))}
                <td onClick={(e) => e.stopPropagation()}>
                  {canManage && s.status === "scheduled" ? (
                    <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                      <button className="btn-delete" title="Verwyder" onClick={() => handleDelete(s)}><IoTrashOutline size={18} /></button>
                    </div>
                  ) : null}
                  <div style={{ display: "flex", gap: 6, flexWrap: "wrap", marginTop: canManage && s.status === "scheduled" ? 4 : 0 }}>
                    <button className="btn-history" title="Geskiedenis" onClick={() => handleViewHistory(s)}><MdHistory size={18} /></button>
                    {canManage && s.status === "scheduled" && (
                      <button className="btn-brown" onClick={() => startCheckFromSession(s)}>Start Kontrole</button>
                    )}
                  </div>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
      <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} totalItems={filteredSessions.length} pageSize={100} />
    </>
  );

  const modalContent = showForm && canManage && (() => {
    const cascadeCount = [formLocationId, formBuildingId, formRoomId].filter(Boolean).length;
    const currentDisplayValue = cascadeCount === 0 ? null
      : cascadeCount === 1 && formLocationId ? { value: formLocationId, label: terrains?.find((t) => String(t.location_id) === String(formLocationId))?.location_name || formLocationId }
      : cascadeCount === 2 && formBuildingId ? { value: formBuildingId, label: buildings?.find((b) => String(b.building_id) === String(formBuildingId))?.building_name || formBuildingId }
      : cascadeCount === 3 && formRoomId ? { value: formRoomId, label: rooms?.find((r) => r.room_id === formRoomId)?.room_name || formRoomId }
      : null;
    const clearCascadeFromLevel = (levelIndex) => {
      if (levelIndex <= 0) { setFormLocationId(""); setFormBuildingId(""); setFormRoomId(null); }
      else if (levelIndex === 1) { setFormBuildingId(""); setFormRoomId(null); }
      else if (levelIndex === 2) { setFormRoomId(null); }
    };
    const breadcrumbData = [{ level: -1, name: "Terreine" }];
    if (formLocationId) breadcrumbData.push({ level: 0, name: terrains?.find((t) => String(t.location_id) === String(formLocationId))?.location_name || formLocationId });
    if (formBuildingId) breadcrumbData.push({ level: 1, name: buildings?.find((b) => String(b.building_id) === String(formBuildingId))?.building_name || formBuildingId });
    if (formRoomId) breadcrumbData.push({ level: 2, name: rooms?.find((r) => r.room_id === formRoomId)?.room_name || formRoomId });

    return (
      <div className="modal-overlay" onClick={() => setShowForm(false)}>
        <div className="modal-panel" style={{ maxWidth: 640 }} onClick={(e) => e.stopPropagation()}>
          <div className="modal-panel-header">
            <h3>{isViewMode ? "Bekyk Lokaal Kontrole" : editing ? "Wysig Lokaal Kontrole" : "Nuwe Lokaal Kontrole"}</h3>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              {isViewMode && (
                <IoPencil size={20} className="modal-edit-btn" onClick={() => setIsViewMode(false)} title="Wysig" />
              )}
              <span className="modal-close" onClick={() => setShowForm(false)}>&times;</span>
            </div>
          </div>
          <div className="modal-panel-body">
            {editing && (
              <div style={{ display: "flex", flexDirection: "column", gap: 4, marginBottom: 12, fontSize: 13 }}>
                {editing.scheduled_datetime && (
                  <span><strong>Geskeduleerd:</strong> {formatDate(editing.scheduled_datetime)}</span>
                )}
                {editing.status === "completed" && (
                  <span><strong>Voltooi op:</strong> {formatDate(editing.completed_datetime)}</span>
                )}
              </div>
            )}
            <div className="input-group" style={{ marginBottom: 16 }}>
              <label style={{ fontWeight: 600, marginBottom: 4, display: "block" }}>Datum en tyd</label>
              <input
                type="datetime-local"
                className="form-control"
                style={{ width: "100%", padding: 8, marginTop: 0 }}
                value={formDateTime}
                onChange={(e) => setFormDateTime(e.target.value)}
                disabled={isViewMode}
              />
            </div>
            <div className="input-group" style={{ marginBottom: 16, position: "relative" }} ref={formCascade.containerRef}>
              <label style={{ fontWeight: 600, marginBottom: 4, display: "block" }}>Ligging</label>
              {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel: clearCascadeFromLevel, maxLevel: 3, marginTop: "6px", marginBottom: "6px", disabled: isViewMode })}
              <Select
                className="react-select-container"
                classNamePrefix="react-select"
                placeholder={["Kies Terrein...", "Kies Gebou...", "Kies Lokaal...", "Ligging voltooi"][cascadeCount]}
                isClearable
                isDisabled={isViewMode || cascadeCount >= 3}
                closeMenuOnSelect={false}
                menuIsOpen={formCascade.menuIsOpen}
                menuPortalTarget={document.body}
                menuPosition="fixed"
                onMenuOpen={formCascade.onMenuOpen}
                onMenuClose={formCascade.onMenuClose}
                components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearCascadeFromLevel} disabled={isViewMode} />, IndicatorsContainer: (p) => <CascadeIndicatorsContainer {...p} disabled={isViewMode} />, ClearIndicator: NoCascadeClearIndicator }}
                options={allLocationOptions}
                styles={{
                  control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                  valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                  singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                  menu: (base) => ({ ...base, zIndex: 10000 }),
                  menuPortal: (base) => ({ ...base, zIndex: 10000 }),
                }}
                filterOption={(option, rawInput) => {
                  if (rawInput) {
                    if (cascadeCount === 0)
                      return option.data._cascadeLevel <= 2 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                    if (cascadeCount === 1)
                      return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 2 && String(option.data._fields.location_id) === String(formLocationId) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                    if (cascadeCount === 2)
                      return option.data._cascadeLevel === 2 && String(option.data._fields.building_id) === String(formBuildingId) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                  }
                  if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                  if (cascadeCount === 1) return option.data._cascadeLevel === 1 && String(option.data._parentId) === String(formLocationId);
                  if (cascadeCount === 2) return option.data._cascadeLevel === 2 && String(option.data._parentId) === String(formBuildingId);
                  return false;
                }}
                value={currentDisplayValue}
                onChange={(selectedOption) => {
                  if (!selectedOption) { setFormLocationId(""); setFormBuildingId(""); setFormRoomId(null); return; }
                  setFormLocationId(selectedOption._fields.location_id);
                  setFormBuildingId(selectedOption._fields.building_id);
                  setFormRoomId(selectedOption._fields.room_id ? Number(selectedOption._fields.room_id) : null);
                  if (cascadeToast) clearTimeout(cascadeToast);
                  const labels = ["Terrein", "Gebou", "Lokaal"];
                  const label = labels[selectedOption._cascadeLevel] || "";
                  setCascadeToast(`\u2713 ${label} suksesvol geselekteer`);
                  const t = setTimeout(() => setCascadeToast(null), 2000);
                  setCascadeToast(t);
                }}
              />
              {cascadeToast && typeof cascadeToast === "string" && (
                <div style={{ position: "absolute", top: "50%", left: "50%", transform: "translate(-50%, -50%)", background: "#16a34a", color: "#fff", padding: "10px 24px", borderRadius: "10px", fontSize: "14px", fontWeight: "600", boxShadow: "0 4px 14px rgba(0,0,0,0.25)", zIndex: 10, textAlign: "center", pointerEvents: "none", whiteSpace: "nowrap" }}>
                  {cascadeToast}
                </div>
              )}
            </div>
            <div className="input-group" style={{ marginBottom: 16 }}>
              <label style={{ fontWeight: 600, marginBottom: 4, display: "block" }}>Toegewys aan</label>
              <RawSelect
                isClearable
                classNamePrefix="react-select"
                options={userOptions}
                value={userOptions.find((o) => o.value === formUserId) || null}
                onChange={(o) => setFormUserId(o ? o.value : null)}
                placeholder={formRoomId ? "Kies gebruiker" : "Kies eers 'n lokaal"}
                isDisabled={isViewMode || !formRoomId}
                menuPortalTarget={document.body}
                menuPosition="fixed"
                styles={{
                  menu: (base) => ({ ...base, zIndex: 10000 }),
                  menuPortal: (base) => ({ ...base, zIndex: 10000 }),
                }}
              />
            </div>
          </div>
          <div className="modal-panel-footer">
            <button className="btn-cancel" onClick={() => setShowForm(false)}>Kanselleer</button>
            {!isViewMode && (
              <button className="btn-add" onClick={handleSave} disabled={saving}>
                {saving ? "Stoor..." : (editing ? "Stoor" : "Skeduleer")}
              </button>
            )}
          </div>
        </div>
      </div>
    );
  })();

  const historyModalContent = showHistoryModal && historySession && (
    <div className="modal-overlay" onClick={() => { setShowHistoryModal(false); setHistoryChecks([]); }}>
      <div className="modal-panel" style={{ maxWidth: 700 }} onClick={(e) => e.stopPropagation()}>
        <div className="modal-panel-header">
          <h3>Kontrole-geskiedenis: {historySession.room_name || `Lokaal #${historySession.room_id}`}</h3>
          <span className="modal-close" onClick={() => { setShowHistoryModal(false); setHistoryChecks([]); }}>&times;</span>
        </div>
        <div className="modal-panel-body">
          {loadingHistory ? (
            <p>Laai geskiedenis...</p>
          ) : historyChecks.length === 0 ? (
            <p>Geen kontrole-geskiedenis nie.</p>
          ) : (
            <div style={{ maxHeight: "400px", overflowY: "auto" }}>
              {historyChecks.map((check) => {
                let summary = [];
                try { summary = JSON.parse(check.summary || '[]'); } catch(e) {}
                const confirmed = summary.filter(s => s.status === 'confirmed').length;
                const missing = summary.filter(s => s.status === 'missing').length;
                const faultReported = summary.filter(s => s.status === 'fault_reported').length;
                const dt = new Date(check.checked_datetime);
                const dateStr = `${dt.getDate().toString().padStart(2,'0')}/${(dt.getMonth()+1).toString().padStart(2,'0')}/${dt.getFullYear()} ${dt.getHours().toString().padStart(2,'0')}:${dt.getMinutes().toString().padStart(2,'0')}`;
                return (
                  <details key={check.room_check_id} style={{ marginBottom: "12px", border: "1px solid #e5e7eb", borderRadius: "8px", padding: "8px 12px" }}>
                    <summary style={{ cursor: "pointer", fontWeight: 600, fontSize: "14px", display: "flex", alignItems: "center", gap: "8px" }}>
                      {dateStr} {check.user_name ? `(${check.user_name})` : ''}
                      <span style={{
                        fontSize: "12px", padding: "2px 8px", borderRadius: "12px", fontWeight: 600,
                        backgroundColor: check.check_status === "Voltooi" ? "#dcfce7" : "#fef2f2",
                        color: check.check_status === "Voltooi" ? "#16a34a" : "#dc2626",
                      }}>
                        {check.check_status || "Voltooi"}
                      </span>
                    </summary>
                    <div style={{ marginTop: "8px", fontSize: "13px", display: "flex", gap: "12px", flexWrap: "wrap" }}>
                      <span style={{ color: "#16a34a", fontWeight: 600 }}>Bevestig: {confirmed}</span>
                      <span style={{ color: "#d97706", fontWeight: 600 }}>Foute: {faultReported}</span>
                      <span style={{ color: "#dc2626", fontWeight: 600 }}>Vermis: {missing}</span>
                    </div>
                    <ul style={{ marginTop: "8px", paddingLeft: "16px", fontSize: "12px" }}>
                      {summary.map((item, i) => {
                        const asset = assets.find((a) => String(a.asset_id) === String(item.asset_id));
                        const name = item.asset_name || asset?.asset_name;
                        const serial = item.asset_serial || asset?.asset_serial;
                        return (
                          <li key={i} style={{ marginBottom: "4px", color: item.status === 'missing' ? "#dc2626" : item.status === 'fault_reported' ? "#d97706" : "#16a34a" }}>
                            {name ? <strong>{name}</strong> : `Bate #${item.asset_id}`}
                            {serial ? ` (${serial})` : ''} — {
                              item.status === 'confirmed' ? 'Bevestig'
                              : item.status === 'missing' ? 'Vermis'
                              : item.status === 'fault_reported' ? 'Fout aangemeld'
                              : 'Hangend'
                            }
                            {item.fault_id ? ` (FK#${item.fault_id})` : ''}
                          </li>
                        );
                      })}
                    </ul>
                  </details>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );

  const checkModalContent = showCheckModal && canManage && (checkStage === "pick" ? (() => {
    const cascadeCount = [checkLocationId, checkBuildingId, checkRoomId].filter(Boolean).length;
    const currentDisplayValue = cascadeCount === 0 ? null
      : cascadeCount === 1 && checkLocationId ? { value: checkLocationId, label: terrains?.find((t) => String(t.location_id) === checkLocationId)?.location_name || checkLocationId }
      : cascadeCount === 2 && checkBuildingId ? { value: checkBuildingId, label: buildings?.find((b) => String(b.building_id) === checkBuildingId)?.building_name || checkBuildingId }
      : checkRoomId ? { value: checkRoomId, label: rooms?.find((r) => String(r.room_id) === checkRoomId)?.room_name || checkRoomId }
      : null;
    const clearFromLevel = (levelIndex) => {
      if (levelIndex <= 0) { setCheckLocationId(""); setCheckBuildingId(""); setCheckRoomId(null); }
      else if (levelIndex === 1) { setCheckBuildingId(""); setCheckRoomId(null); }
      else if (levelIndex === 2) { setCheckRoomId(null); }
    };
    const breadcrumbData = [{ level: -1, name: "Terreine" }];
    if (checkLocationId) breadcrumbData.push({ level: 0, name: terrains?.find((t) => String(t.location_id) === checkLocationId)?.location_name || checkLocationId });
    if (checkBuildingId) breadcrumbData.push({ level: 1, name: buildings?.find((b) => String(b.building_id) === checkBuildingId)?.building_name || checkBuildingId });
    if (checkRoomId) breadcrumbData.push({ level: 2, name: rooms?.find((r) => String(r.room_id) === checkRoomId)?.room_name || checkRoomId });

    return (
      <div className="modal-overlay" onClick={() => setShowCheckModal(false)}>
        <div className="modal-panel" style={{ maxWidth: 640 }} onClick={(e) => e.stopPropagation()}>
          <div className="modal-panel-header">
            <h3>Kontroleer 'n lokaal</h3>
            <span className="modal-close" onClick={() => setShowCheckModal(false)}>&times;</span>
          </div>
          <div className="modal-panel-body">
            <p style={{ marginBottom: 12, fontSize: 14, color: "#374151" }}>Kies die lokaal om te kontroleer. Die bates sal dan gelys word om na te gaan.</p>
            <div className="input-group" style={{ marginBottom: 16, position: "relative" }} ref={checkCascade.containerRef}>
              <label style={{ fontWeight: 600, marginBottom: 4, display: "block" }}>Ligging</label>
              {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 3, marginTop: "6px", marginBottom: "6px" })}
              <Select
                className="react-select-container"
                classNamePrefix="react-select"
                placeholder={["Kies Terrein...", "Kies Gebou...", "Kies Lokaal...", "Ligging voltooi"][cascadeCount]}
                isClearable
                isDisabled={cascadeCount >= 3}
                closeMenuOnSelect={false}
                menuIsOpen={checkCascade.menuIsOpen}
                menuPortalTarget={document.body}
                menuPosition="fixed"
                onMenuOpen={checkCascade.onMenuOpen}
                onMenuClose={checkCascade.onMenuClose}
                components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} />, IndicatorsContainer: CascadeIndicatorsContainer, ClearIndicator: NoCascadeClearIndicator }}
                options={allLocationOptions}
                styles={{
                  control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                  valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                  singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                  menu: (base) => ({ ...base, zIndex: 10000 }),
                  menuPortal: (base) => ({ ...base, zIndex: 10000 }),
                }}
                filterOption={(option, rawInput) => {
                  if (rawInput) {
                    if (cascadeCount === 0)
                      return option.data._cascadeLevel <= 2 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                    if (cascadeCount === 1)
                      return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 2 && String(option.data._fields.location_id) === String(checkLocationId) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                    if (cascadeCount === 2)
                      return option.data._cascadeLevel === 2 && String(option.data._fields.building_id) === String(checkBuildingId) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                  }
                  if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                  if (cascadeCount === 1) return option.data._cascadeLevel === 1 && String(option.data._parentId) === String(checkLocationId);
                  if (cascadeCount === 2) return option.data._cascadeLevel === 2 && String(option.data._parentId) === String(checkBuildingId);
                  return false;
                }}
                value={currentDisplayValue}
                onChange={selectCheckOption}
              />
            </div>
          </div>
          <div className="modal-panel-footer">
            <button className="btn-cancel" onClick={() => setShowCheckModal(false)}>Kanselleer</button>
          </div>
        </div>
      </div>
    );
  })() : (() => {
    const confirmedCount = checkItems.filter((i) => i.status === "confirmed").length;
    const faultCount = checkItems.filter((i) => i.status === "fault_reported").length;
    const missingCount = checkItems.filter((i) => i.status === "missing").length;
    const pendingCount = checkItems.filter((i) => i.status === "pending").length;
    const chip = (label, count, color) => (
      <span style={{ padding: "3px 10px", borderRadius: 12, fontSize: 11, fontWeight: 700, color, backgroundColor: color + "22" }}>
        {label}: {count}
      </span>
    );
    return (
      <div className="modal-overlay" onClick={() => setShowCheckModal(false)}>
        <div className="modal-panel" style={{ maxWidth: 720 }} onClick={(e) => e.stopPropagation()}>
          <div className="modal-panel-header">
            <h3>Kontrole: {checkRoom?.room_name || `Lokaal #${checkRoom?.room_id}`}</h3>
            <span className="modal-close" onClick={() => setShowCheckModal(false)}>&times;</span>
          </div>
          <div className="modal-panel-body">
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center", marginBottom: 12 }}>
              {chip("Bevestig", confirmedCount, "#16a34a")}
              {chip("Foute", faultCount, "#d97706")}
              {chip("Vermis", missingCount, "#dc2626")}
              {chip("Hangend", pendingCount, "#6b7280")}
              <button className="btn-brown" style={{ marginLeft: "auto" }} onClick={openCheckPicker}>Ander lokaal</button>
            </div>
            {checkItems.length === 0 ? (
              <p>Geen bates in hierdie lokaal nie.</p>
            ) : (
              <div style={{ maxHeight: "45vh", overflowY: "auto", border: "1px solid #e5e7eb", borderRadius: 8, background: "#fff" }}>
                {checkItems.map(renderCheckItem)}
              </div>
            )}
          </div>
          <div className="modal-panel-footer">
            <button className="btn-cancel" onClick={() => setShowCheckModal(false)}>Sluit</button>
            <button className="btn-add" onClick={handleCheckSave} disabled={checkSaving || checkItems.length === 0}>
              {checkSaving ? "Stoor..." : `Voltooi (${confirmedCount} / ${checkItems.length} bevestig)`}
            </button>
          </div>
        </div>
      </div>
    );
  })());

  return (
    <div className="main">
      <div className="content">
        {pageContent}
      </div>
      {modalContent}
      {historyModalContent}
      {checkModalContent}
      {dialog}
    </div>
  );
}

export default RoomCheckSessionsPage;
