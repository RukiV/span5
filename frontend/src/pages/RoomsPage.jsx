import React, { useState, useEffect, useRef, useMemo } from "react";
import { Link, useNavigate } from "react-router-dom";
import Select, { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";
import { assetsAPI, buildingsAPI, roomsAPI, locationAPI, roomChecksAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import "../styles/App.css";
import "../styles/Rooms.css";
import { buildFlatLocationOptions } from './locationSearchUtils';
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import ResizableTh from "../components/ResizableTh";


function RoomsPage({ embedded = false }) {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { user, rights } = useCurrentUser();
  const navigate = useNavigate();
  const canManageSessions = (rights || []).includes("roomchecks.manage");

  const [rooms, setRooms] = useState([]);
  const [assets, setAssets] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: null });
  const ROOM_COLUMNS = [
    { key: 'id', label: 'ID', render: (r) => r.room_id, sortKey: 'id', defaultVisible: false },
    { key: 'name', label: 'Naam', render: (r) => r.room_name, sortKey: 'name', defaultVisible: true },
    { key: 'code', label: 'Kode', render: (r) => r.room_code || '-', sortKey: 'code', defaultVisible: true },
    { key: 'type', label: 'Tipe', render: (r) => translateRoomType(r.room_type), sortKey: 'type', defaultVisible: true },
    { key: 'status', label: 'Status', render: (r) => r.room_status, sortKey: 'status', defaultVisible: true },
    { key: 'building', label: 'Gebou', render: (r) => getBuildingName(r.building_id), sortKey: 'building', defaultVisible: true },
    { key: 'capacity', label: 'Kapasiteit', render: (r) => r.room_capacity ?? '-', sortKey: 'capacity', defaultVisible: true },
  ];
  const colVis = useColumnVisibility('rooms-page', ROOM_COLUMNS);
  const colWidths = useColumnWidths('rooms-page', ROOM_COLUMNS);
  const colPickerRef = useRef(null);
  const [showModal, setShowModal] = useState(false);
  const [showAssetsModal, setShowAssetsModal] = useState(false);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [selectedRoom, setSelectedRoom] = useState(null);
  const [roomChecks, setRoomChecks] = useState([]);
  const [loadingChecks, setLoadingChecks] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [cascadeToast, setCascadeToast] = useState(null);
  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const [roomFilter, setRoomFilter] = useState("");
  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, rooms, assets), [terrains, buildings, rooms, assets]);
  
  // Opdateer: Verander die standaard room_type na 'Ander' om by die backend te pas
  const [newRoom, setNewRoom] = useState({
    room_name: "",
    room_code: "",
    room_capacity: "",
    room_type: "", 
    room_status: "Operasioneel",
    location_id: "",
    building_id: "",
  });
  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});

  useEffect(() => {
    const loadData = async () => {
      await Promise.all([fetchRooms(), fetchAssets(), fetchTerrains(), fetchBuildings()]);
    };
    loadData();
  }, []);

  useEffect(() => {
    if (user?.role_id === 2 && user?.location_id) {
      setTerrainFilter(String(user.location_id));
    } else {
      setTerrainFilter("");
    }
  }, [user]);

  const fetchRooms = async () => {
    setLoading(true);
    try {
      const response = await roomsAPI.getAll();
      setRooms(response.data || []);
    } catch (error) {
      console.error("Error fetching rooms:", error);
    } finally {
      setLoading(false);
    }
  };

  const fetchAssets = async () => {
    try {
      const response = await assetsAPI.getAll();
      setAssets(response.data || []);
    } catch (error) {
      console.error("Error fetching assets:", error);
    }
  };

  const fetchTerrains = async () => {
    try {
      const response = await locationAPI.getAll();
      setTerrains(response.data || []);
    } catch (error) {
      console.error("Error fetching terrains:", error);
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

  // Opdateer: Aangesien die backend reeds die korrekte Afrikaanse stringe stoor en terugstuur, 
  // hoef ons dit nie meer van Engels af te vertaal nie. Ons gee net die waarde terug.
  const translateRoomType = (type) => {
    return type || "Ander";
  };

  const translateRoomStatus = (status) => {
    return status || "Operasioneel";
  };

  const handleSaveRoom = async () => {
    const errors = {};
    if (!newRoom.room_name?.trim()) errors.room_name = true;
    if (!newRoom.room_code?.trim()) errors.room_code = true;
    if (!newRoom.room_capacity || Number(newRoom.room_capacity) <= 0) errors.room_capacity = true;
    if (!newRoom.building_id) errors.location_id = true;
    if (Object.keys(errors).length > 0) {
      setInvalidFields(errors);
      const firstKey = Object.keys(errors)[0];
      fieldRefs.current[firstKey]?.scrollIntoView({ behavior: "smooth", block: "center" });
      fieldRefs.current[firstKey]?.focus();
      return;
    }
    setInvalidFields({});

    const roomData = {
      room_name: newRoom.room_name,
      room_code: newRoom.room_code,
      room_capacity: newRoom.room_capacity ? Number(newRoom.room_capacity) : 0,
      room_type: newRoom.room_type, // Stuur nou die korrekte waarde (bv. 'Klaskamer')
      room_status: newRoom.room_status,
      building_id: Number(newRoom.building_id),
    };

    try {
      if (isEditing) {
        await roomsAPI.update(editingId, roomData);
      } else {
        await roomsAPI.create(roomData);
      }
      await fetchRooms();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving room:", error);
      // Wys 'n meer beskrywende foutboodskap as die backend validasie gooi
      const errorMsg = error.response?.data?.detail?.[0]?.msg || error.response?.data?.message || "Fout tydens besparing.";
      showToast({ type: 'error', title: 'Fout', message: `Kon nie lokaal stoor nie:\n${errorMsg}` });
    }
  };

  const handleEditRoom = (room) => {
    const building = buildings.find((b) => b.building_id === room.building_id);
    setIsEditing(true);
    setEditingId(room.room_id);
    setNewRoom({
      room_name: room.room_name || "",
      room_code: room.room_code || "",
      room_capacity: room.room_capacity ?? "",
      room_type: room.room_type || "",
      room_status: room.room_status || "Operasioneel",
      location_id: building ? building.location_id : "",
      building_id: room.building_id ?? "",
    });
    setShowModal(true);
  };

  const handleDeleteRoom = async (roomId) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie lokaal verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' }); if (!confirmed) return;
    try {
      await roomsAPI.delete(roomId);
      await fetchRooms();
    } catch (error) {
      console.error("Error deleting room:", error);
      showToast({ type: 'error', title: 'Fout', message: "Fout tydens verwydering. Probeer asseblief weer." });
    }
  };

  const handleNewRoom = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewRoom({
      room_name: "",
      room_code: "",
      room_capacity: "",
      room_type: "Ander",
      room_status: "Operasioneel",
      location_id: "",
      building_id: "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewRoom({
      room_name: "",
      room_code: "",
      room_capacity: "",
      room_type: "Ander",
      room_status: "Operasioneel",
      location_id: "",
      building_id: "",
    });
  };

  const handleViewAssets = (room) => {
    setSelectedRoom(room);
    setShowAssetsModal(true);
  };

  const getAssetsForRoom = (roomId) => assets.filter((asset) => asset.room_id === roomId);

  const handleViewHistory = async (room) => {
    setSelectedRoom(room);
    setShowHistoryModal(true);
    setLoadingChecks(true);
    try {
      const response = await roomChecksAPI.getByRoom(room.room_id);
      setRoomChecks(response.data || []);
    } catch (error) {
      console.error("Error fetching room checks:", error);
      setRoomChecks([]);
    } finally {
      setLoadingChecks(false);
    }
  };

  const getBuildingName = (buildingId) => {
    const building = buildings.find((b) => b.building_id === buildingId);
    return building ? building.building_name : "-";
  };

  const filteredRooms = [...rooms]
    .filter((room) => {
      if (terrainFilter) {
        const bld = buildings?.find(b => String(b.building_id) === String(room.building_id));
        const locId = bld ? String(bld.location_id) : '';
        if (locId !== String(terrainFilter)) return false;
      }
      if (buildingFilter && String(room.building_id) !== String(buildingFilter)) return false;
      if (roomFilter && String(room.room_id) !== String(roomFilter)) return false;
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        name: room.room_name,
        code: room.room_code,
        type: translateRoomType(room.room_type || 'Ander'),
        status: translateRoomStatus(room.room_status || 'Operasioneel'),
        building: getBuildingName(room.building_id),
        capacity: room.room_capacity,
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (!sortKey) return 0;
      const dir = sortDirection === 'asc' ? 1 : -1;
      if (sortKey === 'name') return String(a.room_name || '').localeCompare(String(b.room_name || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'code') return String(a.room_code || '').localeCompare(String(b.room_code || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'type') return String(translateRoomType(a.room_type) || '').localeCompare(String(translateRoomType(b.room_type) || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'status') return String(a.room_status || '').localeCompare(String(b.room_status || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'building') return String(getBuildingName(a.building_id)).localeCompare(String(getBuildingName(b.building_id)), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'capacity') return (Number(a.room_capacity || 0) - Number(b.room_capacity || 0)) * dir;
      return 0;
    });

  const filterColumnOptions = [
    { value: "all", label: "Alle kolomme" },
    { value: "name", label: "Naam" },
    { value: "code", label: "Kode" },
    { value: "type", label: "Tipe" },
    { value: "status", label: "Status" },
    { value: "building", label: "Gebou" },
    { value: "capacity", label: "Kapasiteit" }
  ];

  // Opdateer: Verander die `value` eienskappe om eksak ooreen te stem met die backend se reëls
  const roomTypeOptions = [
    { value: "Klaskamer", label: "Klaskamer" },
    { value: "Laboratorium", label: "Laboratorium" },
    { value: "Kantoor", label: "Kantoor" },
    { value: "Konferensiekamer", label: "Konferensiekamer" },
    { value: "Pakhuis", label: "Pakhuis" },
    { value: "Badkamer", label: "Badkamer" },
    { value: "Ander", label: "Ander" }
  ];

  const roomStatusOptions = [
    { value: "Operasioneel", label: "Operasioneel" },
    { value: "Fout Aangemeld", label: "Fout Aangemeld" },
    { value: "Instandhouding", label: "Instandhouding" },
    { value: "Buite Werking", label: "Buite Werking" }
  ];

  if (loading) {
    return <div className="main"><div className="content">Laai...</div></div>;
  }

  const pageContent = (
    <>
      <div className="controls">
        <div className="controls-left">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
            <input
              type="text"
              className="search-box"
              placeholder="Soek lokale..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <Select
            className="basic-single"
            classNamePrefix="select"
            value={filterColumnOptions.find(o => o.value === filterColumn)}
            onChange={(selected) => setFilterColumn(selected ? selected.value : "all")}
            options={filterColumnOptions}
            isSearchable={false}
            styles={{ container: (base) => ({ ...base, minWidth: '160px' }) }}
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
                    options={allLocationOptions}
                    filterOption={(option, rawInput) => {
                      if (rawInput) {
                        if (cascadeCount === 0)
                          return option.data._cascadeLevel <= 1 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        if (cascadeCount === 1)
                          return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 1 && String(option.data._fields.location_id) === String(terrainFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
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
            columns={ROOM_COLUMNS}
            visibleColumns={colVis.visibleColumns}
            toggleColumn={colVis.toggleColumn}
            resetVisibility={colVis.resetVisibility}
            onResetWidths={colWidths.resetWidths}
          />
          <button className="btn-add" onClick={handleNewRoom}>+ Nuwe Lokaal</button>
        </div>
      </div>

      <table className="standard-table">
        <thead>
          <tr>
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
            <th style={{ width: '180px' }}>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredRooms.length === 0 ? (
            <tr><td colSpan={colVis.visibleColumns.length + 1} style={{ textAlign: 'center', padding: '20px' }}>Geen lokale gevind</td></tr>
          ) : (
            filteredRooms.map((room) => (
              <tr key={room.room_id} onClick={() => handleEditRoom(room)} style={{ cursor: "pointer" }}>
                {colVis.visibleColumns.map((col) => (
                  <td key={col.key}>{col.render(room)}</td>
                ))}
                <td onClick={e => e.stopPropagation()}>
                  <button className="btn-view" onClick={() => handleViewAssets(room)}>Bekyk Bates</button>
                  <button className="btn-view" onClick={() => handleViewHistory(room)}>Geskiedenis</button>
                  {canManageSessions && (
                    <button className="btn-view" onClick={() => navigate(`/room-checks-schedules?scheduleRoom=${room.room_id}`)}>Skeduleer</button>
                  )}
                  <button className="btn-delete" onClick={() => handleDeleteRoom(room.room_id)}>Verwyder</button>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </>
  );

  const modalContent = (
    <div className="modal" style={{ display: 'flex' }}>
      <div className="modal-content">
        <div className="modal-header">
          <h3>{isEditing ? "Wysig" : "Nuwe"} lokaal {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
          <span className="close" onClick={handleCloseModal}>&times;</span>
        </div>

        <div className="input-row">
          <div className="input-group">
            <label>Naam *</label>
            <input
              ref={el => fieldRefs.current.room_name = el}
              type="text"
              value={newRoom.room_name}
              className={invalidFields.room_name ? "field-invalid" : ""}
              onChange={(e) => {
                setNewRoom({ ...newRoom, room_name: e.target.value });
                if (invalidFields.room_name) setInvalidFields(prev => { const n = {...prev}; delete n.room_name; return n; });
              }}
            />
          </div>
          <div className="input-group">
            <label>Lokaal Kode *</label>
            <input
              ref={el => fieldRefs.current.room_code = el}
              type="text"
              placeholder="Bv. L10"
              value={newRoom.room_code}
              className={invalidFields.room_code ? "field-invalid" : ""}
              onChange={(e) => {
                setNewRoom({ ...newRoom, room_code: e.target.value });
                if (invalidFields.room_code) setInvalidFields(prev => { const n = {...prev}; delete n.room_code; return n; });
              }}
            />
          </div>
        </div>

        <div className="input-row">
          <div className="input-group">
            <label>Kapasiteit *</label>
            <input
              ref={el => fieldRefs.current.room_capacity = el}
              type="number"
              value={newRoom.room_capacity}
              className={invalidFields.room_capacity ? "field-invalid" : ""}
              onChange={(e) => {
                setNewRoom({ ...newRoom, room_capacity: e.target.value });
                if (invalidFields.room_capacity) setInvalidFields(prev => { const n = {...prev}; delete n.room_capacity; return n; });
              }}
            />
          </div>
          <div className="input-group">
            <label>Tipe</label>
            <Select
              className="basic-single"
              classNamePrefix="select"
              value={roomTypeOptions.find(o => o.value === newRoom.room_type)}
              onChange={(selected) => setNewRoom({ ...newRoom, room_type: selected ? selected.value : "" })}
              options={roomTypeOptions}
              isSearchable={false}
            />
          </div>
          <div className="input-group">
            <label>Status</label>
            <Select
              className="basic-single"
              classNamePrefix="select"
              value={roomStatusOptions.find(option => option.value === newRoom.room_status)}
              onChange={(selectedOption) => setNewRoom({ ...newRoom, room_status: selectedOption ? selectedOption.value : "Operasioneel" })}
              options={roomStatusOptions}
              isSearchable={false}
            />
          </div>
        </div>

        <div className="input-row">
          <div className={invalidFields.location_id ? "input-group field-invalid" : "input-group"} style={{ position: "relative", flex: 1 }}>
            <label>Ligging *</label>
            {(() => {
              const cascadeCount = [newRoom.location_id, newRoom.building_id].filter(Boolean).length;
              const clearFromLevel = (levelIndex) => {
                if (levelIndex <= 0) setNewRoom(p => ({...p, location_id: "", building_id: ""}));
                else if (levelIndex === 1) setNewRoom(p => ({...p, building_id: ""}));
              };
              const breadcrumbData = [{ level: -1, name: "Terreine" }];
              if (newRoom.location_id) breadcrumbData.push({ level: 0, name: terrains?.find(t => String(t.location_id) === String(newRoom.location_id))?.location_name || newRoom.location_id });
              if (newRoom.building_id) breadcrumbData.push({ level: 1, name: buildings?.find(b => String(b.building_id) === String(newRoom.building_id))?.building_name || newRoom.building_id });
              const renderBreadcrumb = () => (
                <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: "4px", fontSize: "13px", color: "#111827", marginTop: "6px", marginBottom: "6px" }}>
                  {breadcrumbData.map((item, i) => {
                    const isLast = i === breadcrumbData.length - 1;
                    const showArrow = isLast ? cascadeCount < 2 : true;
                    return (
                      <React.Fragment key={i}>
                        <button type="button" className="breadcrumb-btn" onClick={() => clearFromLevel(item.level + 1)} style={{ border: "none", cursor: "pointer", margin: "0", color: "#111827", fontWeight: isLast ? 700 : 600, fontSize: "13px", lineHeight: "1", display: "inline-flex", alignItems: "center" }}>{item.name}</button>
                        {showArrow && <span style={{ color: "#9ca3af", lineHeight: "1", display: "inline-flex", alignItems: "center" }}>›</span>}
                      </React.Fragment>
                    );
                  })}
                </div>
              );
              const backBtnStyle = { background: "#935e28", border: "none", borderRadius: "4px", color: "#fff", cursor: "pointer", display: "flex", alignItems: "center", padding: "4px 8px", margin: "2px" };
              const CascadeControl = ({ children, ...props }) => (
                <components.Control {...props}>
                  {children}
                  {cascadeCount > 0 && (
                    <span className="cascade-back-indicator" onMouseDown={(e) => { e.stopPropagation(); e.preventDefault(); clearFromLevel(cascadeCount - 1); }} title="Terug na vorige vlak" style={backBtnStyle}>
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
                      placeholder={["Kies Terrein...","Kies Gebou...","Ligging voltooi"][cascadeCount]}
                      isClearable
                      isDisabled={cascadeCount >= 2}
                      closeMenuOnSelect={false}
                      components={{ Control: CascadeControl }}
                      options={allLocationOptions}
                      filterOption={(option, rawInput) => {
                        if (rawInput) {
                          if (cascadeCount === 0)
                            return option.data._cascadeLevel <= 1 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 1)
                            return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 1 && String(option.data._fields.location_id) === String(newRoom.location_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        }
                        if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                        if (cascadeCount === 1) return option.data._cascadeLevel === 1 && String(option.data._parentId) === String(newRoom.location_id);
                        return false;
                      }}
                      value={null}
                      onChange={(selectedOption) => {
                        if (!selectedOption) return;
                        setNewRoom(p => ({...p, ...selectedOption._fields}));
                        if (invalidFields.location_id) setInvalidFields(prev => { const n = {...prev}; delete n.location_id; return n; });
                        const labels = ["Terrein","Gebou"];
                        const label = labels[selectedOption._cascadeLevel] || "";
                        setCascadeToast(`✓ ${label} suksesvol geselekteer`);
                        setTimeout(() => setCascadeToast(null), 2000);
                      }}
                    />
                </>
              );
            })()}
            {cascadeToast && (
              <div style={{ position: "absolute", top: "50%", left: "50%", transform: "translate(-50%, -50%)", background: "#16a34a", color: "#fff", padding: "10px 24px", borderRadius: "10px", fontSize: "14px", fontWeight: "600", boxShadow: "0 4px 14px rgba(0,0,0,0.25)", zIndex: 10, textAlign: "center", pointerEvents: "none", whiteSpace: "nowrap" }}>
                {cascadeToast}
              </div>
            )}
          </div>
        </div>

        <div className="modal-footer">
          <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
          <button className="btn-add" onClick={handleSaveRoom}>{isEditing ? "Opdateer" : "Stoor"}</button>
        </div>
      </div>
    </div>
  );

  const historyModalContent = showHistoryModal && selectedRoom && (
    <div className="modal" style={{ display: "flex" }}>
      <div className="modal-content">
        <div className="modal-header">
          <h3>Kontrole-geskiedenis: {selectedRoom.room_name}</h3>
          <span className="close" onClick={() => { setShowHistoryModal(false); setRoomChecks([]); }}>&times;</span>
        </div>
        <div className="modal-body">
          {loadingChecks ? (
            <p>Laai geskiedenis...</p>
          ) : roomChecks.length === 0 ? (
            <p>Geen kontrole-geskiedenis nie.</p>
          ) : (
            <div style={{ maxHeight: "400px", overflowY: "auto" }}>
              {roomChecks.map((check) => {
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

  if (embedded) {
    return (
      <>
        {pageContent}

        {showModal && modalContent}

        {showAssetsModal && selectedRoom && (
          <div className="modal" style={{ display: "flex" }}>
            <div className="modal-content">
              <div className="modal-header">
                <h3>Bates in {getBuildingName(selectedRoom.building_id)} - {selectedRoom.room_name}</h3>
                <span className="close" onClick={() => setShowAssetsModal(false)}>&times;</span>
              </div>
              <div className="modal-body">
                {getAssetsForRoom(selectedRoom.room_id).length > 0 ? (
                  <table className="assets-table">
                    <thead>
                      <tr>
                        <th>Naam</th>
                        <th>Serienommer</th>
                        <th>Buite</th>
                        <th>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {getAssetsForRoom(selectedRoom.room_id).map((asset) => (
                        <tr key={asset.asset_id}>
                          <td>{asset.asset_name}</td>
                          <td>{asset.asset_serial}</td>
                          <td>{asset.asset_isoutdoor ? "Ja" : "Nee"}</td>
                          <td>{asset.asset_status}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                ) : (
                  <p>Geen bates in hierdie lokaal.</p>
                )}
              </div>
            </div>
          </div>
        )}

        {historyModalContent}
      {dialog}
      </>
    );
  }

  return (
    <div className="main">
      <div className="content">
        {pageContent}
      </div>

      {showModal && modalContent}

      {showAssetsModal && selectedRoom && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Bates in {getBuildingName(selectedRoom.building_id)} - {selectedRoom.room_name}</h3>
              <span className="close" onClick={() => setShowAssetsModal(false)}>&times;</span>
            </div>
            <div className="modal-body">
              {getAssetsForRoom(selectedRoom.room_id).length > 0 ? (
                <table className="assets-table">
                  <thead>
                    <tr>
                      <th>Naam</th>
                      <th>Serienommer</th>
                      <th>Buite</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {getAssetsForRoom(selectedRoom.room_id).map((asset) => (
                      <tr key={asset.asset_id}>
                        <td>{asset.asset_name}</td>
                        <td>{asset.asset_serial}</td>
                        <td>{asset.asset_isoutdoor ? "Ja" : "Nee"}</td>
                        <td>{asset.asset_status}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p>Geen bates in hierdie lokaal.</p>
              )}
            </div>
          </div>
          </div>
        )}

        {historyModalContent}
      {dialog}
    </div>
  );
}

export default RoomsPage;