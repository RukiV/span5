import React, { useState, useEffect, useRef, useMemo } from "react";
import { Link } from "react-router-dom";
import Select from "react-select";
import { IoTrashOutline } from "react-icons/io5";
import { renderBreadcrumb, CascadeControl, CascadeIndicatorsContainer, NoCascadeClearIndicator } from "../components/controlHelpers";
import { roomsAPI, stockAPI, buildingsAPI, locationAPI, apiClient } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import usePagination from "../hooks/usePagination";
import Pagination from "../components/Pagination/Pagination";
import ResizableTh from "../components/ResizableTh";
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import useAiSuggestions from "../hooks/useAiSuggestions";
import AiSuggestPanel from "../components/AiSuggestPanel";
import useCascadeMenu from "../hooks/useCascadeMenu";
import "../styles/Asset.css";
import "../styles/App.css";
import { buildFlatLocationOptions } from './locationSearchUtils';
import ImportExportModal from "../components/DataTransfer/ImportExportModal";
import { getDeleteErrorMessage, confirmCascade, batchDelete } from "../utils/deleteUtils";

function StockPage({ embedded = false }) {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { user, hasRight } = useCurrentUser();
  const [stock, setStock] = useState([]);
  const [showImportWizard, setShowImportWizard] = useState(false);
  const [rooms, setRooms] = useState([]);
  const [buildings, setBuildings] = useState([]); // Bygevoeg
  const [terrains, setTerrains] = useState([]); // Bygevoeg
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: null });

  const STOCK_COLUMNS = [
    { key: 'id', label: 'ID Voorraad', render: (s) => s.stock_id, sortKey: 'id', defaultVisible: false },
    { key: 'name', label: 'Naam', render: (s) => s.stock_name, sortKey: 'name', defaultVisible: true },
    { key: 'brand', label: 'Handelsmerk', render: (s) => s.stock_brand, sortKey: 'brand', defaultVisible: true },
    { key: 'type', label: 'Tipe', render: (s) => s.stock_type, sortKey: 'type', defaultVisible: true },
    { key: 'amount', label: 'Hoeveelheid', render: (s) => s.stock_amount, sortKey: 'amount', defaultVisible: true },
    { key: 'minimum', label: 'Minimum', render: (s) => s.stock_minimum, sortKey: 'minimum', defaultVisible: true },
    { key: 'boxTotal', label: 'Boks Totaal', render: (s) => s.stock_boxTotal, sortKey: 'boxTotal', defaultVisible: true },
    { key: 'room', label: 'Lokaal', render: (s) => getRoomName(s), sortKey: 'room', defaultVisible: true },
    { key: 'description', label: 'Beskrywing', render: (s) => s.stock_desc || '-', sortKey: 'description', defaultVisible: false },
  ];
  const colVis = useColumnVisibility('stock-page', STOCK_COLUMNS);
  const colWidths = useColumnWidths('stock-page', STOCK_COLUMNS);
  const colPickerRef = useRef(null);

  const [stockImages, setStockImages] = useState([]);
  const [selectedImageFiles, setSelectedImageFiles] = useState([]);
  const [selectedImagePreviewUrls, setSelectedImagePreviewUrls] = useState([]);
  const [imagesToDelete, setImagesToDelete] = useState([]);
  const [activeImageViewer, setActiveImageViewer] = useState(null);
  const MAX_STOCK_IMAGES = 1;
  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const [roomFilter, setRoomFilter] = useState("");
  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, rooms, null), [terrains, buildings, rooms]);
  const filterCascade = useCascadeMenu();
  const modalCascadeMenu = useCascadeMenu();
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [cascadeToast, setCascadeToast] = useState(null);
  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});

  const [newStock, setNewStock] = useState({
    stock_name: "",
    stock_brand: "",
    stock_amount: 0,
    stock_minimum: 0,
    stock_boxTotal: 0,
    stock_type: "",
    stock_desc: "",
    room_id: "",
    location_id: "", // Bygevoeg vir cascading logika
    building_id: ""  // Bygevoeg vir cascading logika
  });

  // AI-veldvoorstel: stock_type uit soortgelyke voorraadname.
  const { suggestions: aiSuggestions, loading: aiLoading, filled: aiFilled, error: aiError } = useAiSuggestions({
    context: 'stock',
    values: {
      stock_name: newStock.stock_name,
      stock_brand: newStock.stock_brand,
      stock_amount: newStock.stock_amount || undefined,
      stock_minimum: newStock.stock_minimum || undefined,
      stock_boxTotal: newStock.stock_boxTotal || undefined,
      stock_type: newStock.stock_type,
    },
  });

  useEffect(() => {
    const loadInitialData = async () => {
      await Promise.all([fetchStock(), fetchRooms(), fetchBuildings(), fetchTerrains()]);
    };
    loadInitialData();
  }, []);

  useEffect(() => {
    if (user?.role_id === 2 && user?.location_id) {
      setTerrainFilter(String(user.location_id));
    } else {
      setTerrainFilter("");
    }
  }, [user]);

  const fetchStock = async () => {
    try {
      const response = await stockAPI.getAll();
      setStock(response.data || []);
    } catch (error) {
      console.error("Error fetching stock:", error);
    } finally {
      setLoading(false);
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

  const fetchBuildings = async () => {
    try {
      const response = await buildingsAPI.getAll();
      setBuildings(response.data || []);
    } catch (error) {
      console.error("Error fetching buildings:", error);
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

  const fetchStockImages = async (stockId) => {
    if (!stockId) {
      setStockImages([]);
      return;
    }

    try {
      const response = await apiClient.image.getByParent("stock", stockId);
      setStockImages(response.data || []);
    } catch (error) {
      console.error("Fout by laai van voorraad-beelde:", error);
      setStockImages([]);
    }
  };

  const getStockImageUrl = (imageId) => {
    if (!imageId) return null;
    return apiClient.image?.getFileUrl ? apiClient.image.getFileUrl(imageId) : null;
  };

  const handleImageFilesChange = (event) => {
    const files = Array.from(event.target.files || []);
    const remainingSlots = Math.max(0, MAX_STOCK_IMAGES - (selectedImageFiles.length + stockImages.length));
    const incomingFiles = files.slice(0, remainingSlots);

    if (files.length > remainingSlots) {
      showToast({ type: 'warning', title: 'Waarskuwing', message: `Jy kan maksimaal ${MAX_STOCK_IMAGES} beeld per voorraad-item oplaai.` });
    }

    if (incomingFiles.length === 0) {
      event.target.value = "";
      return;
    }

    const previewUrls = incomingFiles.map((file) => URL.createObjectURL(file));
    setSelectedImageFiles((prev) => [...prev, ...incomingFiles]);
    setSelectedImagePreviewUrls((prev) => [...prev, ...previewUrls]);
    event.target.value = "";
  };

  const handleRemoveSelectedPreview = async (index) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie beeld verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;

    setSelectedImageFiles((prev) => prev.filter((_, itemIndex) => itemIndex !== index));
    setSelectedImagePreviewUrls((prev) => {
      const urlToRevoke = prev[index];
      if (urlToRevoke) {
        URL.revokeObjectURL(urlToRevoke);
      }
      return prev.filter((_, itemIndex) => itemIndex !== index);
    });
  };

  const handleDeleteExistingImage = async (imageId) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie beeld verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;

    setStockImages((prev) => prev.filter((image) => image.image_id !== imageId));
    setImagesToDelete((prev) => (prev.includes(imageId) ? prev : [...prev, imageId]));
  };

  const handleSaveStock = async () => {
    let savedStockId = isEditing ? editingId : null;
    try {
      const errors = {};
      if (!newStock.stock_name.trim()) errors.stock_name = true;
      if (!newStock.stock_brand.trim()) errors.stock_brand = true;
      if (!newStock.stock_type.trim()) errors.stock_type = true;
      if (!newStock.stock_minimum || Number(newStock.stock_minimum) <= 0) errors.stock_minimum = true;
      if (!newStock.stock_boxTotal || Number(newStock.stock_boxTotal) <= 0) errors.stock_boxTotal = true;
      if (!newStock.stock_desc?.trim()) errors.stock_desc = true;
      if (!newStock.room_id) errors.location_id = true;
      if (Object.keys(errors).length > 0) {
        setInvalidFields(errors);
        const firstKey = Object.keys(errors)[0];
        fieldRefs.current[firstKey]?.scrollIntoView({ behavior: "smooth", block: "center" });
        fieldRefs.current[firstKey]?.focus();
        return;
      }
      setInvalidFields({});

      const stockData = {
        stock_name: newStock.stock_name,
        stock_brand: newStock.stock_brand,
        stock_amount: Number(newStock.stock_amount),
        stock_minimum: Number(newStock.stock_minimum),
        stock_boxTotal: Number(newStock.stock_boxTotal),
        stock_type: newStock.stock_type,
        stock_desc: newStock.stock_desc,
        room_id: Number(newStock.room_id),
      };

      if (isEditing) {
        await stockAPI.update(editingId, stockData);
        savedStockId = editingId;
      } else {
        const response = await stockAPI.create(stockData);
        savedStockId = response?.data?.stock_id ?? response?.data?.id ?? null;
      }

      if (!savedStockId) {
        throw new Error("Kon nie die voorraad-ID na stoor terugkry nie.");
      }

      if (isEditing) {
        for (const imageId of imagesToDelete) {
          await apiClient.image.delete(imageId);
        }
      }

      if (selectedImageFiles.length > 0) {
        for (const file of selectedImageFiles.slice(0, MAX_STOCK_IMAGES)) {
          const formData = new FormData();
          formData.append("file", file);
          await apiClient.image.uploadForParent(savedStockId, "stock", formData);
        }
      }

      handleCloseModal();
      fetchStock();
      fetchStockImages(savedStockId);
    } catch (error) {
      console.error("Error saving stock:", error);
      showToast({ type: 'error', title: 'Fout', message: "Fout tydens besparing. Probeer asseblief weer." });
    }
  };

  const handleDeleteStock = async (id) => {
    const confirmed = await confirmCascade(confirm, { entityLabel: "voorraad-item", childrenLabel: "beelde" });
    if (!confirmed) return;
    try {
      await stockAPI.delete(id);
      fetchStock();
    } catch (error) {
      console.error("Error deleting stock:", error);
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
      apiDelete: stockAPI.delete,
      confirm,
      showToast,
      entityLabel: "voorraad-items",
      childrenLabel: "beelde",
      refresh: fetchStock,
      errorFallback: "Fout tydens verwydering. Probeer asseblief weer.",
    }).then(() => setSelectedIds([]));
  };

  const handleEditStock = (item) => {
    // Vind die geassosieerde kamer en gebou vir die geselekteerde item
    const room = rooms.find((r) => r.room_id === item.room_id);
    const building = room ? buildings.find((b) => b.building_id === room.building_id) : null;

    setIsEditing(true);
    setEditingId(item.stock_id);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewStock({
      stock_name: item.stock_name || "",
      stock_brand: item.stock_brand || "",
      stock_amount: item.stock_amount || 0,
      stock_minimum: item.stock_minimum || 0,
      stock_boxTotal: item.stock_boxTotal || 0,
      stock_type: item.stock_type || "",
      stock_desc: item.stock_desc || "",
      room_id: item.room_id ? Number(item.room_id) : "",
      location_id: building ? building.location_id : "",
      building_id: room ? room.building_id : ""
    });
    fetchStockImages(item.stock_id);
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setStockImages([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewStock({ stock_name: "", stock_brand: "", stock_amount: 0, stock_minimum: 0, stock_boxTotal: 0, stock_type: "", stock_desc: "", room_id: "", location_id: "", building_id: "" });
  };

  const handleNewStock = () => {
    setIsEditing(false);
    setEditingId(null);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setStockImages([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewStock({ stock_name: "", stock_brand: "", stock_amount: 0, stock_minimum: 0, stock_boxTotal: 0, stock_type: "", stock_desc: "", room_id: "", location_id: "", building_id: "" });
    setShowModal(true);
  };

  const getStockLocationId = (item) => {
    if (!item.room_id) return null;
    const room = rooms.find((r) => r.room_id === item.room_id);
    if (!room) return null;
    const building = buildings.find((b) => b.building_id === room.building_id);
    return building ? building.location_id : null;
  };

  const getStockBuildingId = (item) => {
    if (!item.room_id) return null;
    const room = rooms.find((r) => r.room_id === item.room_id);
    return room ? room.building_id : null;
  };

  const getRoomName = (item) => {
    if (!item.room_id) return "-";
    const room = rooms.find((roomItem) => roomItem.room_id === item.room_id);
    return room ? room.room_name : `Room ${item.room_id}`;
  };

  const filteredStock = [...stock]
    .filter((item) => {
      if (terrainFilter) {
        const locId = getStockLocationId(item);
        if (String(locId) !== String(terrainFilter)) return false;
      }
      if (buildingFilter) {
        const bldId = getStockBuildingId(item);
        if (String(bldId) !== String(buildingFilter)) return false;
      }
      if (roomFilter) {
        if (String(item.room_id) !== String(roomFilter)) return false;
      }
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const values = {
        id: item.stock_id,
        name: item.stock_name,
        brand: item.stock_brand,
        type: item.stock_type,
        amount: item.stock_amount,
        minimum: item.stock_minimum,
        boxTotal: item.stock_boxTotal,
        description: item.stock_desc,
        room: getRoomName(item),
      };
      if (filterColumn === 'all') {
        return Object.values(values).some((value) => String(value || '').toLowerCase().includes(query));
      }
      return String(values[filterColumn] || '').toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (!sortKey) return 0;
      const dir = sortDirection === 'asc' ? 1 : -1;
      if (sortKey === 'id') return (Number(a.stock_id || 0) - Number(b.stock_id || 0)) * dir;
      if (sortKey === 'name') return String(a.stock_name || '').localeCompare(String(b.stock_name || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'brand') return String(a.stock_brand || '').localeCompare(String(b.stock_brand || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'type') return String(a.stock_type || '').localeCompare(String(b.stock_type || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'amount') return (Number(a.stock_amount || 0) - Number(b.stock_amount || 0)) * dir;
      if (sortKey === 'minimum') return (Number(a.stock_minimum || 0) - Number(b.stock_minimum || 0)) * dir;
      if (sortKey === 'boxTotal') return (Number(a.stock_boxTotal || 0) - Number(b.stock_boxTotal || 0)) * dir;
      if (sortKey === 'room') return String(getRoomName(a) || '').localeCompare(String(getRoomName(b) || ''), 'af', { sensitivity: 'base' }) * dir;
      if (sortKey === 'description') return String(a.stock_desc || '').localeCompare(String(b.stock_desc || ''), 'af', { sensitivity: 'base' }) * dir;
      return 0;
    });
    const { currentPage, totalPages, paginatedData: paginatedStock, goToPage } = usePagination(filteredStock, 100);
  useEffect(() => { goToPage(1); }, [searchTerm, filterColumn, terrainFilter, buildingFilter, roomFilter, sortKey, sortDirection, goToPage]);
const allSelected = paginatedStock.length > 0 && paginatedStock.every((x) => selectedIds.includes(x.stock_id));
  const toggleAll = () => {
    if (allSelected) {
      const pageIds = new Set(paginatedStock.map((x) => x.stock_id));
      setSelectedIds((prev) => prev.filter((id) => !pageIds.has(id)));
    } else {
      const pageIds = paginatedStock.map((x) => x.stock_id);
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
              placeholder="Soek voorraad..."
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
              { value: "brand", label: "Handelsmerk" },
              { value: "type", label: "Tipe" },
              { value: "amount", label: "Hoeveelheid" },
              { value: "minimum", label: "Minimum" },
              { value: "boxTotal", label: "Boks Totaal" },
              { value: "room", label: "Lokaal" },
              { value: "description", label: "Beskrywing" },
            ].find((option) => option.value === filterColumn)}
            onChange={(selected) => setFilterColumn(selected?.value || "all")}
            options={[
              { value: "all", label: "Alle kolomme" },
              { value: "id", label: "ID" },
              { value: "name", label: "Naam" },
              { value: "brand", label: "Handelsmerk" },
              { value: "type", label: "Tipe" },
              { value: "amount", label: "Hoeveelheid" },
              { value: "minimum", label: "Minimum" },
              { value: "boxTotal", label: "Boks Totaal" },
              { value: "room", label: "Lokaal" },
              { value: "description", label: "Beskrywing" },
            ]}
            isSearchable={false}
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
            return (
              <div className="control-cascade-stack" ref={filterCascade.containerRef}>
                <div className="control-cascade-breadcrumb">
                  {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 3 })}
                </div>
                  <Select
                    className="react-select-container"
                    classNamePrefix="react-select"
                    placeholder={["Kies Terrein...","Kies Gebou...","Kies Lokaal...","Filter voltooi"][cascadeCount]}
                    isClearable
                    isDisabled={cascadeCount >= 3}
                    closeMenuOnSelect={false}
                    menuIsOpen={filterCascade.menuIsOpen}
                    onMenuOpen={filterCascade.onMenuOpen}
                    onMenuClose={filterCascade.onMenuClose}
                    components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} />, IndicatorsContainer: CascadeIndicatorsContainer, ClearIndicator: NoCascadeClearIndicator }}
                    styles={{
                      container: (base) => ({ ...base, minWidth: '260px' }),
                      control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                      valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                      singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                    }}
                    options={allLocationOptions}
                    filterOption={(option, rawInput) => {
                      if (rawInput) {
                        if (cascadeCount === 0)
                          return option.data._cascadeLevel <= 3 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        if (cascadeCount === 1)
                          return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 3 && String(option.data._fields.location_id) === String(terrainFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        if (cascadeCount === 2)
                          return option.data._cascadeLevel >= 2 && option.data._cascadeLevel <= 3 && String(option.data._fields.building_id) === String(buildingFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        if (cascadeCount === 3)
                          return option.data._cascadeLevel >= 3 && option.data._cascadeLevel <= 3 && String(option.data._fields.room_id) === String(roomFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
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
                      setTerrainFilter(f.location_id); setBuildingFilter(f.building_id); setRoomFilter(f.room_id);
                    }}
                  />
              </div>
            );
          })()}
        </div>
        <div className="controls-right">
          {hasRight('stock.manage') && (
            <button
              type="button"
              className="btn-add"
              style={{ marginLeft: '0.5rem' }}
              onClick={() => setShowImportWizard(true)}
            >
              ⇅ Invoer / Uitvoer rekords
            </button>
          )}
          <ColumnPicker
            ref={colPickerRef}
            columns={STOCK_COLUMNS}
            visibleColumns={colVis.visibleColumns}
            toggleColumn={colVis.toggleColumn}
            resetVisibility={colVis.resetVisibility}
            onResetWidths={colWidths.resetWidths}
          />
          <button className="btn-add" onClick={handleNewStock}>+ Nuwe Voorraad</button>
          {selectedIds.length > 0 && (
            <button className="btn-delete" style={{ marginLeft: '0.5rem' }} onClick={handleDeleteSelected}>
              Verwyder Geselekteerde ({selectedIds.length})
            </button>
          )}
          {hasRight('stock.manage') && (
            <ImportExportModal
              isOpen={showImportWizard}
              onClose={() => setShowImportWizard(false)}
              defaultEntity="stock"
              onImported={fetchStock}
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
                className={col.sortKey ? getSortClass(col.sortKey) : ''}
                onClick={() => col.sortKey && handleSort(col.sortKey)}
                onContextMenu={(e) => colPickerRef.current?.openAt(e)}
              >
                {col.label}{col.sortKey && getSortIndicator(col.sortKey)}
              </ResizableTh>
            ))}
            <th style={{ width: '190px' }}>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {paginatedStock.map((item) => (
            <tr key={item.stock_id} onClick={() => handleEditStock(item)} style={{ cursor: "pointer" }}>
              <td style={{ textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
                <input type="checkbox" checked={selectedIds.includes(item.stock_id)} onChange={() => toggleOne(item.stock_id)} />
              </td>
              {colVis.visibleColumns.map((col) => (
                <td key={col.key}>{col.render(item)}</td>
              ))}
              <td onClick={e => e.stopPropagation()}>
                <button className="btn-delete" title="Verwyder" onClick={() => handleDeleteStock(item.stock_id)}><IoTrashOutline size={18} /></button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} totalItems={filteredStock.length} pageSize={100} />
    </>
  );

  const modalContent = (
    <div className="modal" style={{ display: "flex" }}>
      <div className="modal-content">
        <div className="modal-header">
          <h3>{isEditing ? "Wysig" : "Nuwe"} Voorraad {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
          <span className="close" onClick={handleCloseModal}>&times;</span>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Naam *</label>
            <input
              type="text"
              value={newStock.stock_name}
              ref={el => fieldRefs.current.stock_name = el}
              className={invalidFields.stock_name ? "field-invalid" : ""}
              onChange={(e) => { setNewStock({ ...newStock, stock_name: e.target.value }); if (invalidFields.stock_name) setInvalidFields(prev => { const n = {...prev}; delete n.stock_name; return n; }); }}
            />
          </div>
          <div className="input-group">
            <label>Handelsmerk *</label>
            <input
              type="text"
              value={newStock.stock_brand}
              ref={el => fieldRefs.current.stock_brand = el}
              className={invalidFields.stock_brand ? "field-invalid" : ""}
              onChange={(e) => { setNewStock({ ...newStock, stock_brand: e.target.value }); if (invalidFields.stock_brand) setInvalidFields(prev => { const n = {...prev}; delete n.stock_brand; return n; }); }}
            />
          </div>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Tipe *</label>
            <input
              type="text"
              value={newStock.stock_type}
              ref={el => fieldRefs.current.stock_type = el}
              className={invalidFields.stock_type ? "field-invalid" : ""}
              onChange={(e) => { setNewStock({ ...newStock, stock_type: e.target.value }); if (invalidFields.stock_type) setInvalidFields(prev => { const n = {...prev}; delete n.stock_type; return n; }); }}
            />
          </div>
          <div className="input-group">
            <label>Hoeveelheid</label>
            <input
              type="number"
              value={newStock.stock_amount}
              onChange={(e) => setNewStock({ ...newStock, stock_amount: e.target.value })}
            />
          </div>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Minimum voorraad *</label>
            <input
              type="number"
              value={newStock.stock_minimum}
              ref={el => fieldRefs.current.stock_minimum = el}
              className={invalidFields.stock_minimum ? "field-invalid" : ""}
              onChange={(e) => { setNewStock({ ...newStock, stock_minimum: e.target.value }); if (invalidFields.stock_minimum) setInvalidFields(prev => { const n = {...prev}; delete n.stock_minimum; return n; }); }}
            />
          </div>
          <div className="input-group">
            <label>Boks Totaal *</label>
            <input
              type="number"
              value={newStock.stock_boxTotal}
              ref={el => fieldRefs.current.stock_boxTotal = el}
              className={invalidFields.stock_boxTotal ? "field-invalid" : ""}
              onChange={(e) => { setNewStock({ ...newStock, stock_boxTotal: e.target.value }); if (invalidFields.stock_boxTotal) setInvalidFields(prev => { const n = {...prev}; delete n.stock_boxTotal; return n; }); }}
            />
          </div>
        </div>

        <div className="input-row">
          <div className={invalidFields.location_id ? "input-group field-invalid" : "input-group"} style={{ position: "relative", flex: 1 }}>
            <label>Ligging *</label>
            {(() => {
              const cascadeCount = [newStock.location_id, newStock.building_id, newStock.room_id].filter(Boolean).length;
              const currentDisplayValue = cascadeCount === 0 ? null
                : cascadeCount === 1 && newStock.location_id ? { value: newStock.location_id, label: terrains?.find(t => String(t.location_id) === String(newStock.location_id))?.location_name || newStock.location_id }
                : cascadeCount === 2 && newStock.building_id ? { value: newStock.building_id, label: buildings?.find(b => String(b.building_id) === String(newStock.building_id))?.building_name || newStock.building_id }
                : cascadeCount === 3 && newStock.room_id ? { value: newStock.room_id, label: rooms?.find(r => String(r.room_id) === String(newStock.room_id))?.room_name || newStock.room_id }
                : null;
              const clearFromLevel = (levelIndex) => {
                if (levelIndex <= 0) setNewStock(p => ({...p, location_id: "", building_id: "", room_id: ""}));
                else if (levelIndex === 1) setNewStock(p => ({...p, building_id: "", room_id: ""}));
                else if (levelIndex === 2) setNewStock(p => ({...p, room_id: ""}));
              };
              const breadcrumbData = [{ level: -1, name: "Terreine" }];
              if (newStock.location_id) breadcrumbData.push({ level: 0, name: terrains?.find(t => String(t.location_id) === String(newStock.location_id))?.location_name || newStock.location_id });
              if (newStock.building_id) breadcrumbData.push({ level: 1, name: buildings?.find(b => String(b.building_id) === String(newStock.building_id))?.building_name || newStock.building_id });
              if (newStock.room_id) breadcrumbData.push({ level: 2, name: rooms?.find(r => String(r.room_id) === String(newStock.room_id))?.room_name || newStock.room_id });
              return (
                <div ref={modalCascadeMenu.containerRef}>
                  {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 3, marginTop: "6px", marginBottom: "6px" })}
                    <Select
                      className="react-select-container"
                      classNamePrefix="react-select"
                      placeholder={["Kies Terrein...","Kies Gebou...","Kies Lokaal...","Ligging voltooi"][cascadeCount]}
                      isClearable
                      isDisabled={cascadeCount >= 3}
                      closeMenuOnSelect={false}
                      menuIsOpen={modalCascadeMenu.menuIsOpen}
                      onMenuOpen={modalCascadeMenu.onMenuOpen}
                      onMenuClose={modalCascadeMenu.onMenuClose}
                      components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} />, IndicatorsContainer: CascadeIndicatorsContainer, ClearIndicator: NoCascadeClearIndicator }}
                      options={allLocationOptions}
                      styles={{
                        container: (base) => ({ ...base, minWidth: '260px' }),
                        control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                        valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                        singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                      }}
                      filterOption={(option, rawInput) => {
                        if (rawInput) {
                          if (cascadeCount === 0)
                            return option.data._cascadeLevel <= 3 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 1)
                            return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 3 && String(option.data._fields.location_id) === String(newStock.location_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 2)
                            return option.data._cascadeLevel >= 2 && option.data._cascadeLevel <= 3 && String(option.data._fields.building_id) === String(newStock.building_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 3)
                            return option.data._cascadeLevel >= 3 && option.data._cascadeLevel <= 3 && String(option.data._fields.room_id) === String(newStock.room_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        }
                        if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                        if (cascadeCount === 1) return option.data._cascadeLevel === 1 && String(option.data._parentId) === String(newStock.location_id);
                        if (cascadeCount === 2) return option.data._cascadeLevel === 2 && String(option.data._parentId) === String(newStock.building_id);
                        return false;
                      }}
                      value={currentDisplayValue}
                      onChange={(selectedOption) => {
                        if (!selectedOption) { setNewStock(p => ({...p, location_id: "", building_id: "", room_id: ""})); return; }
                        if (invalidFields.location_id) setInvalidFields(prev => { const n = {...prev}; delete n.location_id; return n; });
                        const labels = ["Terrein","Gebou","Lokaal"];
                        setNewStock(p => ({...p, ...selectedOption._fields}));
                        setCascadeToast(`✓ ${labels[cascadeCount]} suksesvol geselekteer`);
                        setTimeout(() => setCascadeToast(null), 2000);
                      }}
                    />
                </div>
              );
            })()}
            {cascadeToast && (
              <div style={{ position: "absolute", top: "50%", left: "50%", transform: "translate(-50%, -50%)", background: "#16a34a", color: "#fff", padding: "10px 24px", borderRadius: "10px", fontSize: "14px", fontWeight: "600", boxShadow: "0 4px 14px rgba(0,0,0,0.25)", zIndex: 10, textAlign: "center", pointerEvents: "none", whiteSpace: "nowrap" }}>
                {cascadeToast}
              </div>
            )}
          </div>
        </div>

        <div className="input-row">
          <div className="input-group">
            <label>Beskrywing *</label>
            <textarea
              value={newStock.stock_desc}
              ref={el => fieldRefs.current.stock_desc = el}
              className={invalidFields.stock_desc ? "field-invalid" : ""}
              onChange={(e) => { setNewStock({ ...newStock, stock_desc: e.target.value }); if (invalidFields.stock_desc) setInvalidFields(prev => { const n = {...prev}; delete n.stock_desc; return n; }); }}
            />
          </div>
        </div>

        <div className="input-row">
          <div className="input-group" style={{ width: "100%" }}>
            <label>Beelde</label>
            <input type="file" accept="image/*" multiple onChange={handleImageFilesChange} />
            <div className="image-preview-grid">
              {stockImages.map((image) => (
                <div key={image.image_id} className="record-image-card">
                  <img
                    src={getStockImageUrl(image.image_id)}
                    alt={image.filename || "Voorraadbeeld"}
                    className="record-image-thumb"
                    onClick={() => setActiveImageViewer(getStockImageUrl(image.image_id))}
                  />
                  <button type="button" className="btn-delete" onClick={() => handleDeleteExistingImage(image.image_id)}>
                    Verwyder
                  </button>
                </div>
              ))}
              {selectedImagePreviewUrls.map((url, index) => (
                <div key={`${url}-${index}`} className="record-image-card">
                  <img src={url} alt={`Voorgestelde beeld ${index + 1}`} className="record-image-thumb" onClick={() => setActiveImageViewer(url)} />
                  <button type="button" className="btn-delete" onClick={() => handleRemoveSelectedPreview(index)}>
                    Verwyder
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
          <button className="btn-add" onClick={handleSaveStock}>{isEditing ? "Opdateer" : "Stoor"}</button>
        </div>
        <AiSuggestPanel
          suggestions={aiSuggestions}
          loading={aiLoading}
          filled={aiFilled}
          error={aiError}
          labels={{ stock_type: 'Tipe' }}
          onUse={(key, s) => {
            if (key === 'stock_type') setNewStock(p => ({ ...p, stock_type: String(s.value) }));
          }}
        />
      </div>
    </div>
  );

  const imageViewerContent = activeImageViewer && (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', zIndex: 1100, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '2rem' }} onClick={() => setActiveImageViewer(null)}>
      <div style={{ background: '#fff', borderRadius: '8px', maxWidth: 'min(90vw, 1200px)', maxHeight: '90vh', padding: '2rem', position: 'relative', boxShadow: '0 12px 30px rgba(0,0,0,0.25)' }}>
        <span className="close" onClick={() => setActiveImageViewer(null)} style={{ position: 'absolute', top: '0.75rem', right: '0.75rem', cursor: 'pointer' }}>&times;</span>
        <img src={activeImageViewer} alt="Vergrote beeld" style={{ width: '100%', maxHeight: '75vh', objectFit: 'contain', display: 'block', marginTop: '2rem' }} onClick={(event) => event.stopPropagation()} />
      </div>
    </div>
  );

  if (embedded) {
    return (
      <>
        {pageContent}

        {showModal && modalContent}
        {imageViewerContent}
      {dialog}
      </>
    );
  }

  return (
    <div className="main">
      <div className="content">
          <div className="controls controls--sticky">
            <div className="controls-left">
              <div className="control-input-shell">
                <input
                  type="text"
                  placeholder="Soek voorraad..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              <Select
                className="react-select-container"
                classNamePrefix="react-select"
                value={[
                  { value: "all", label: "Alle kolomme" }, { value: "id", label: "ID" },
                  { value: "name", label: "Naam" }, { value: "brand", label: "Handelsmerk" },
                  { value: "type", label: "Tipe" }, { value: "amount", label: "Hoeveelheid" },
                  { value: "minimum", label: "Minimum" }, { value: "boxTotal", label: "Boks Totaal" },
                  { value: "room", label: "Lokaal" }, { value: "description", label: "Beskrywing" },
                ].find((option) => option.value === filterColumn)}
                onChange={(selected) => setFilterColumn(selected?.value || "all")}
                options={[
                  { value: "all", label: "Alle kolomme" }, { value: "id", label: "ID" },
                  { value: "name", label: "Naam" }, { value: "brand", label: "Handelsmerk" },
                  { value: "type", label: "Tipe" }, { value: "amount", label: "Hoeveelheid" },
                  { value: "minimum", label: "Minimum" }, { value: "boxTotal", label: "Boks Totaal" },
                  { value: "room", label: "Lokaal" }, { value: "description", label: "Beskrywing" },
                ]}
                  isSearchable={false}
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
                return (
                  <div className="control-cascade-stack" ref={filterCascade.containerRef}>
                    <div className="control-cascade-breadcrumb">
                      {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: 3 })}
                    </div>
                    <Select
                      className="react-select-container"
                      classNamePrefix="react-select"
                      placeholder={["Kies Terrein...","Kies Gebou...","Kies Lokaal...","Filter voltooi"][cascadeCount]}
                      isClearable
                      isDisabled={cascadeCount >= 3}
                      closeMenuOnSelect={false}
                      menuIsOpen={filterCascade.menuIsOpen}
                      onMenuOpen={filterCascade.onMenuOpen}
                      onMenuClose={filterCascade.onMenuClose}
                      components={{ Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} />, IndicatorsContainer: CascadeIndicatorsContainer, ClearIndicator: NoCascadeClearIndicator }}
                      styles={{
                        container: (base) => ({ ...base, minWidth: '260px' }),
                        control: (base) => ({ ...base, minHeight: '40px', height: '40px', display: 'flex', alignItems: 'center' }),
                        valueContainer: (base) => ({ ...base, padding: '0 12px', display: 'flex', alignItems: 'center' }),
                        singleValue: (base) => ({ ...base, margin: 0, padding: 0, lineHeight: '38px', whiteSpace: 'nowrap' }),
                      }}
                      options={allLocationOptions}
                      filterOption={(option, rawInput) => {
                        if (rawInput) {
                          if (cascadeCount === 0)
                            return option.data._cascadeLevel <= 3 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 1)
                            return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 3 && String(option.data._fields.location_id) === String(terrainFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 2)
                            return option.data._cascadeLevel >= 2 && option.data._cascadeLevel <= 3 && String(option.data._fields.building_id) === String(buildingFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 3)
                            return option.data._cascadeLevel >= 3 && option.data._cascadeLevel <= 3 && String(option.data._fields.room_id) === String(roomFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
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
                        setTerrainFilter(f.location_id); setBuildingFilter(f.building_id); setRoomFilter(f.room_id);
                      }}
                    />
                  </div>
                );
              })()}
            </div>
            <div className="controls-right">
              {hasRight('stock.manage') && (
                <button
                  type="button"
                  className="btn-add"
                  style={{ marginLeft: '0.5rem' }}
                  onClick={() => setShowImportWizard(true)}
                >
                  ⇅ Invoer / Uitvoer rekords
                </button>
              )}
              <ColumnPicker
                ref={colPickerRef}
                columns={STOCK_COLUMNS}
                visibleColumns={colVis.visibleColumns}
                toggleColumn={colVis.toggleColumn}
                resetVisibility={colVis.resetVisibility}
                onResetWidths={colWidths.resetWidths}
              />
          <button className="btn-add" onClick={handleNewStock}>+ Nuwe Voorraad</button>
            {selectedIds.length > 0 && (
              <button className="btn-delete" style={{ marginLeft: '0.5rem' }} onClick={handleDeleteSelected}>
                Verwyder Geselekteerde ({selectedIds.length})
              </button>
            )}
            {hasRight('stock.manage') && (
              <ImportExportModal
                isOpen={showImportWizard}
                onClose={() => setShowImportWizard(false)}
                defaultEntity="stock"
                onImported={fetchStock}
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
                    className={col.sortKey ? getSortClass(col.sortKey) : ''}
                    onClick={() => col.sortKey && handleSort(col.sortKey)}
                    onContextMenu={(e) => colPickerRef.current?.openAt(e)}
                  >
                    {col.label}{col.sortKey && getSortIndicator(col.sortKey)}
                  </ResizableTh>
                ))}
                <th style={{ width: '190px' }}>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredStock.length === 0 ? (
                <tr><td colSpan={colVis.visibleColumns.length + 2} style={{ textAlign: 'center', padding: '20px' }}>Geen voorraad gevind</td></tr>
              ) : (
                paginatedStock.map((item) => (
                  <tr key={item.stock_id} onClick={() => handleEditStock(item)} style={{ cursor: "pointer" }}>
                    <td style={{ textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
                      <input type="checkbox" checked={selectedIds.includes(item.stock_id)} onChange={() => toggleOne(item.stock_id)} />
                    </td>
                    {colVis.visibleColumns.map((col) => (
                      <td key={col.key}>{col.render(item)}</td>
                    ))}
                    <td onClick={e => e.stopPropagation()}>
                      <button className="btn-delete" title="Verwyder" onClick={() => handleDeleteStock(item.stock_id)}><IoTrashOutline size={18} /></button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
      <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} totalItems={filteredStock.length} pageSize={100} />
        </div>

      {showModal && modalContent}
      {imageViewerContent}
      {dialog}
    </div>
  );
}

export default StockPage;