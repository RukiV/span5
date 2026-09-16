import React, { useState, useEffect, useRef, useMemo } from "react";
import { Link, useNavigate, useLocation } from "react-router-dom";
import Select from "react-select";
import { IoTrashOutline, IoPencil } from "react-icons/io5";
import { renderBreadcrumb, CascadeControl, CascadeIndicatorsContainer, NoCascadeClearIndicator } from "../components/controlHelpers";
import useCascadeMenu from "../hooks/useCascadeMenu";
import { buildingsAPI, locationAPI, roomsAPI, assetsAPI, stockAPI, ticketsAPI, workOrdersAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import useColumnSort from "../hooks/useColumnSort";
import useFilterState from "../hooks/useFilterState";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import SortPicker from "../components/ColumnPicker/SortPicker";
import FilterPicker from "../components/ColumnPicker/FilterPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import usePagination from "../hooks/usePagination";
import Pagination from "../components/Pagination/Pagination";
import ResizableTh from "../components/ResizableTh";
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import { useMoveChildren } from '../components/Modal/useMoveChildren';
import ImportExportModal from "../components/DataTransfer/ImportExportModal";
import { getDeleteErrorMessage, chooseDeleteStrategy, batchDelete } from "../utils/deleteUtils";
import '../styles/App.css';
import "../styles/Rooms.css";
import { buildFlatLocationOptions } from './locationSearchUtils';
import Modal from '../components/Modal/Modal';
import BuildingDetailView from '../components/DetailView/BuildingDetailView';
import useAiSuggestions from "../hooks/useAiSuggestions";
import AiSuggestPanel from "../components/AiSuggestPanel";
import '../components/DetailView/DetailView.css';

function BuildingsPage({ embedded = false }) {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { openMoveChildren, moveChildrenDialog } = useMoveChildren();
  const { user, hasRight } = useCurrentUser();
  const [buildings, setBuildings] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [assets, setAssets] = useState([]);
  const [stock, setStock] = useState([]);
  const [faults, setFaults] = useState([]);
  const [jobs, setJobs] = useState([]);
  const [loading, setLoading] = useState(true);
  const filterPersist = useFilterState({ storageKey: "buildings-page" });
  const [searchTerm, setSearchTerm] = useState(() => filterPersist.value.search);
  const [filterColumn, setFilterColumn] = useState("all");
  const BUILDING_COLUMNS = [
    { key: 'id', label: 'ID', render: (b) => b.building_id, sortKey: 'id', defaultVisible: false },
    { key: 'name', label: 'Naam', render: (b) => b.building_name, sortKey: 'name', defaultVisible: true },
    { key: 'type', label: 'Tipe', render: (b) => formatBuildingTypes(b), sortKey: 'type', defaultVisible: true },
    { key: 'terrain', label: 'Terrein', render: (b) => getTerrainName(b.location_id), sortKey: 'terrain', defaultVisible: true },
  ];
  const colVis = useColumnVisibility('buildings-page', BUILDING_COLUMNS);
  const colWidths = useColumnWidths('buildings-page', BUILDING_COLUMNS);
  const { sorts, addSort, removeSort, toggleDirection, moveSort, clearSorts, applySort } = useColumnSort({
    columns: BUILDING_COLUMNS,
    storageKey: 'buildings-page',
  });
  const colPickerRef = useRef(null);
  const [terrainFilter, setTerrainFilter] = useState(() => filterPersist.value.location_id);
  const [buildingFilter, setBuildingFilter] = useState(() => filterPersist.value.building_id);
  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, null, null), [terrains, buildings]);
  const modalCascadeMenu = useCascadeMenu();
  const navigate = useNavigate();
  const location = useLocation();
  const [showModal, setShowModal] = useState(false);
  const [showImportWizard, setShowImportWizard] = useState(false);
  const [showRoomsModal, setShowRoomsModal] = useState(false);
  const [selectedBuilding, setSelectedBuilding] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [isViewMode, setIsViewMode] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const newBuildingDefault = { building_name: "", building_types: [], location_id: "" };
  const [newBuilding, setNewBuilding] = useState(newBuildingDefault);
  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});
  const buildingSuggestions = useAiSuggestions({
    context: 'building',
    values: { building_name: newBuilding.building_name, building_types: newBuilding.building_types },
    enabled: showModal && !isViewMode,
  });

  const translateBuildingType = (type) => {
    const translations = {
      "Kantoorgebou": "Admin",
      "Onderwys": "Onderwys",
      "Laboratorium": "Laboratorium",
      "warehouse": "Pakhuis",
      "Kafeteria": "Kafeteria",
      "Koshuis": "Koshuis",
      "Ander": "Ander",
    };
    return translations[type] || type;
  };

  const formatBuildingTypes = (building) => {
    const types = Array.isArray(building?.building_types)
      ? building.building_types
      : building?.building_type
        ? [building.building_type]
        : [];
    return types.map(translateBuildingType).join(", ") || "Ander";
  };

  useEffect(() => {
    const loadData = async () => {
      await Promise.all([fetchBuildings(), fetchTerrains(), fetchRooms(), fetchAssets(), fetchStock(), fetchFaults(), fetchJobs()]);
    };
    loadData();
  }, []);

  useEffect(() => {
    if (location.state?.building) {
      const target = buildings.find((b) => String(b.building_id) === String(location.state.building.building_id));
      if (target) handleEditBuilding(target);
    }
  }, [location.state?.building, buildings]);

  useEffect(() => {
    if (user?.role_id === 2 && user?.location_id) {
      setTerrainFilter(String(user.location_id));
    } else {
      setTerrainFilter("");
    }
  }, [user]);

  useEffect(() => {
    filterPersist.set({
      search: searchTerm,
      location_id: terrainFilter,
      building_id: buildingFilter,
      room_id: "",
      status: "",
    });
  }, [filterPersist, searchTerm, terrainFilter, buildingFilter]);

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

  const fetchAssets = async () => {
    try {
      const response = await assetsAPI.getAll();
      setAssets(response.data || []);
    } catch (error) {
      console.error("Error fetching assets:", error);
    }
  };

  const fetchStock = async () => {
    try {
      const response = await stockAPI.getAll();
      setStock(response.data || []);
    } catch (error) {
      console.error("Error fetching stock:", error);
    }
  };

  const fetchFaults = async () => {
    try {
      const response = await ticketsAPI.getAll();
      setFaults(response.data || []);
    } catch (error) {
      console.error("Error fetching faults:", error);
    }
  };

  const fetchJobs = async () => {
    try {
      const response = await workOrdersAPI.getAll();
      setJobs(response.data || []);
    } catch (error) {
      console.error("Error fetching jobs:", error);
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
    if (!newBuilding.building_types || newBuilding.building_types.length === 0) errors.building_types = true;
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
      building_types: newBuilding.building_types,
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
    const children = getRoomsForBuilding(id);
    const roomIds = new Set(children.map((r) => r.room_id));
    const assetsInSubtree = assets.filter((a) => roomIds.has(a.room_id));
    const stockInSubtree = stock.filter((s) => roomIds.has(s.room_id));
    const assetIds = new Set(assetsInSubtree.map((a) => a.asset_id));
    const faultsInSubtree = faults.filter((f) => f.building_id === id || roomIds.has(f.room_id) || (f.asset_id && assetIds.has(f.asset_id)));
    const faultIds = new Set(faultsInSubtree.map((f) => f.fault_id));
    const jobsInSubtree = jobs.filter((j) => j.building_id === id || roomIds.has(j.room_id) || (j.asset_id && assetIds.has(j.asset_id)) || (j.fault_id && faultIds.has(j.fault_id)));
    const hasContent = assetsInSubtree.length + stockInSubtree.length > 0;
    const strategy = await chooseDeleteStrategy(confirm, {
      entityLabel: "gebou",
      childrenLabel: "lokale",
      hasChildren: children.length > 0,
      hasContent,
      counts: {
        lokale: children.length,
        bates: assetsInSubtree.length,
        voorraad: stockInSubtree.length,
        foutkaartjies: faultsInSubtree.length,
        werksopdragte: jobsInSubtree.length,
      },
      directChildrenLabel: 'lokale',
      parentLevelLabel: 'gebou',
    });
    if (!strategy) return;

    try {
      if (strategy === 'move') {
        const targetOptions = buildings
          .filter((b) => b.building_id !== id)
          .map((b) => ({ value: b.building_id, label: b.building_name }));
        const assignments = await openMoveChildren({
          mode: 'individual',
          title: `Skuif lokale van "${buildings.find((b) => b.building_id === id)?.building_name || ''}"`,
          children: children.map((r) => ({ id: r.room_id, label: r.room_name })),
          parentOptions: targetOptions,
          parentLabel: 'verwyder',
          confirmLabel: 'Skuif en verwyder gebou',
        });
        if (assignments === false) return;
        for (const child of children) {
          const target = assignments[child.room_id];
          if (target != null) {
            await roomsAPI.update(child.room_id, { building_id: Number(target) });
          }
        }
      } else if (strategy === 'moveContent') {
        const targetRooms = rooms.filter((r) => !roomIds.has(r.room_id));
        const parentOptions = targetRooms.map((r) => {
          const b = buildings.find((bb) => bb.building_id === r.building_id);
          const label = b ? `${r.room_name} — ${b.building_name}` : r.room_name;
          return { value: r.room_id, label };
        });
        const groups = [];
        const lookup = {};
        const buildingLabel = buildings.find((b) => b.building_id === id)?.building_name || `Gebou ${id}`;
        for (const room of children) {
          const batesInRoom = assets.filter((a) => a.room_id === room.room_id);
          const stockInRoom = stock.filter((s) => s.room_id === room.room_id);
          if (batesInRoom.length === 0 && stockInRoom.length === 0) continue;
          const items = [];
          for (const a of batesInRoom) {
            const sid = `a_${a.asset_id}`;
            items.push({ id: sid, label: `Bate: ${a.asset_name || a.asset_serial || `Bate #${a.asset_id}`}` });
            lookup[sid] = { kind: 'asset', realId: a.asset_id };
          }
          for (const s of stockInRoom) {
            const sid = `s_${s.stock_id}`;
            items.push({ id: sid, label: `Voorraad: ${s.stock_name || s.stock_type || `Voorraad #${s.stock_id}`}` });
            lookup[sid] = { kind: 'stock', realId: s.stock_id };
          }
          groups.push({
            id: `room_${room.room_id}`,
            label: room.room_name,
            buildingId: id,
            buildingLabel,
            items,
          });
        }
        if (groups.length > 0) {
          const assignments = await openMoveChildren({
            mode: 'grouped',
            title: `Skuif bates en voorraad van "${buildingLabel}"`,
            groups,
            parentOptions,
            parentLabel: 'verwyder',
            childrenHeader: 'Bates en voorraad volgens lokaal (sleep per lokaal of individueel)',
            confirmLabel: 'Skuif en verwyder gebou',
          });
          if (assignments === false) return;
          for (const [syntheticId, target] of Object.entries(assignments)) {
            if (target == null) continue;
            const rec = lookup[syntheticId];
            if (!rec) continue;
            if (rec.kind === 'asset') {
              await assetsAPI.update(rec.realId, { room_id: Number(target) });
            } else {
              await stockAPI.update(rec.realId, { room_id: Number(target) });
            }
          }
        }
      }
      await buildingsAPI.delete(id);
      await fetchBuildings();
    } catch (error) {
      console.error("Error deleting building:", error);
      showToast({ type: 'error', title: 'Fout', message: getDeleteErrorMessage(error, "Fout tydens verwydering. Probeer asseblief weer.") });
    }
  };

  const [selectedIds, setSelectedIds] = useState([]);
  const toggleOne = (id) => {
    setSelectedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };
  const handleDeleteSelected = () => {
    batchDelete({
      ids: selectedIds,
      apiDelete: buildingsAPI.delete,
      confirm,
      showToast,
      entityLabel: "geboue",
      childrenLabel: "lokale",
      refresh: fetchBuildings,
      errorFallback: "Fout tydens verwydering. Probeer asseblief weer.",
    }).then(() => setSelectedIds([]));
  };

  const handleEditBuilding = (item) => {
    setIsEditing(true);
    setIsViewMode(true);
    setEditingId(item.building_id);
    setNewBuilding({
      building_name: item.building_name || "",
      building_types: Array.isArray(item.building_types) ? item.building_types : (item.building_type ? [item.building_type] : []),
      location_id: item.location_id || "",
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setIsViewMode(false);
    setEditingId(null);
    setNewBuilding(newBuildingDefault);
  };

  const handleNewBuilding = () => {
    setIsEditing(false);
    setIsViewMode(false);
    setEditingId(null);
    setNewBuilding(newBuildingDefault);
    setShowModal(true);
  };

  const handleViewRooms = (building) => {
    setSelectedBuilding(building);
    setShowRoomsModal(true);
  };

  const filteredBuildings = applySort([...buildings]
    .filter((building) => {
      if (terrainFilter && String(building.location_id) !== String(terrainFilter)) return false;
      if (buildingFilter && String(building.building_id) !== String(buildingFilter)) return false;
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        id: building.building_id,
        name: building.building_name,
        type: formatBuildingTypes(building),
        terrain: getTerrainName(building.location_id),
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    }),
    (b, key) => {
      switch (key) {
        case 'id': return Number(b.building_id || 0);
        case 'name': return String(b.building_name || '');
        case 'type': return String(formatBuildingTypes(b) || '');
        case 'terrain': return String(getTerrainName(b.location_id) || '');
        default: return '';
      }
    },
  );
    const { currentPage, totalPages, paginatedData: paginatedBuildings, goToPage } = usePagination(filteredBuildings, 100);
  useEffect(() => { goToPage(1); }, [searchTerm, filterColumn, terrainFilter, buildingFilter, sorts, goToPage]);
  const allSelected = paginatedBuildings.length > 0 && paginatedBuildings.every((x) => selectedIds.includes(x.building_id));
  const toggleAll = () => {
    if (allSelected) {
      const pageIds = new Set(paginatedBuildings.map((x) => x.building_id));
      setSelectedIds((prev) => prev.filter((id) => !pageIds.has(id)));
    } else {
      const pageIds = paginatedBuildings.map((x) => x.building_id);
      setSelectedIds((prev) => [...new Set([...prev, ...pageIds])]);
    }
  };

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
    { value: "Koshuis", label: "Koshuis" },
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
      <div className="controls controls--sticky">
        <div className="controls-left">
          <div className="control-input-shell">
            <input
              type="text"
              placeholder="Soek geboue..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <FilterPicker
            search={searchTerm}
            onSearch={setSearchTerm}
            filterColumn={filterColumn}
            onFilterColumnChange={setFilterColumn}
            filterColumnOptions={filterColumnOptions}
            terrainFilter={terrainFilter}
            buildingFilter={buildingFilter}
            roomFilter=""
            onLocationChange={(loc, bld) => {
              setTerrainFilter(loc || "");
              setBuildingFilter(bld || "");
            }}
            locationOptions={allLocationOptions}
            maxLevel={2}
            lockedTerrain={user?.role_id === 2 ? String(user?.location_id || "") : null}
            onReset={() => {
              setSearchTerm("");
              setTerrainFilter("");
              setBuildingFilter("");
            }}
          />
        <SortPicker
            columns={BUILDING_COLUMNS}
            sorts={sorts}
            onAdd={addSort}
            onRemove={removeSort}
            onToggleDirection={toggleDirection}
            onMove={moveSort}
            onClear={clearSorts}
          />
          <ColumnPicker
            ref={colPickerRef}
            columns={BUILDING_COLUMNS}
            visibleColumns={colVis.visibleColumns}
            toggleColumn={colVis.toggleColumn}
            resetVisibility={colVis.resetVisibility}
            onResetWidths={colWidths.resetWidths}
          />
        </div>
        <div className="controls-right">
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
          <button className="btn-add" onClick={handleNewBuilding}>+ Nuwe Gebou</button>
          {selectedIds.length > 0 && (
            <button className="btn-delete" style={{ marginLeft: '0.5rem' }} onClick={handleDeleteSelected}>
              Verwyder Geselekteerde ({selectedIds.length})
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
            <th style={{ width: '230px' }}>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {paginatedBuildings.map((building) => (
            <tr key={building.building_id} onClick={() => handleEditBuilding(building)} style={{ cursor: "pointer" }}>
              <td style={{ textAlign: 'center' }} onClick={e => e.stopPropagation()}>
                <input type="checkbox" checked={selectedIds.includes(building.building_id)} onChange={() => toggleOne(building.building_id)} />
              </td>
              {colVis.visibleColumns.map((col) => (
                <td key={col.key}>{col.render(building)}</td>
              ))}
              <td onClick={e => e.stopPropagation()}>
                <button className="btn-view" onClick={() => handleViewRooms(building)}>Besigtig Lokale</button>
                <button className="btn-delete" title="Verwyder" onClick={() => handleDeleteBuilding(building.building_id)}><IoTrashOutline size={18} /></button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} totalItems={filteredBuildings.length} pageSize={100} />
    </>
  );

  const modalContent = (
    <div className="modal" style={{ display: "flex" }} onClick={(e) => { if (e.target === e.currentTarget && isViewMode) handleCloseModal(); }}>
      <div className="modal-content">
        <div className="modal-header">
          <h3>{isViewMode ? "Bekyk" : isEditing ? "Wysig" : "Nuwe"} Gebou {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
          <div className="modal-header-actions">
            {isEditing && isViewMode && hasRight('buildings.manage') && (
              <IoPencil size={20} className="modal-edit-btn" onClick={() => setIsViewMode(false)} title="Wysig" />
            )}
            <span className="close" onClick={handleCloseModal}>&times;</span>
          </div>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Naam *</label>
            <input
              type="text"
              ref={el => fieldRefs.current.building_name = el}
              className={invalidFields.building_name ? "field-invalid" : ""}
              value={newBuilding.building_name}
              disabled={isViewMode}
              onChange={(e) => {
                setNewBuilding({ ...newBuilding, building_name: e.target.value });
                if (invalidFields.building_name) setInvalidFields(prev => { const n = { ...prev }; delete n.building_name; return n; });
              }}
            />
          </div>
        </div>
        <div className="input-row">
          <div className={invalidFields.building_types ? "input-group field-invalid building-types-picker" : "input-group building-types-picker"}>
            <label>Tipes</label>
            <Select
              className="basic-single"
              classNamePrefix="select"
              isMulti
              maxMenuHeight={180}
              value={buildingTypeOptions.filter(o => newBuilding.building_types.includes(o.value))}
              onChange={(selected) => setNewBuilding({ ...newBuilding, building_types: selected ? selected.map(o => o.value) : [] })}
              options={buildingTypeOptions}
              isSearchable={false}
              isDisabled={isViewMode}
              placeholder="Kies een of meer tipes..."
              styles={{
                control: (base) => ({ ...base, minHeight: '40px', alignItems: 'center' }),
                valueContainer: (base) => ({ ...base, display: 'flex', alignItems: 'center', flexWrap: 'wrap' }),
              }}
            />
          </div>
        </div>
        <div className="input-row">
          <div className={invalidFields.location_id ? "input-group field-invalid" : "input-group"} style={{ position: "relative" }}>
            <label>Terrein *</label>
            {(() => {
              const cascadeCount = [newBuilding.location_id].filter(Boolean).length;
              const currentDisplayValue = cascadeCount === 0 ? null
                : cascadeCount === 1 && newBuilding.location_id ? { value: newBuilding.location_id, label: terrains?.find(t => String(t.location_id) === String(newBuilding.location_id))?.location_name || newBuilding.location_id }
                : null;
              const clearFromLevel = (levelIndex) => {
                if (levelIndex <= 0) setNewBuilding(p => ({...p, location_id: ""}));
              };
              const breadcrumbData = [{ level: -1, name: "Terreine" }];
              if (newBuilding.location_id) breadcrumbData.push({ level: 0, name: terrains?.find(t => String(t.location_id) === String(newBuilding.location_id))?.location_name || newBuilding.location_id });
               return (
                 <div ref={modalCascadeMenu.containerRef}>
                   {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 1, marginTop: "6px", marginBottom: "6px", disabled: isViewMode })}
                  <Select
                    className="react-select-container"
                    classNamePrefix="react-select"
                    placeholder={["Kies Terrein...","Ligging voltooi"][cascadeCount]}
                    isClearable
                    isDisabled={isViewMode || cascadeCount >= 1}
                    closeMenuOnSelect={false}
                    menuIsOpen={modalCascadeMenu.menuIsOpen}
                    onMenuOpen={modalCascadeMenu.onMenuOpen}
                    onMenuClose={modalCascadeMenu.onMenuClose}
                    components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} disabled={isViewMode} />, IndicatorsContainer: (p) => <CascadeIndicatorsContainer {...p} disabled={isViewMode} />, ClearIndicator: NoCascadeClearIndicator }}
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
                    value={currentDisplayValue}
                    onChange={(selectedOption) => {
                      if (!selectedOption) { setNewBuilding(p => ({...p, location_id: ""})); return; }
                      setNewBuilding(p => ({...p, ...selectedOption._fields}));
                      if (invalidFields.location_id) setInvalidFields(prev => { const n = {...prev}; delete n.location_id; return n; });
                    }}
                  />
                 </div>
               );
            })()}
          </div>
        </div>
        {!isViewMode && (
        <div className="modal-footer">
          <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
          <button className="btn-add" onClick={handleSaveBuilding}>{isEditing ? "Opdateer" : "Stoor"}</button>
        </div>
        )}
        <AiSuggestPanel
          suggestions={buildingSuggestions.suggestions}
          loading={buildingSuggestions.loading}
          filled={buildingSuggestions.filled}
          error={buildingSuggestions.error}
          labels={{ building_types: 'Gebou tipe' }}
          onUse={(key, suggestion) => {
            if (key === 'building_types' && Array.isArray(suggestion.value)) {
              setNewBuilding((previous) => ({ ...previous, building_types: suggestion.value }));
            }
          }}
        />
      </div>
    </div>
  );

  if (embedded) {
    return (
      <>
        {pageContent}

        {showModal && isViewMode && isEditing && (
          <Modal
            isOpen={true}
            onClose={handleCloseModal}
            title={`Bekyk Gebou`}
            size="md"
            headerActions={
              hasRight('buildings.manage') ? (
                <IoPencil size={20} className="modal-edit-btn" onClick={() => setIsViewMode(false)} title="Wysig" />
              ) : null
            }
          >
            <BuildingDetailView
              building={newBuilding}
              terrainName={terrains.find(t => String(t.location_id) === String(newBuilding.location_id))?.location_name}
              rooms={rooms}
              onNavigateToRoom={(r) => {
                handleCloseModal();
                navigate('/rooms', { state: { room: r } });
              }}
            />
          </Modal>
        )}

        {showModal && !isViewMode && modalContent}

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
                        <tr key={room.room_id} onClick={() => navigate('/rooms', { state: { room } })} style={{ cursor: 'pointer' }}>
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
      {moveChildrenDialog}
      </>
    );
  }

  return (
    <div className="main">
      <div className="content">
        {pageContent}
      </div>

      {showModal && isViewMode && isEditing && (
        <Modal
          isOpen={true}
          onClose={handleCloseModal}
          title={`Bekyk Gebou`}
          size="md"
          headerActions={
            hasRight('buildings.manage') ? (
              <IoPencil size={20} className="modal-edit-btn" onClick={() => setIsViewMode(false)} title="Wysig" />
            ) : null
          }
        >
          <BuildingDetailView
            building={newBuilding}
            terrainName={terrains.find(t => String(t.location_id) === String(newBuilding.location_id))?.location_name}
            rooms={rooms}
            onNavigateToRoom={(r) => {
              handleCloseModal();
              navigate('/rooms', { state: { room: r } });
            }}
          />
        </Modal>
      )}

      {showModal && !isViewMode && modalContent}

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
                      <tr key={room.room_id} onClick={() => navigate('/rooms', { state: { room } })} style={{ cursor: 'pointer' }}>
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
      {moveChildrenDialog}
    </div>
  );
}

export default BuildingsPage;