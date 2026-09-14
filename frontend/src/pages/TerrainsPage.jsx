import React, { useState, useEffect, useRef } from "react";
import { Link, useNavigate } from "react-router-dom";
import { IoTrashOutline, IoPencil } from "react-icons/io5";
import { buildingsAPI, locationAPI, roomsAPI, assetsAPI, stockAPI, ticketsAPI, workOrdersAPI } from "../services/api";
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import { useMoveChildren } from '../components/Modal/useMoveChildren';
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import SortPicker from "../components/ColumnPicker/SortPicker";
import FilterPicker from "../components/ColumnPicker/FilterPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import usePagination from "../hooks/usePagination";
import Pagination from "../components/Pagination/Pagination";
import ResizableTh from "../components/ResizableTh";
import { useCurrentUser } from "../hooks/useCurrentUser";
import ImportExportModal from "../components/DataTransfer/ImportExportModal";
import { getDeleteErrorMessage, chooseDeleteStrategy, batchDelete } from "../utils/deleteUtils";
import '../styles/App.css';
import "../styles/Rooms.css";
import Modal from '../components/Modal/Modal';
import CampusDetailView from '../components/DetailView/CampusDetailView';
import '../components/DetailView/DetailView.css';
import useAiSuggestions from "../hooks/useAiSuggestions";
import AiSuggestPanel from "../components/AiSuggestPanel";

