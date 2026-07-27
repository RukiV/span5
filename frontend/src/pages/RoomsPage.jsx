import React, { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import Select, { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";
import { assetsAPI, buildingsAPI, roomsAPI, locationAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import "../styles/App.css";
import "../styles/Rooms.css";

function RoomsPage({ embedded = false }) {
  const { user } = useCurrentUser();

  const [rooms, setRooms] = useState([]);
  const [assets, setAssets] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  const [showModal, setShowModal] = useState(false);
  const [showAssetsModal, setShowAssetsModal] = useState(false);
  const [selectedRoom, setSelectedRoom] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [cascadeToast, setCascadeToast] = useState(null);
  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const [roomFilter, setRoomFilter] = useState("");
  
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
      alert(`Kon nie lokaal stoor nie:\n${errorMsg}`);
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
    if (!window.confirm("Is jy seker jy wil hierdie lokaal verwyder?")) {
      return;
    }
    try {
      await roomsAPI.delete(roomId);
      await fetchRooms();
    } catch (error) {
      console.error("Error deleting room:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
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
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'name') return String(a.room_name || '').localeCompare(String(b.room_name || ''), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'code') return String(a.room_code || '').localeCompare(String(b.room_code || ''), 'af', { sensitivity: 'base' }) * direction;
      if (sortBy === 'capacity') return (Number(a.room_capacity || 0) - Number(b.room_capacity || 0)) * direction;
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

  const sortByOptions = [
    { value: "default", label: "Standaard" },
    { value: "name", label: "Naam" },
    { value: "code", label: "Kode" },
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
          <Select
            className="basic-single"
            classNamePrefix="select"
            value={sortByOptions.find(o => o.value === sortBy)}
            onChange={(selected) => setSortBy(selected ? selected.value : "default")}
            options={sortByOptions}
            isSearchable={false}
            styles={{ container: (base) => ({ ...base, minWidth: '140px' }) }}
          />
          <div style={{ display: 'flex', gap: '0.25rem' }}>
            <button type="button" className="btn-add" onClick={() => setSortDirection('asc')} style={{ minWidth: '40px', background: sortDirection === 'asc' ? '#935e28' : undefined }} title="Stygend">▲</button>
            <button type="button" className="btn-add" onClick={() => setSortDirection('desc')} style={{ minWidth: '40px', background: sortDirection === 'desc' ? '#935e28' : undefined }} title="Dalend">▼</button>
          </div>
          <button className="btn-add" onClick={handleNewRoom}>+ Nuwe Lokaal</button>
        </div>
      </div>

      <table className="standard-table">
        <thead>
          <tr>
            <th>Naam</th>
            <th>Kode</th>
            <th>Tipe</th>
            <th>Status</th>
            <th>Gebou</th>
            <th>Kapasiteit</th>
            <th>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredRooms.map((room) => (
            <tr key={room.room_id} onClick={() => handleEditRoom(room)} style={{ cursor: "pointer" }}>
              <td>{room.room_name}</td>
              <td>{room.room_code ?? '-'}</td>
              <td>{translateRoomType(room.room_type || 'Ander')}</td>
              <td>{translateRoomStatus(room.room_status || 'Operasioneel')}</td>
              <td>{getBuildingName(room.building_id)}</td>
              <td>{room.room_capacity ?? '-'}</td>
              <td onClick={e => e.stopPropagation()}>
                <button className="btn-view" onClick={() => handleViewAssets(room)}>
                  Besigtig Bates
                </button>
                <button className="btn-delete" onClick={() => handleDeleteRoom(room.room_id)}>
                  Verwyder
                </button>
              </td>
            </tr>
          ))}
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
                    options={(() => {
                      if (cascadeCount === 0) return (terrains || []).map(t => ({ value: String(t.location_id), label: `${t.location_id} - ${t.location_name || "Terrein"}` }));
                      if (cascadeCount === 1) return (buildings || []).filter(b => String(b.location_id) === String(newRoom.location_id)).map(b => ({ value: String(b.building_id), label: `${b.building_id} - ${b.building_name || "Gebou"}` }));
                      return [];
                    })()}
                    value={null}
                    onChange={(selectedOption) => {
                      if (!selectedOption) return;
                      const labels = ["Terrein","Gebou"];
                      if (cascadeCount === 0) setNewRoom(p => ({...p, location_id: selectedOption.value, building_id: ""}));
                      else if (cascadeCount === 1) setNewRoom(p => ({...p, building_id: selectedOption.value}));
                      if (invalidFields.location_id) setInvalidFields(prev => { const n = {...prev}; delete n.location_id; return n; });
                      setCascadeToast(`✓ ${labels[cascadeCount]} suksesvol geselekteer`);
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
    </div>
  );
}

export default RoomsPage;