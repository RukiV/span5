import React, { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import Select from "react-select";
import { buildingsAPI, locationAPI } from "../services/api";
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import ResizableTh from "../components/ResizableTh";
import { useCurrentUser } from "../hooks/useCurrentUser";
import ImportExportModal from "../components/DataTransfer/ImportExportModal";
import '../styles/App.css';
import "../styles/Rooms.css";

function TerrainsPage({ embedded = false }) {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { hasRight } = useCurrentUser();
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: null });
  const TERRAIN_COLUMNS = [
    { key: 'id', label: 'ID Terrein', render: (t) => t.location_id, sortKey: 'id', defaultVisible: true },
    { key: 'name', label: 'Naam', render: (t) => t.location_name, sortKey: 'name', defaultVisible: true },
    { key: 'type', label: 'Tipe', render: (t) => t.location_type, sortKey: 'type', defaultVisible: true },
    { key: 'streetnum', label: 'Straatnommer', render: (t) => t.location_streetnum || '-', sortKey: 'streetnum', defaultVisible: true },
    { key: 'streetname', label: 'Straatnaam', render: (t) => t.location_streetname || '-', sortKey: 'streetname', defaultVisible: true },
    { key: 'suburb', label: 'Suburb', render: (t) => t.location_suburb || '-', sortKey: 'suburb', defaultVisible: true },
    { key: 'city', label: 'Stad', render: (t) => t.location_city || '-', sortKey: 'city', defaultVisible: true },
    { key: 'province', label: 'Provinsie', render: (t) => t.location_province || '-', sortKey: 'province', defaultVisible: true },
    { key: 'country', label: 'Land', render: (t) => t.location_country || '-', sortKey: 'country', defaultVisible: false },
  ];
  const colVis = useColumnVisibility('terrains-page', TERRAIN_COLUMNS);
  const colWidths = useColumnWidths('terrains-page', TERRAIN_COLUMNS);
  const colPickerRef = useRef(null);
  const [showModal, setShowModal] = useState(false);
  const [showImportWizard, setShowImportWizard] = useState(false);
  const [showBuildingsModal, setShowBuildingsModal] = useState(false);
  const [selectedTerrain, setSelectedTerrain] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [newTerrain, setNewTerrain] = useState({
    location_name: "",
    location_type: "",
    location_streetnum: "",
    location_streetname: "",
    location_suburb: "",
    location_city: "",
    location_province: "",
    location_country: "",
  });
  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});

  useEffect(() => {
    fetchTerrains();
    fetchBuildings();
  }, []);

  const fetchTerrains = async () => {
    try {
      const response = await locationAPI.getAll();
      setTerrains(response.data);
    } catch (error) {
      console.error("Error fetching terrains:", error);
    } finally {
      setLoading(false);
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

  const handleSaveTerrain = async () => {
    try {
      const errors = {};
      if (!newTerrain.location_name.trim()) errors.location_name = true;
      if (!newTerrain.location_type.trim()) errors.location_type = true;
      if (!newTerrain.location_streetnum.trim()) errors.location_streetnum = true;
      if (!newTerrain.location_streetname.trim()) errors.location_streetname = true;
      if (!newTerrain.location_suburb.trim()) errors.location_suburb = true;
      if (!newTerrain.location_city.trim()) errors.location_city = true;
      if (!newTerrain.location_province.trim()) errors.location_province = true;
      if (!newTerrain.location_country.trim()) errors.location_country = true;
      if (Object.keys(errors).length > 0) {
        setInvalidFields(errors);
        const firstKey = Object.keys(errors)[0];
        fieldRefs.current[firstKey]?.scrollIntoView({ behavior: "smooth", block: "center" });
        fieldRefs.current[firstKey]?.focus();
        return;
      }
      setInvalidFields({});

      const terrainData = {
        location_name: newTerrain.location_name,
        location_type: newTerrain.location_type,
        location_streetnum: newTerrain.location_streetnum,
        location_streetname: newTerrain.location_streetname,
        location_suburb: newTerrain.location_suburb || null,
        location_city: newTerrain.location_city || null,
        location_province: newTerrain.location_province || null,
        location_country: newTerrain.location_country || null,
      };

      if (isEditing) {
        await locationAPI.update(editingId, terrainData);
      } else {
        await locationAPI.create(terrainData);
      }

      handleCloseModal();
      fetchTerrains();
    } catch (error) {
      console.error("Error saving terrain:", error);
      showToast({ type: 'error', title: 'Fout', message: "Fout tydens besparing. Probeer asseblief weer." });
    }
  };

  const handleDeleteTerrain = async (id) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie terrein verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' }); if (!confirmed) return;
    try {
      await locationAPI.delete(id);
      fetchTerrains();
    } catch (error) {
      console.error("Error deleting terrain:", error);
      showToast({ type: 'error', title: 'Fout', message: "Fout tydens verwydering. Probeer asseblief weer." });
    }
  };

  const handleViewBuildings = (terrain) => {
    setSelectedTerrain(terrain);
    setShowBuildingsModal(true);
  };

  const getBuildingsForTerrain = (locationId) => buildings.filter((b) => b.location_id === locationId);

  const translateBuildingType = (type) => {
    const translations = {
      admin: "Admin",
      onderwys: "Onderwys",
      laboratory: "Laboratorium",
      warehouse: "Pakhuis",
      other: "Ander",
    };
    return translations[type] || type;
  };

  const handleEditTerrain = (item) => {
    setIsEditing(true);
    setEditingId(item.location_id);
    setNewTerrain({
      location_name: item.location_name || "",
      location_type: item.location_type || "",
      location_streetnum: item.location_streetnum || "",
      location_streetname: item.location_streetname || "",
      location_suburb: item.location_suburb || "",
      location_city: item.location_city || "",
      location_province: item.location_province || "",
      location_country: item.location_country || "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewTerrain({ location_name: "", location_type: "", location_streetnum: "", location_streetname: "", location_suburb: "", location_city: "", location_province: "", location_country: "" });
  };

  const handleNewTerrain = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewTerrain({ location_name: "", location_type: "", location_streetnum: "", location_streetname: "", location_suburb: "", location_city: "", location_province: "", location_country: "" });
    setShowModal(true);
  };

  const filteredTerrains = [...terrains]
    .filter((terrain) => {
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        id: terrain.location_id,
        name: terrain.location_name,
        type: terrain.location_type,
        streetnum: terrain.location_streetnum,
        streetname: terrain.location_streetname,
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (!sortKey) return 0;
      const dir = sortDirection === 'asc' ? 1 : -1;
      if (sortKey === 'id') return (Number(a.location_id || 0) - Number(b.location_id || 0)) * dir;
      if (sortKey === 'name') return String(a.location_name || '').localeCompare(String(b.location_name || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'type') return String(a.location_type || '').localeCompare(String(b.location_type || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'streetnum') return String(a.location_streetnum || '').localeCompare(String(b.location_streetnum || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'streetname') return String(a.location_streetname || '').localeCompare(String(b.location_streetname || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'suburb') return String(a.location_suburb || '').localeCompare(String(b.location_suburb || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'city') return String(a.location_city || '').localeCompare(String(b.location_city || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'province') return String(a.location_province || '').localeCompare(String(b.location_province || ''), 'af', { sensitivity: 'base' }) * dir;
      return 0;
    });

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
              placeholder="Soek terreine..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <Select
            className="react-select-container"
            classNamePrefix="react-select"
            value={[
              { value: "all", label: "Alle kolomme" },
              { value: "id", label: "ID" },
              { value: "name", label: "Naam" },
              { value: "type", label: "Tipe" },
              { value: "streetnum", label: "Straatnommer" },
              { value: "streetname", label: "Straatnaam" },
            ].find((option) => option.value === filterColumn)}
            onChange={(selected) => setFilterColumn(selected?.value || "all")}
            options={[
              { value: "all", label: "Alle kolomme" },
              { value: "id", label: "ID" },
              { value: "name", label: "Naam" },
              { value: "type", label: "Tipe" },
              { value: "streetnum", label: "Straatnommer" },
              { value: "streetname", label: "Straatnaam" },
            ]}
            isSearchable={false}
          />
        </div>
        <div className="controls-right">
          <ColumnPicker ref={colPickerRef} columns={colVis.columnDefs} visibleColumns={colVis.visibleColumns.map(c => c)} toggleColumn={colVis.toggleColumn} resetVisibility={colVis.resetVisibility} onResetWidths={colWidths.resetWidths} />
          <button className="btn-add" onClick={handleNewTerrain}>+ Nuwe Terrein</button>
          {hasRight('locations.manage') && (
            <button
              type="button"
              className="btn-add"
              style={{ marginLeft: '0.5rem' }}
              onClick={() => setShowImportWizard(true)}
            >
              ⇅ Invoer / Uitvoer rekords
            </button>
          )}
          {hasRight('locations.manage') && (
            <ImportExportModal
              isOpen={showImportWizard}
              onClose={() => setShowImportWizard(false)}
              defaultEntity="location"
              onImported={() => { fetchTerrains(); fetchBuildings(); }}
            />
          )}
        </div>
      </div>

      <table className="standard-table">
        <thead>
          <tr>
            {colVis.visibleColumns.map((col) => (
              <ResizableTh key={col.key} col={col} colWidths={colWidths} className={getSortClass(col.sortKey)} onClick={() => handleSort(col.sortKey)} onContextMenu={(e) => { e.preventDefault(); colPickerRef.current?.openAt(e); }}>
                {col.label}{getSortIndicator(col.sortKey)}
              </ResizableTh>
            ))}
            <th>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredTerrains.length === 0 ? (
            <tr>
              <td colSpan={colVis.visibleColumns.length + 1} style={{ textAlign: 'center', padding: '20px' }}>
                Geen terreine gevind
              </td>
            </tr>
          ) : (
            filteredTerrains.map((terrain) => (
              <tr key={terrain.location_id} onClick={() => handleEditTerrain(terrain)} style={{ cursor: "pointer" }}>
                {colVis.visibleColumns.map((col) => (
                  <td key={col.key}>{col.render(terrain)}</td>
                ))}
                <td onClick={e => e.stopPropagation()}>
                  <button className="btn-view" onClick={() => handleViewBuildings(terrain)}>Besigtig Geboue</button>
                  <button className="btn-delete" onClick={() => handleDeleteTerrain(terrain.location_id)}>Verwyder</button>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </>
  );

  const modalContent = (
    <div className="modal" style={{ display: "flex" }}>
      <div className="modal-content">
        <div className="modal-header">
          <h3>{isEditing ? "Wysig" : "Nuwe"} Terrein {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
          <span className="close" onClick={handleCloseModal}>&times;</span>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Naam *</label>
            <input
              ref={el => fieldRefs.current.location_name = el}
              type="text"
              className={invalidFields.location_name ? "field-invalid" : ""}
              value={newTerrain.location_name}
              onChange={(e) => {
                setNewTerrain({ ...newTerrain, location_name: e.target.value });
                setInvalidFields(p => { const n = {...p}; delete n.location_name; return n; });
              }}
            />
          </div>
          <div className="input-group">
            <label>Tipe *</label>
            <input
              ref={el => fieldRefs.current.location_type = el}
              type="text"
              className={invalidFields.location_type ? "field-invalid" : ""}
              value={newTerrain.location_type}
              onChange={(e) => {
                setNewTerrain({ ...newTerrain, location_type: e.target.value });
                setInvalidFields(p => { const n = {...p}; delete n.location_type; return n; });
              }}
            />
          </div>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Straatnommer *</label>
            <input
              ref={el => fieldRefs.current.location_streetnum = el}
              type="text"
              className={invalidFields.location_streetnum ? "field-invalid" : ""}
              value={newTerrain.location_streetnum}
              onChange={(e) => {
                setNewTerrain({ ...newTerrain, location_streetnum: e.target.value });
                setInvalidFields(p => { const n = {...p}; delete n.location_streetnum; return n; });
              }}
            />
          </div>
          <div className="input-group">
            <label>Straatnaam *</label>
            <input
              ref={el => fieldRefs.current.location_streetname = el}
              type="text"
              className={invalidFields.location_streetname ? "field-invalid" : ""}
              value={newTerrain.location_streetname}
              onChange={(e) => {
                setNewTerrain({ ...newTerrain, location_streetname: e.target.value });
                setInvalidFields(p => { const n = {...p}; delete n.location_streetname; return n; });
              }}
            />
          </div>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Suburb *</label>
            <input
              ref={el => fieldRefs.current.location_suburb = el}
              type="text"
              className={invalidFields.location_suburb ? "field-invalid" : ""}
              value={newTerrain.location_suburb}
              onChange={(e) => {
                setNewTerrain({ ...newTerrain, location_suburb: e.target.value });
                setInvalidFields(p => { const n = {...p}; delete n.location_suburb; return n; });
              }}
            />
          </div>
          <div className="input-group">
            <label>Stad *</label>
            <input
              ref={el => fieldRefs.current.location_city = el}
              type="text"
              className={invalidFields.location_city ? "field-invalid" : ""}
              value={newTerrain.location_city}
              onChange={(e) => {
                setNewTerrain({ ...newTerrain, location_city: e.target.value });
                setInvalidFields(p => { const n = {...p}; delete n.location_city; return n; });
              }}
            />
          </div>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Provinsie *</label>
            <input
              ref={el => fieldRefs.current.location_province = el}
              type="text"
              className={invalidFields.location_province ? "field-invalid" : ""}
              value={newTerrain.location_province}
              onChange={(e) => {
                setNewTerrain({ ...newTerrain, location_province: e.target.value });
                setInvalidFields(p => { const n = {...p}; delete n.location_province; return n; });
              }}
            />
          </div>
          <div className="input-group">
            <label>Land *</label>
            <input
              ref={el => fieldRefs.current.location_country = el}
              type="text"
              className={invalidFields.location_country ? "field-invalid" : ""}
              value={newTerrain.location_country}
              onChange={(e) => {
                setNewTerrain({ ...newTerrain, location_country: e.target.value });
                setInvalidFields(p => { const n = {...p}; delete n.location_country; return n; });
              }}
            />
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
          <button className="btn-add" onClick={handleSaveTerrain}>{isEditing ? "Opdateer" : "Stoor"}</button>
        </div>
      </div>
    </div>
  );

  if (embedded) {
    return (
      <>
        {pageContent}

        {showModal && modalContent}

        {showBuildingsModal && selectedTerrain && (
          <div className="modal" style={{ display: "flex" }}>
            <div className="modal-content">
              <div className="modal-header">
                <h3>Geboue in {selectedTerrain.location_name}</h3>
                <span className="close" onClick={() => setShowBuildingsModal(false)}>&times;</span>
              </div>
              <div className="modal-body">
                {getBuildingsForTerrain(selectedTerrain.location_id).length > 0 ? (
                  <table className="standard-table">
                    <thead>
                      <tr>
                        <th>Naam</th>
                        <th>Tipe</th>
                      </tr>
                    </thead>
                    <tbody>
                      {getBuildingsForTerrain(selectedTerrain.location_id).map((building) => (
                        <tr key={building.building_id}>
                          <td>{building.building_name}</td>
                          <td>{translateBuildingType(building.building_type)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                ) : (
                  <p>Geen geboue op hierdie terrein.</p>
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
      {showBuildingsModal && selectedTerrain && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Geboue in {selectedTerrain.location_name}</h3>
              <span className="close" onClick={() => setShowBuildingsModal(false)}>&times;</span>
            </div>
            <div className="modal-body">
              {getBuildingsForTerrain(selectedTerrain.location_id).length > 0 ? (
                <table className="standard-table">
                  <thead>
                    <tr>
                      <th>Naam</th>
                      <th>Tipe</th>
                    </tr>
                  </thead>
                  <tbody>
                    {getBuildingsForTerrain(selectedTerrain.location_id).map((building) => (
                      <tr key={building.building_id}>
                        <td>{building.building_name}</td>
                        <td>{translateBuildingType(building.building_type)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p>Geen geboue op hierdie terrein.</p>
              )}
            </div>
          </div>
        </div>
      )}
      {dialog}
    </div>
  );
}

export default TerrainsPage;
