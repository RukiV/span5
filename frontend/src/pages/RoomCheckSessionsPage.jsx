import React, { useState, useEffect, useRef, useMemo } from "react";
import RawSelect from "react-select";
import Select from "react-select";
import { IoTrashOutline } from "react-icons/io5";
import { renderBreadcrumb, CascadeControl, CascadeIndicatorsContainer, NoCascadeClearIndicator } from "../components/controlHelpers";
import { useSearchParams } from "react-router-dom";
import { roomChecksAPI, roomsAPI, usersAPI, locationAPI, buildingsAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import { useToast } from "../components/Toast/useToast";
import { useConfirmDialog } from "../components/Modal/useConfirmDialog";
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import useColumnWidths from "../hooks/useColumnWidths";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import ResizableTh from "../components/ResizableTh";
import { buildFlatLocationOptions } from "./locationSearchUtils";
import useCascadeMenu from "../hooks/useCascadeMenu";
import "../styles/App.css";
import "../styles/Rooms.css";
import "../components/Modal/Modal.css";
import { getDeleteErrorMessage, confirmCascade, batchDelete } from "../utils/deleteUtils";

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
  const [loading, setLoading] = useState(true);

  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: "scheduled_datetime" });

  const SESSION_COLUMNS = [
    { key: "room", label: "Lokaal", render: (s) => s.room_name || `Lokaal #${s.room_id}`, sortKey: "room", defaultVisible: true },
    { key: "user", label: "Toegewys aan", render: (s) => s.assigned_user_name || `Gebruiker #${s.assigned_user_id}`, sortKey: "user", defaultVisible: true },
    { key: "datetime", label: "Datum en tyd", render: (s) => formatDate(s.scheduled_datetime), sortKey: "datetime", defaultVisible: true },
    { key: "status", label: "Status", render: (s) => statusBadge(s.status), sortKey: "status", defaultVisible: true },
    { key: "id", label: "ID", render: (s) => s.session_id, sortKey: "id", defaultVisible: false },
  ];
  const colVis = useColumnVisibility("sessions-page", SESSION_COLUMNS);
  const colWidths = useColumnWidths("sessions-page", SESSION_COLUMNS);
  const colPickerRef = useRef(null);

  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const [roomFilter, setRoomFilter] = useState("");
  const [cascadeToast, setCascadeToast] = useState(null);
  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, rooms, []), [terrains, buildings, rooms]);
  const filterCascade = useCascadeMenu();
  const formCascade = useCascadeMenu();

  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [formLocationId, setFormLocationId] = useState("");
  const [formBuildingId, setFormBuildingId] = useState("");
  const [formRoomId, setFormRoomId] = useState(null);
  const [formUserId, setFormUserId] = useState(null);
  const [formDateTime, setFormDateTime] = useState("");
  const [saving, setSaving] = useState(false);

  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [historySession, setHistorySession] = useState(null);
  const [historyChecks, setHistoryChecks] = useState([]);
  const [loadingHistory, setLoadingHistory] = useState(false);

  useEffect(() => {
    const init = async () => {
      try {
        const [sessionsRes, roomsRes, usersRes, terrainsRes, buildingsRes] = await Promise.all([
          roomChecksAPI.sessions.getAll({}),
          roomsAPI.getAll(),
          usersAPI.getAssignable(),
          locationAPI.getAll(),
          buildingsAPI.getAll(),
        ]);
        setSessions(sessionsRes.data || []);
        setRooms(roomsRes.data || []);
        setAssignableUsers(usersRes.data || []);
        setTerrains(terrainsRes.data || []);
        setBuildings(buildingsRes.data || []);
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
    if (!loading && searchParams.get("scheduleRoom")) {
      const targetRoomId = searchParams.get("scheduleRoom");
      openCreate();
      preselectRoom(Number(targetRoomId));
      setSearchParams({}, { replace: true });
    }
  }, [loading, searchParams, rooms, buildings, terrains]);

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
      showToast({ type: "error", title: "Fout", message: "Kon nie kontrole-skedules laai nie." });
    }
  };

  const openCreate = () => {
    setEditing(null);
    setFormLocationId("");
    setFormBuildingId("");
    setFormRoomId(null);
    setFormUserId(null);
    setFormDateTime("");
    setShowForm(true);
  };

  const openEdit = (s) => {
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
      showToast({ type: "error", title: "Fout", message: "Kon nie die skedule stoor nie." });
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
  const toggleAll = () => {
    setSelectedIds(allSelected ? [] : filteredSessions.map((x) => x.session_id));
  };
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

  const formatDate = (iso) => {
    if (!iso) return "Geen datum";
    const d = new Date(iso);
    return `${String(d.getDate()).padStart(2, "0")}/${String(d.getMonth() + 1).padStart(2, "0")}/${d.getFullYear()} ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
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

  const filteredSessions = [...sessions]
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
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        room: s.room_name || "",
        user: s.assigned_user_name || "",
        datetime: formatDate(s.scheduled_datetime),
        status: STATUS_LABELS[s.status] || s.status,
        id: String(s.session_id),
      };
      if (filterColumn === "all") {
        return Object.values(values).some((v) => String(v).toLowerCase().includes(query));
      }
      return String(values[filterColumn] || "").toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (!sortKey) return 0;
      const dir = sortDirection === "asc" ? 1 : -1;
      if (sortKey === "room") return String(a.room_name || "").localeCompare(String(b.room_name || ""), "af", { sensitivity: "base" }) * dir;
      if (sortKey === "user") return String(a.assigned_user_name || "").localeCompare(String(b.assigned_user_name || ""), "af", { sensitivity: "base" }) * dir;
      if (sortKey === "datetime") return (new Date(a.scheduled_datetime || 0) - new Date(b.scheduled_datetime || 0)) * dir;
      if (sortKey === "status") return String(a.status || "").localeCompare(String(b.status || ""), "af", { sensitivity: "base" }) * dir;
      if (sortKey === "id") return (a.session_id - b.session_id) * dir;
      return 0;
    });
  const allSelected = filteredSessions.length > 0 && selectedIds.length === filteredSessions.length;

  const filterColumnOptions = [
    { value: "all", label: "Alle kolomme" },
    { value: "room", label: "Lokaal" },
    { value: "user", label: "Toegewys aan" },
    { value: "datetime", label: "Datum en tyd" },
    { value: "status", label: "Status" },
  ];

  if (loading) {
    return <div className="main"><div className="content">Laai...</div></div>;
  }

  const pageContent = (
    <>
      <div className="controls">
        <div className="controls-left">
          <div className="control-input-shell">
            <input
              type="text"
              placeholder="Soek skedules..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <Select
            className="react-select-container"
            classNamePrefix="react-select"
            value={filterColumnOptions.find((o) => o.value === filterColumn)}
            onChange={(selected) => setFilterColumn(selected ? selected.value : "all")}
            options={filterColumnOptions}
            isSearchable={false}
            styles={{
              container: (base) => ({ ...base, minWidth: "160px" }),
              control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
              valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
              singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
            }}
          />
          {(() => {
            const cascadeCount = [terrainFilter, buildingFilter, roomFilter].filter(Boolean).length;
            const currentDisplayValue = cascadeCount === 0 ? null
              : cascadeCount === 1 && terrainFilter ? { value: terrainFilter, label: terrains?.find((t) => String(t.location_id) === terrainFilter)?.location_name || terrainFilter }
              : cascadeCount === 2 && buildingFilter ? { value: buildingFilter, label: buildings?.find((b) => String(b.building_id) === buildingFilter)?.building_name || buildingFilter }
              : null;
            const clearFromLevel = (levelIndex) => {
              if (levelIndex <= 0) { setTerrainFilter(""); setBuildingFilter(""); setRoomFilter(""); }
              else if (levelIndex === 1) { setBuildingFilter(""); setRoomFilter(""); }
              else if (levelIndex === 2) { setRoomFilter(""); }
            };
            const breadcrumbData = [{ level: -1, name: "Terreine" }];
            if (terrainFilter) breadcrumbData.push({ level: 0, name: terrains?.find((t) => String(t.location_id) === terrainFilter)?.location_name || terrainFilter });
            if (buildingFilter) breadcrumbData.push({ level: 1, name: buildings?.find((b) => String(b.building_id) === buildingFilter)?.building_name || buildingFilter });
            if (roomFilter) breadcrumbData.push({ level: 2, name: rooms?.find((r) => String(r.room_id) === roomFilter)?.room_name || roomFilter });
            return (
              <div className="control-cascade-stack" ref={filterCascade.containerRef}>
                <div className="control-cascade-breadcrumb">
                  {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 3 })}
                </div>
                <Select
                  className="react-select-container"
                  classNamePrefix="react-select"
                  placeholder={["Kies Terrein...", "Kies Gebou...", "Kies Lokaal...", "Filter voltooi"][cascadeCount]}
                  isClearable
                  isDisabled={cascadeCount >= 3}
                  closeMenuOnSelect={false}
                  menuIsOpen={filterCascade.menuIsOpen}
                  onMenuOpen={filterCascade.onMenuOpen}
                  onMenuClose={filterCascade.onMenuClose}
                  components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} />, IndicatorsContainer: CascadeIndicatorsContainer, ClearIndicator: NoCascadeClearIndicator }}
                  styles={{
                    container: (base) => ({ ...base, minWidth: "260px" }),
                    control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                    valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                    singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                  }}
                  options={allLocationOptions}
                  filterOption={(option, rawInput) => {
                    if (rawInput) {
                      if (cascadeCount === 0)
                        return option.data._cascadeLevel <= 2 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                      if (cascadeCount === 1)
                        return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 2 && String(option.data._fields.location_id) === String(terrainFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                      if (cascadeCount === 2)
                        return option.data._cascadeLevel === 2 && String(option.data._fields.building_id) === String(buildingFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
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
                    setTerrainFilter(f.location_id);
                    setBuildingFilter(f.building_id);
                    setRoomFilter(f.room_id);
                  }}
                />
              </div>
            );
          })()}
        </div>
        <div className="controls-right">
          <ColumnPicker
            ref={colPickerRef}
            columns={SESSION_COLUMNS}
            visibleColumns={colVis.visibleColumns}
            toggleColumn={colVis.toggleColumn}
            resetVisibility={colVis.resetVisibility}
            onResetWidths={colWidths.resetWidths}
          />
          {canManage && <button className="btn-add" onClick={openCreate}>+ Nuwe Skedule</button>}
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
                className={col.sortKey ? getSortClass(col.sortKey) : ""}
                onClick={() => col.sortKey && handleSort(col.sortKey)}
                onContextMenu={(e) => colPickerRef.current?.openAt(e)}
              >
                {col.label}{col.sortKey && getSortIndicator(col.sortKey)}
              </ResizableTh>
            ))}
            <th style={{ width: "250px" }}>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredSessions.length === 0 ? (
            <tr><td colSpan={colVis.visibleColumns.length + 2} style={{ textAlign: "center", padding: "20px" }}>Geen skedules gevind nie.</td></tr>
          ) : (
            filteredSessions.map((s) => (
              <tr key={s.session_id} onClick={() => canManage && openEdit(s)} style={{ cursor: canManage ? "pointer" : "default" }}>
                <td style={{ textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
                  <input type="checkbox" checked={selectedIds.includes(s.session_id)} onChange={() => toggleOne(s.session_id)} />
                </td>
                {colVis.visibleColumns.map((col) => (
                  <td key={col.key}>{col.render(s)}</td>
                ))}
                <td onClick={(e) => e.stopPropagation()}>
                  {s.status === "completed" && (
                    <button className="btn-view" onClick={() => handleViewHistory(s)}>Geskiedenis</button>
                  )}
                  {canManage && s.status === "scheduled" && (
                    <>
                      <button className="btn-view" onClick={() => openEdit(s)}>Wysig</button>
                      <button className="btn-delete" title="Verwyder" onClick={() => handleDelete(s)}><IoTrashOutline size={18} /></button>
                    </>
                  )}
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
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
            <h3>{editing ? "Wysig Skedule" : "Nuwe Kontrole Skedule"}</h3>
            <span className="modal-close" onClick={() => setShowForm(false)}>&times;</span>
          </div>
          <div className="modal-panel-body">
            <div className="input-group" style={{ marginBottom: 16 }}>
              <label style={{ fontWeight: 600, marginBottom: 4, display: "block" }}>Datum en tyd</label>
              <input
                type="datetime-local"
                className="form-control"
                style={{ width: "100%", padding: 8, marginTop: 0 }}
                value={formDateTime}
                onChange={(e) => setFormDateTime(e.target.value)}
              />
            </div>
            <div className="input-group" style={{ marginBottom: 16, position: "relative" }} ref={formCascade.containerRef}>
              <label style={{ fontWeight: 600, marginBottom: 4, display: "block" }}>Ligging</label>
              {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel: clearCascadeFromLevel, maxLevel: 3, marginTop: "6px", marginBottom: "6px" })}
              <Select
                className="react-select-container"
                classNamePrefix="react-select"
                placeholder={["Kies Terrein...", "Kies Gebou...", "Kies Lokaal...", "Ligging voltooi"][cascadeCount]}
                isClearable
                isDisabled={cascadeCount >= 3}
                closeMenuOnSelect={false}
                menuIsOpen={formCascade.menuIsOpen}
                onMenuOpen={formCascade.onMenuOpen}
                onMenuClose={formCascade.onMenuClose}
                components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearCascadeFromLevel} />, IndicatorsContainer: CascadeIndicatorsContainer, ClearIndicator: NoCascadeClearIndicator }}
                options={allLocationOptions}
                styles={{
                  control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                  valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                  singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
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
                isDisabled={!formRoomId}
              />
            </div>
          </div>
          <div className="modal-panel-footer">
            <button className="btn-cancel" onClick={() => setShowForm(false)}>Kanselleer</button>
            <button className="btn-add" onClick={handleSave} disabled={saving}>
              {saving ? "Stoor..." : (editing ? "Stoor" : "Skeduleer")}
            </button>
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
                        {check.check_status || "Onvoltooi"}
                      </span>
                    </summary>
                    <div style={{ marginTop: "8px", fontSize: "13px", display: "flex", gap: "12px", flexWrap: "wrap" }}>
                      <span style={{ color: "#16a34a", fontWeight: 600 }}>Bevestig: {confirmed}</span>
                      <span style={{ color: "#d97706", fontWeight: 600 }}>Foute: {faultReported}</span>
                      <span style={{ color: "#dc2626", fontWeight: 600 }}>Vermis: {missing}</span>
                    </div>
                    <ul style={{ marginTop: "8px", paddingLeft: "16px", fontSize: "12px" }}>
                      {summary.map((item, i) => (
                        <li key={i} style={{ marginBottom: "4px" }}>
                          Bate #{item.asset_id} — {
                            item.status === 'confirmed' ? 'Bevestig'
                            : item.status === 'missing' ? 'Vermis'
                            : item.status === 'fault_reported' ? 'Fout aangemeld'
                            : 'Hangend'
                          }
                          {item.fault_id ? ` (FK#${item.fault_id})` : ''}
                        </li>
                      ))}
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

  return (
    <div className="main">
      <div className="content">
        {pageContent}
      </div>
      {modalContent}
      {historyModalContent}
      {dialog}
    </div>
  );
}

export default RoomCheckSessionsPage;
