import React, { useState, useEffect, useRef, useMemo } from "react";
import { Link } from "react-router-dom";
import Select from "react-select";
import { renderBreadcrumb, CascadeControl, NoCloseControl, NoCloseDropdownIndicator } from "../components/controlHelpers";
import { buildingsAPI, locationAPI, roomsAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import ResizableTh from "../components/ResizableTh";
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import ImportExportModal from "../components/DataTransfer/ImportExportModal";
import '../styles/App.css';
import "../styles/Rooms.css";
import { buildFlatLocationOptions } from './locationSearchUtils';

function BuildingsPage({ embedded = false }) {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { user, hasRight } = useCurrentUser();
  const [buildings, setBuildings] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: null });
  const BUILDING_COLUMNS = [
    { key: 'id', label: 'ID', render: (b) => b.building_id, sortKey: 'id', defaultVisible: false },
    { key: 'name', label: 'Naam', render: (b) => b.building_name, sortKey: 'name', defaultVisible: true },
    { key: 'type', label: 'Tipe', render: (b) => translateBuildingType(b.building_type), sortKey: 'type', defaultVisible: true },
    { key: 'terrain', label: 'Terrein', render: (b) => getTerrainName(b.location_id), sortKey: 'terrain', defaultVisible: true },
  ];
  const colVis = useColumnVisibility('buildings-page', BUILDING_COLUMNS);
  const colWidths = useColumnWidths('buildings-page', BUILDING_COLUMNS);
  const colPickerRef = useRef(null);
  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, null, null), [terrains, buildings]);
  const [showModal, setShowModal] = useState(false);
  const [showImportWizard, setShowImportWizard] = useState(false);
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
      showToast({ type: 'error', title: 'Fout', message: "Fout tydens besparing. Probeer asseblief weer." });
    }
  };

  const handleDeleteBuilding = async (id) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie gebou verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' }); if (!confirmed) return;
    try {
      await buildingsAPI.delete(id);
      await fetchBuildings();
    } catch (error) {
      console.error("Error deleting building:", error);
      showToast({ type: 'error', title: 'Fout', message: "Fout tydens verwydering. Probeer asseblief weer." });
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
      if (!sortKey) return 0;
      const dir = sortDirection === 'asc' ? 1 : -1;
      if (sortKey === 'name') return String(a.building_name || '').localeCompare(String(b.building_name || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'type') return String(translateBuildingType(a.building_type)).localeCompare(String(translateBuildingType(b.building_type)), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'terrain') return String(getTerrainName(a.location_id)).localeCompare(String(getTerrainName(b.location_id)), 'af', { sensitivity: 'base' }) * dir;
      return 0;
    });

  // Opsies vir dropdowns
  const filterColumnOptions = [
    { value: "all", label: "Alle kolomme" },
    { value: "name", label: "Naam" },
    { value: "type", label: "Tipe" },
    { value: "terrain", label: "Terrein" }
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
    return <div className="main"><div className="content">Laai...</div></div>;
  }

  const pageContent = (
    <>
      <div className="controls">
        <div className="controls-left">
          <div className="control-input-shell">
            <input
              type="text"
              placeholder="Soek geboue..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <Select
            className="react-select-container"
            classNamePrefix="react-select"
            value={filterColumnOptions.find(o => o.value === filterColumn)}
            onChange={(selected) => setFilterColumn(selected ? selected.value : "all")}
            options={filterColumnOptions}
            isSearchable={false}
            components={{ Control: NoCloseControl, DropdownIndicator: NoCloseDropdownIndicator }}
            styles={{
              container: (base) => ({ ...base, minWidth: '160px' }),
              control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
              valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
              singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
            }}
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
            return (
              <div className="control-cascade-stack">
                <div className="control-cascade-breadcrumb">
                  {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 2 })}
                </div>
                  <Select
                    className="react-select-container"
                    classNamePrefix="react-select"
                    placeholder={["Kies Terrein...","Kies Gebou...","Filter voltooi"][cascadeCount]}
                    isClearable
                    isDisabled={cascadeCount >= 2}
                    closeMenuOnSelect={false}
                    components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} />, DropdownIndicator: NoCloseDropdownIndicator }}
                    styles={{
                      container: (base) => ({ ...base, minWidth: '260px' }),
                      control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                      valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                      singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                    }}
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
          <ColumnPicker
            ref={colPickerRef}
            columns={BUILDING_COLUMNS}
            visibleColumns={colVis.visibleColumns}
            toggleColumn={colVis.toggleColumn}
            resetVisibility={colVis.resetVisibility}
            onResetWidths={colWidths.resetWidths}
          />
          <button className="btn-add" onClick={handleNewBuilding}>+ Nuwe Gebou</button>
          {hasRight('buildings.manage') && (
            <button
              type="button"
              className="btn-add"
              style={{ marginLeft: '0.5rem' }}
              onClick={() => setShowImportWizard(true)}
            >
              ⇅ Invoer / Uitvoer rekords
            </button>
          )}
          {hasRight('buildings.manage') && (
            <ImportExportModal
              isOpen={showImportWizard}
              onClose={() => setShowImportWizard(false)}
              defaultEntity="building"
              onImported={fetchBuildings}
            />
          )}
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
            <th style={{ width: '200px' }}>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredBuildings.map((building) => (
            <tr key={building.building_id} onClick={() => handleEditBuilding(building)} style={{ cursor: "pointer" }}>
              {colVis.visibleColumns.map((col) => (
                <td key={col.key}>{col.render(building)}</td>
              ))}
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
              styles={{
                control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
              }}
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
               return (
                 <>
                   {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 1, marginTop: "6px", marginBottom: "6px" })}
                  <Select
                    className="react-select-container"
                    classNamePrefix="react-select"
                    placeholder={["Kies Terrein...","Ligging voltooi"][cascadeCount]}
                    isClearable
                    isDisabled={cascadeCount >= 1}
                    closeMenuOnSelect={false}
                    components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} /> }}
                    options={allLocationOptions}
                    styles={{
                      container: (base) => ({ ...base, minWidth: '260px' }),
                      control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                      valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                      singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                    }}
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
      {dialog}
    </div>
  );
}

export default BuildingsPage;