function TerrainsPage({ embedded = false }) {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { openMoveChildren, moveChildrenDialog } = useMoveChildren();
  const navigate = useNavigate();
  const { hasRight } = useCurrentUser();
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [assets, setAssets] = useState([]);
  const [stock, setStock] = useState([]);
  const [faults, setFaults] = useState([]);
  const [jobs, setJobs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const TERRAIN_COLUMNS = [
    { key: 'id', label: 'ID Terrein', render: (t) => t.location_id, sortKey: 'id', defaultVisible: false },
    { key: 'name', label: 'Naam', render: (t) => t.location_name, sortKey: 'name', defaultVisible: true },
    { key: 'type', label: 'Tipe', render: (t) => t.location_type, sortKey: 'type', defaultVisible: true },
    { key: 'streetnum', label: 'Straatnommer', render: (t) => t.location_streetnum || '-', sortKey: 'streetnum', defaultVisible: true },
    { key: 'streetname', label: 'Straatnaam', render: (t) => t.location_streetname || '-', sortKey: 'streetname', defaultVisible: true },
    { key: 'suburb', label: 'Voorstad', render: (t) => t.location_suburb || '-', sortKey: 'suburb', defaultVisible: true },
    { key: 'city', label: 'Stad', render: (t) => t.location_city || '-', sortKey: 'city', defaultVisible: true },
    { key: 'province', label: 'Provinsie', render: (t) => t.location_province || '-', sortKey: 'province', defaultVisible: true },
    { key: 'country', label: 'Land', render: (t) => t.location_country || '-', sortKey: 'country', defaultVisible: false },
  ];
  const colVis = useColumnVisibility('terrains-page', TERRAIN_COLUMNS);
  const colWidths = useColumnWidths('terrains-page', TERRAIN_COLUMNS);
  const { sorts, addSort, removeSort, toggleDirection, moveSort, clearSorts, applySort } = useColumnSort({
    columns: TERRAIN_COLUMNS,
    storageKey: 'terrains-page',
  });
  const colPickerRef = useRef(null);
  const [showModal, setShowModal] = useState(false);
  const [showImportWizard, setShowImportWizard] = useState(false);
  const [showBuildingsModal, setShowBuildingsModal] = useState(false);
  const [selectedTerrain, setSelectedTerrain] = useState(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [isViewMode, setIsViewMode] = useState(false);
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
  const terrainSuggestions = useAiSuggestions({
    context: 'location',
    values: newTerrain,
    enabled: showModal && !isViewMode,
  });

  useEffect(() => {
    fetchTerrains();
    fetchBuildings();
    fetchRooms();
    fetchAssets();
    fetchStock();
    fetchFaults();
    fetchJobs();
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
    const children = getBuildingsForTerrain(id);
    const buildingIds = new Set(children.map((b) => b.building_id));
    const roomsInTerrain = rooms.filter((r) => buildingIds.has(r.building_id));
    const roomIds = new Set(roomsInTerrain.map((r) => r.room_id));
    const assetsInSubtree = assets.filter((a) => roomIds.has(a.room_id));
    const stockInSubtree = stock.filter((s) => roomIds.has(s.room_id));
    const assetIds = new Set(assetsInSubtree.map((a) => a.asset_id));
    const faultsInSubtree = faults.filter((f) => f.location_id === id || buildingIds.has(f.building_id) || roomIds.has(f.room_id) || (f.asset_id && assetIds.has(f.asset_id)));
    const faultIds = new Set(faultsInSubtree.map((f) => f.fault_id));
    const jobsInSubtree = jobs.filter((j) => j.location_id === id || buildingIds.has(j.building_id) || roomIds.has(j.room_id) || (j.asset_id && assetIds.has(j.asset_id)) || (j.fault_id && faultIds.has(j.fault_id)));
    const hasContent = assetsInSubtree.length + stockInSubtree.length > 0;
    const strategy = await chooseDeleteStrategy(confirm, {
      entityLabel: "terrein",
      childrenLabel: "geboue",
      hasChildren: children.length > 0,
      hasContent,
      counts: {
        geboue: children.length,
        lokale: roomsInTerrain.length,
        bates: assetsInSubtree.length,
        voorraad: stockInSubtree.length,
        foutkaartjies: faultsInSubtree.length,
        werksopdragte: jobsInSubtree.length,
      },
      directChildrenLabel: 'geboue',
      parentLevelLabel: 'terrein',
    });
    if (!strategy) return;

    try {
      if (strategy === 'move') {
        const targetOptions = terrains
          .filter((t) => t.location_id !== id)
          .map((t) => ({ value: t.location_id, label: t.location_name }));
        const assignments = await openMoveChildren({
          mode: 'individual',
          title: `Skuif geboue van "${terrains.find((t) => t.location_id === id)?.location_name || ''}"`,
          children: children.map((b) => ({ id: b.building_id, label: b.building_name })),
          parentOptions: targetOptions,
          parentLabel: 'verwyder',
          confirmLabel: 'Skuif en verwyder terrein',
        });
        if (assignments === false) return;
        for (const child of children) {
          const target = assignments[child.building_id];
          if (target != null) {
            await buildingsAPI.update(child.building_id, { location_id: Number(target) });
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
        for (const room of roomsInTerrain) {
          const batesInRoom = assets.filter((a) => a.room_id === room.room_id);
          const stockInRoom = stock.filter((s) => s.room_id === room.room_id);
          if (batesInRoom.length === 0 && stockInRoom.length === 0) continue;
          const building = buildings.find((bb) => bb.building_id === room.building_id);
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
            buildingId: room.building_id,
            buildingLabel: building ? building.building_name : `Gebou ${room.building_id}`,
            items,
          });
        }
        if (groups.length > 0) {
          const assignments = await openMoveChildren({
            mode: 'grouped',
            title: `Skuif bates en voorraad van "${terrains.find((t) => t.location_id === id)?.location_name || ''}"`,
            groups,
            parentOptions,
            parentLabel: 'verwyder',
            childrenHeader: 'Bates en voorraad volgens lokaal/gebou (sleep per lokaal)',
            confirmLabel: 'Skuif en verwyder terrein',
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
      await locationAPI.delete(id);
      fetchTerrains();
    } catch (error) {
      console.error("Error deleting terrain:", error);
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
      apiDelete: locationAPI.delete,
      confirm,
      showToast,
      entityLabel: "terreine",
      childrenLabel: "geboue",
      refresh: fetchTerrains,
      errorFallback: "Fout tydens verwydering. Probeer asseblief weer.",
    }).then(() => setSelectedIds([]));
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
    setIsViewMode(true);
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
    setIsViewMode(false);
    setEditingId(null);
    setNewTerrain({ location_name: "", location_type: "", location_streetnum: "", location_streetname: "", location_suburb: "", location_city: "", location_province: "", location_country: "" });
  };

  const handleNewTerrain = () => {
    setIsEditing(false);
    setIsViewMode(false);
    setEditingId(null);
    setNewTerrain({ location_name: "", location_type: "", location_streetnum: "", location_streetname: "", location_suburb: "", location_city: "", location_province: "", location_country: "" });
    setShowModal(true);
  };

  const filteredTerrains = applySort([...terrains]
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
    }),
    (t, key) => {
      switch (key) {
        case 'id': return Number(t.location_id || 0);
        case 'name': return String(t.location_name || '');
        case 'type': return String(t.location_type || '');
        case 'streetnum': return String(t.location_streetnum || '');
        case 'streetname': return String(t.location_streetname || '');
        case 'suburb': return String(t.location_suburb || '');
        case 'city': return String(t.location_city || '');
        case 'province': return String(t.location_province || '');
        case 'country': return String(t.location_country || '');
        default: return '';
      }
    },
  );
    const { currentPage, totalPages, paginatedData: paginatedTerrains, goToPage } = usePagination(filteredTerrains, 100);
  useEffect(() => { goToPage(1); }, [searchTerm, filterColumn, sorts, goToPage]);
  const allSelected = paginatedTerrains.length > 0 && paginatedTerrains.every((x) => selectedIds.includes(x.location_id));
  const toggleAll = () => {
    if (allSelected) {
      const pageIds = new Set(paginatedTerrains.map((x) => x.location_id));
      setSelectedIds((prev) => prev.filter((id) => !pageIds.has(id)));
    } else {
      const pageIds = paginatedTerrains.map((x) => x.location_id);
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
              placeholder="Soek terreine..."
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
              { value: "id", label: "ID" },
              { value: "name", label: "Naam" },
              { value: "type", label: "Tipe" },
              { value: "streetnum", label: "Straatnommer" },
              { value: "streetname", label: "Straatnaam" },
            ]}
            onReset={() => setSearchTerm("")}
          />
        <SortPicker
            columns={TERRAIN_COLUMNS}
            sorts={sorts}
            onAdd={addSort}
            onRemove={removeSort}
            onToggleDirection={toggleDirection}
            onMove={moveSort}
            onClear={clearSorts}
          />
          <ColumnPicker ref={colPickerRef} columns={colVis.columnDefs} visibleColumns={colVis.visibleColumns.map(c => c)} toggleColumn={colVis.toggleColumn} resetVisibility={colVis.resetVisibility} onResetWidths={colWidths.resetWidths} />
        </div>
        <div className="controls-right">
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
          <button className="btn-add" onClick={handleNewTerrain}>+ Nuwe Terrein</button>
          {selectedIds.length > 0 && (
            <button className="btn-delete" style={{ marginLeft: '0.5rem' }} onClick={handleDeleteSelected}>
              Verwyder Geselekteerde ({selectedIds.length})
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
            <th style={{ width: '36px', textAlign: 'center' }}>
              <input type="checkbox" checked={allSelected} onChange={toggleAll} title="Kies alles" onClick={(e) => e.stopPropagation()} />
            </th>
            {colVis.visibleColumns.map((col) => (
              <ResizableTh key={col.key} col={col} colWidths={colWidths} onContextMenu={(e) => { e.preventDefault(); colPickerRef.current?.openAt(e); }}>
                {col.label}
              </ResizableTh>
            ))}
            <th style={{ width: '230px' }}>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredTerrains.length === 0 ? (
            <tr>
              <td colSpan={colVis.visibleColumns.length + 2} style={{ textAlign: 'center', padding: '20px' }}>
                Geen terreine gevind
              </td>
            </tr>
          ) : (
            paginatedTerrains.map((terrain) => (
              <tr key={terrain.location_id} onClick={() => handleEditTerrain(terrain)} style={{ cursor: "pointer" }}>
                <td style={{ textAlign: 'center' }} onClick={e => e.stopPropagation()}>
                  <input type="checkbox" checked={selectedIds.includes(terrain.location_id)} onChange={() => toggleOne(terrain.location_id)} />
                </td>
                {colVis.visibleColumns.map((col) => (
                  <td key={col.key}>{col.render(terrain)}</td>
                ))}
                <td onClick={e => e.stopPropagation()}>
                  <button className="btn-view" onClick={() => handleViewBuildings(terrain)}>Besigtig Geboue</button>
                  <button className="btn-delete" title="Verwyder" onClick={() => handleDeleteTerrain(terrain.location_id)}><IoTrashOutline size={18} /></button>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
      <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} totalItems={filteredTerrains.length} pageSize={100} />
    </>
  );

  const modalContent = (
    <div className="modal" style={{ display: "flex" }} onClick={(e) => { if (e.target === e.currentTarget && isViewMode) handleCloseModal(); }}>
      <div className="modal-content">
        <div className="modal-header">
          <h3>{isViewMode ? "Bekyk" : isEditing ? "Wysig" : "Nuwe"} Terrein {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
          <div className="modal-header-actions">
            {isEditing && isViewMode && hasRight('locations.manage') && (
              <IoPencil size={20} className="modal-edit-btn" onClick={() => setIsViewMode(false)} title="Wysig" />
            )}
            <span className="close" onClick={handleCloseModal}>&times;</span>
          </div>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Naam *</label>
            <input
              ref={el => fieldRefs.current.location_name = el}
              type="text"
              disabled={isViewMode}
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
              disabled={isViewMode}
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
              disabled={isViewMode}
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
              disabled={isViewMode}
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
            <label>Voorstad *</label>
            <input
              ref={el => fieldRefs.current.location_suburb = el}
              type="text"
              disabled={isViewMode}
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
              disabled={isViewMode}
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
              disabled={isViewMode}
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
              disabled={isViewMode}
              className={invalidFields.location_country ? "field-invalid" : ""}
              value={newTerrain.location_country}
              onChange={(e) => {
                setNewTerrain({ ...newTerrain, location_country: e.target.value });
                setInvalidFields(p => { const n = {...p}; delete n.location_country; return n; });
              }}
            />
          </div>
        </div>
        {!isViewMode && (
          <>
          <div className="modal-footer">
            <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
            <button className="btn-add" onClick={handleSaveTerrain}>{isEditing ? "Opdateer" : "Stoor"}</button>
          </div>
          <AiSuggestPanel
            suggestions={terrainSuggestions.suggestions}
            loading={terrainSuggestions.loading}
            filled={terrainSuggestions.filled}
            error={terrainSuggestions.error}
            labels={{ location_type: 'Terrein tipe', location_suburb: 'Voorstad', location_city: 'Stad', location_province: 'Provinsie', location_country: 'Land' }}
            onUse={(key, suggestion) => setNewTerrain((previous) => ({ ...previous, [key]: String(suggestion.value) }))}
          />
          </>
        )}
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
            title={`Bekyk Terrein`}
            size="md"
            headerActions={
              hasRight('locations.manage') ? (
                <IoPencil size={20} className="modal-edit-btn" onClick={() => setIsViewMode(false)} title="Wysig" />
              ) : null
            }
          >
            <CampusDetailView
              campus={newTerrain}
              buildings={buildings}
              onNavigateToBuilding={(b) => {
                handleCloseModal();
                navigate('/buildings', { state: { building: b } });
              }}
            />
          </Modal>
        )}

        {showModal && !isViewMode && modalContent}

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
                        <tr key={building.building_id} onClick={() => navigate('/buildings', { state: { building } })} style={{ cursor: 'pointer' }}>
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
          title={`Bekyk Terrein`}
          size="md"
          headerActions={
            hasRight('locations.manage') ? (
              <IoPencil size={20} className="modal-edit-btn" onClick={() => setIsViewMode(false)} title="Wysig" />
            ) : null
          }
        >
          <CampusDetailView
            campus={newTerrain}
            buildings={buildings}
            onNavigateToBuilding={(b) => {
              handleCloseModal();
              navigate('/buildings', { state: { building: b } });
            }}
          />
        </Modal>
      )}
      {showModal && !isViewMode && modalContent}
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
                      <tr key={building.building_id} onClick={() => navigate('/buildings', { state: { building } })} style={{ cursor: 'pointer' }}>
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
      {moveChildrenDialog}
    </div>
  );
}

export default TerrainsPage;
