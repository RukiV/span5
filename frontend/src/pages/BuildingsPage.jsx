import React, { useState, useEffect, useRef, useMemo } from "react";
import { Link } from "react-router-dom";
import Select, { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";
import Sidebar from '../components/Sidebar';
import { buildingsAPI, locationAPI, roomsAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import "../styles/Rooms.css";
import { useLogout } from "./Page.jsx";
import { buildFlatLocationOptions } from './locationSearchUtils';
import UserProfileHeader from '../components/UserProfileHeader';

function BuildingsPage({ embedded = false }) {
  const { isAdmin, user } = useCurrentUser();
  const logout = useLogout();
  const [buildings, setBuildings] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, null, null), [terrains, buildings]);
  const [showModal, setShowModal] = useState(false);
  const [showRoomsModal, setShowRoomsModal] = useState(false);
  const [selectedBuilding, setSelectedBuilding] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newBuilding, setNewBuilding] = useState({
    building_name: "",
    building_type: "",
    location_id: "",
  });
  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});

  const translateBuildingType = (type) => {
    const translations = {
      "Kantoorgebou": "Admin",
      "Onderwys": "Onderwys",
      "Laboratorium": "Laboratorium",
      "warehouse": "Pakhuis",
      "Kafeteria": "Kafeteria",
      "Ander": "Ander",
    };
    return translations[type] || type;
  };

  useEffect(() => {
    const loadData = async () => {
      await Promise.all([fetchBuildings(), fetchTerrains(), fetchRooms()]);
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

  const fetchBuildings = async () => {
    setLoading(true);
    try {
      const response = await buildingsAPI.getAll();
      setBuildings(response.data || []);
    } catch (error) {
      console.error("Error fetching buildings:", error);
    } finally {
      setLoading(false);
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

  const fetchRooms = async () => {
    try {
      const response = await roomsAPI.getAll();
      setRooms(response.data || []);
    } catch (error) {
      console.error("Error fetching rooms:", error);
    }
  };

  const getTerrainName = (locationId) => {
    const terrain = terrains.find((t) => t.location_id === locationId);
    return terrain ? terrain.location_name : "-";
  };

  const getRoomsForBuilding = (buildingId) => rooms.filter((r) => r.building_id === buildingId);

  const translateRoomType = (type) => {
    const translations = {
      classroom: "Klaslokaal",
      laboratory: "Laboratorium",
      office: "Kantoor",
      other: "Ander",
    };
    return translations[type] || type;
  };

  const handleSaveBuilding = async () => {
    const errors = {};
    if (!newBuilding.building_name?.trim()) errors.building_name = true;
    if (!newBuilding.location_id) errors.location_id = true;
    if (Object.keys(errors).length > 0) {
      setInvalidFields(errors);
      const firstKey = Object.keys(errors)[0];
      fieldRefs.current[firstKey]?.scrollIntoView({ behavior: "smooth", block: "center" });
      fieldRefs.current[firstKey]?.focus();
      return;
    }
    setInvalidFields({});

    const buildingData = {
      building_name: newBuilding.building_name,
      building_type: newBuilding.building_type,
      location_id: Number(newBuilding.location_id),
    };

    try {
      if (isEditing) {
        await buildingsAPI.update(editingId, buildingData);
      } else {
        await buildingsAPI.create(buildingData);
      }
      await fetchBuildings();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving building:", error);
      alert("Fout tydens besparing. Probeer asseblief weer.");
    }
  };

  const handleDeleteBuilding = async (id) => {
    if (!window.confirm("Is jy seker jy wil hierdie gebou verwyder?")) {
      return;
    }
    try {
      await buildingsAPI.delete(id);
      await fetchBuildings();
    } catch (error) {
      console.error("Error deleting building:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  const handleEditBuilding = (item) => {
    setIsEditing(true);
    setEditingId(item.building_id);
    setNewBuilding({
      building_name: item.building_name || "",
      building_type: item.building_type || "",
      location_id: item.location_id || "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewBuilding({ building_name: "", building_type: "Ander", location_id: "" });
  };

  const handleNewBuilding = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewBuilding({ building_name: "", building_type: "Ander", location_id: "" });
    setShowModal(true);
  };

  const handleViewRooms = (building) => {
    setSelectedBuilding(building);
    setShowRoomsModal(true);
  };

  const filteredBuildings = [...buildings]
    .filter((building) => {
      if (terrainFilter && String(building.location_id) !== String(terrainFilter)) return false;
      if (buildingFilter && String(building.building_id) !== String(buildingFilter)) return false;
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        id: building.building_id,
        name: building.building_name,
        type: translateBuildingType(building.building_type),
        terrain: getTerrainName(building.location_id),
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (sortBy === 'default') return 0;
      const direction = sortDirection === 'asc' ? 1 : -1;
      if (sortBy === 'id') return (Number(a.building_id || 0) - Number(b.building_id || 0)) * direction;
      if (sortBy === 'name') return String(a.building_name || '').localeCompare(String(b.building_name || ''), 'af', { sensitivity: 'base' }) * direction;
      return 0;
    });

  // Opsies vir dropdowns
  const filterColumnOptions = [
    { value: "all", label: "Alle kolomme" },
    { value: "name", label: "Naam" },
    { value: "type", label: "Tipe" },
    { value: "terrain", label: "Terrein" }
  ];

  const sortByOptions = [
    { value: "default", label: "Standaard" },
    { value: "name", label: "Naam" }
  ];

  const buildingTypeOptions = [
    { value: "Kantoorgebou", label: "Admin" },
    { value: "Onderwys", label: "Onderwys" },
    { value: "Laboratorium", label: "Laboratorium" },
    { value: "warehouse", label: "Pakhuis" },
    { value: "Kafeteria", label: "Kafeteria" },
    { value: "Ander", label: "Ander" }
  ];

  const terrainOptions = terrains.map((t) => ({
    value: String(t.location_id),
    label: t.location_name
  }));

  if (loading) {
    return <div style={{ display: "flex" }}><div className="main"><div className="content">Laai...</div></div></div>;
  }

  const pageContent = (
    <>
      <div className="analytics-grid">
        <div className="analytics-card">
          <h4>Totale Geboue</h4>
          <p className="analytics-value">{buildings.length}</p>
        </div>
        <div className="analytics-card">
          <h4>Lokale</h4>
          <p className="analytics-value">{rooms.length}</p>
        </div>
        <div className="analytics-card">
          <h4>Tipes</h4>
          <p className="analytics-value">{new Set(buildings.map(b => b.building_type).filter(Boolean)).size}</p>
        </div>
        <div className="analytics-card">
          <h4>Terreine</h4>
          <p className="analytics-value">{new Set(buildings.map(b => b.location_id).filter(Boolean)).size}</p>
        </div>
      </div>
      <div className="controls">
        <div className="controls-left">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
            <input
              type="text"
              className="search-box"
              placeholder="Soek geboue..."
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
            const cascadeCount = [terrainFilter, buildingFilter].filter(Boolean).length;
            const currentDisplayValue = cascadeCount === 0 ? null
              : cascadeCount === 1 && terrainFilter ? { value: terrainFilter, label: terrains?.find(t => String(t.location_id) === terrainFilter)?.location_name || terrainFilter }
              : cascadeCount === 2 && buildingFilter ? { value: buildingFilter, label: buildings?.find(b => String(b.building_id) === buildingFilter)?.building_name || buildingFilter }
              : null;
            const clearFromLevel = (levelIndex) => {
              if (levelIndex <= 0) { setTerrainFilter(''); setBuildingFilter(''); }
              else if (levelIndex === 1) { setBuildingFilter(''); }
            };
            const breadcrumbData = [{ level: -1, name: "Terreine" }];
            if (terrainFilter) breadcrumbData.push({ level: 0, name: terrains?.find(t => String(t.location_id) === terrainFilter)?.location_name || terrainFilter });
            if (buildingFilter) breadcrumbData.push({ level: 1, name: buildings?.find(b => String(b.building_id) === buildingFilter)?.building_name || buildingFilter });
            const renderBreadcrumb = () => (
              <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: "4px", fontSize: "13px", color: "#111827", marginTop: "4px" }}>
                {breadcrumbData.map((item, i) => {
                  const isLast = i === breadcrumbData.length - 1;
                  const showArrow = isLast ? cascadeCount < 2 : true;
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
                    placeholder={["Kies Terrein...","Kies Gebou...","Filter voltooi"][cascadeCount]}
                    isClearable
                    isDisabled={cascadeCount >= 2}
                    components={{ Control: CascadeControl }}
                    styles={{ container: (base) => ({ ...base, minWidth: '260px' }) }}
                    options={allLocationOptions}
                    filterOption={(option, rawInput) => {
                      if (cascadeCount === 0 && rawInput)
                        return option.data._cascadeLevel <= 0 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                      if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                      if (cascadeCount === 1) return option.data._cascadeLevel === 1 && String(option.data._parentId) === String(terrainFilter);
                      return false;
                    }}
                    value={currentDisplayValue}
                    onChange={(selectedOption) => {
                      if (!selectedOption) return;
                      const f = selectedOption._fields;
                      setTerrainFilter(f.location_id); setBuildingFilter(f.building_id);
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
          <button className="btn-add" onClick={handleNewBuilding}>+ Nuwe Gebou</button>
        </div>
      </div>

      <table className="standard-table">
        <thead>
          <tr>
            <th>Naam</th>
            <th>Tipe</th>
            <th>Terrein</th>
            <th>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredBuildings.map((building) => (
            <tr key={building.building_id} onClick={() => handleEditBuilding(building)} style={{ cursor: "pointer" }}>
              <td>{building.building_name}</td>
              <td>{translateBuildingType(building.building_type)}</td>
              <td>{getTerrainName(building.location_id)}</td>
              <td onClick={e => e.stopPropagation()}>
                <button className="btn-view" onClick={() => handleViewRooms(building)}>Besigtig Lokale</button>
                <button className="btn-delete" onClick={() => handleDeleteBuilding(building.building_id)}>Verwyder</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );

  const modalContent = (
    <div className="modal" style={{ display: "flex" }}>
      <div className="modal-content">
        <div className="modal-header">
          <h3>{isEditing ? "Wysig" : "Nuwe"} Gebou {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
          <span className="close" onClick={handleCloseModal}>&times;</span>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Naam *</label>
            <input
              type="text"
              ref={el => fieldRefs.current.building_name = el}
              className={invalidFields.building_name ? "field-invalid" : ""}
              value={newBuilding.building_name}
              onChange={(e) => {
                setNewBuilding({ ...newBuilding, building_name: e.target.value });
                if (invalidFields.building_name) setInvalidFields(prev => { const n = { ...prev }; delete n.building_name; return n; });
              }}
            />
          </div>
          <div className="input-group">
            <label>Tipe</label>
            <Select
              className="basic-single"
              classNamePrefix="select"
              value={buildingTypeOptions.find(o => o.value === newBuilding.building_type)}
              onChange={(selected) => setNewBuilding({ ...newBuilding, building_type: selected ? selected.value : "" })}
              options={buildingTypeOptions}
              isSearchable={false}
            />
          </div>
        </div>
        <div className="input-row">
          <div className={invalidFields.location_id ? "input-group field-invalid" : "input-group"} style={{ position: "relative" }}>
            <label>Terrein *</label>
            {(() => {
              const cascadeCount = [newBuilding.location_id].filter(Boolean).length;
              const clearFromLevel = (levelIndex) => {
                if (levelIndex <= 0) setNewBuilding(p => ({...p, location_id: ""}));
              };
              const breadcrumbData = [{ level: -1, name: "Terreine" }];
              if (newBuilding.location_id) breadcrumbData.push({ level: 0, name: terrains?.find(t => String(t.location_id) === String(newBuilding.location_id))?.location_name || newBuilding.location_id });
              const renderBreadcrumb = () => (
                <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: "4px", fontSize: "13px", color: "#111827", marginTop: "6px", marginBottom: "6px" }}>
                  {breadcrumbData.map((item, i) => {
                    const isLast = i === breadcrumbData.length - 1;
                    const showArrow = isLast ? cascadeCount < 1 : true;
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
                    placeholder={["Kies Terrein...","Ligging voltooi"][cascadeCount]}
                    isClearable
                    isDisabled={cascadeCount >= 1}
                    closeMenuOnSelect={false}
                    components={{ Control: CascadeControl }}
                    options={allLocationOptions}
                    filterOption={(option, rawInput) => {
                      if (cascadeCount === 0 && rawInput)
                        return option.data._cascadeLevel <= 0 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                      if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                      return false;
                    }}
                    value={null}
                    onChange={(selectedOption) => {
                      if (!selectedOption) return;
                      setNewBuilding(p => ({...p, ...selectedOption._fields}));
                      if (invalidFields.location_id) setInvalidFields(prev => { const n = {...prev}; delete n.location_id; return n; });
                    }}
                  />
                </>
              );
            })()}
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
          <button className="btn-add" onClick={handleSaveBuilding}>{isEditing ? "Opdateer" : "Stoor"}</button>
        </div>
      </div>
    </div>
  );

  if (embedded) {
    return (
      <>
        {pageContent}

        {showModal && modalContent}

        {showRoomsModal && selectedBuilding && (
          <div className="modal" style={{ display: "flex" }}>
            <div className="modal-content">
              <div className="modal-header">
                <h3>Lokale in {selectedBuilding.building_name} ({getTerrainName(selectedBuilding.location_id)})</h3>
                <span className="close" onClick={() => setShowRoomsModal(false)}>&times;</span>
              </div>
              <div className="modal-body">
                {getRoomsForBuilding(selectedBuilding.building_id).length > 0 ? (
                  <table className="standard-table">
                    <thead>
                      <tr>
                        <th>Naam</th>
                        <th>Kode</th>
                        <th>Tipe</th>
                        <th>Status</th>
                        <th>Kapasiteit</th>
                      </tr>
                    </thead>
                    <tbody>
                      {getRoomsForBuilding(selectedBuilding.building_id).map((room) => (
                        <tr key={room.room_id}>
                          <td>{room.room_name}</td>
                          <td>{room.room_code}</td>
                          <td>{translateRoomType(room.room_type || 'other')}</td>
                          <td>{room.room_status}</td>
                          <td>{room.room_capacity ?? '-'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                ) : (
                  <p>Geen lokale in hierdie gebou.</p>
                )}
              </div>
            </div>
          </div>
        )}
      </>
    );
  }

  return (
    <div style={{ display: "flex" }}>
      <Sidebar currentPath="/buildings" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Gebou Bestuur</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
          {pageContent}
        </div>
      </div>

      {showModal && modalContent}

      {showRoomsModal && selectedBuilding && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Lokale in {selectedBuilding.building_name} ({getTerrainName(selectedBuilding.location_id)})</h3>
              <span className="close" onClick={() => setShowRoomsModal(false)}>&times;</span>
            </div>
            <div className="modal-body">
              {getRoomsForBuilding(selectedBuilding.building_id).length > 0 ? (
                <table className="standard-table">
                  <thead>
                    <tr>
                      <th>Naam</th>
                      <th>Kode</th>
                      <th>Tipe</th>
                      <th>Status</th>
                      <th>Kapasiteit</th>
                    </tr>
                  </thead>
                  <tbody>
                    {getRoomsForBuilding(selectedBuilding.building_id).map((room) => (
                      <tr key={room.room_id}>
                        <td>{room.room_name}</td>
                        <td>{room.room_code}</td>
                        <td>{translateRoomType(room.room_type || 'other')}</td>
                        <td>{room.room_status}</td>
                        <td>{room.room_capacity ?? '-'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p>Geen lokale in hierdie gebou.</p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default BuildingsPage;