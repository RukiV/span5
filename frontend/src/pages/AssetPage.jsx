import React, { useState, useEffect, useRef, useMemo } from "react";
import { Link, useNavigate } from "react-router-dom";
import Select, { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";
import { assetsAPI, assettypesAPI, roomsAPI, authAPI, workOrdersAPI, buildingsAPI, locationAPI, apiClient  } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import ResizableTh from "../components/ResizableTh";
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';
import "../styles/App.css";
import "../styles/Asset.css";
import "./Page.jsx";
import { buildFlatLocationOptions } from './locationSearchUtils';

function AssetPage({ embedded = false }) {
  const { showToast } = useToast();
  const { confirm, dialog } = useConfirmDialog();
  const { user } = useCurrentUser();
  const navigate = useNavigate();
  const [assets, setAssets] = useState([]);
  const [assettypes, setAssettypes] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [terrains, setTerrains] = useState([]); 
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass } = useColumnSort({ defaultSortKey: null });
  const ASSET_COLUMNS = [
    { key: 'id', label: 'ID', render: (a) => a.asset_id, sortKey: 'id', defaultVisible: false },
    { key: 'asset_name', label: 'Naam', render: (a) => a.asset_name, sortKey: 'asset_name', defaultVisible: true },
    { key: 'asset_brand', label: 'Merk', render: (a) => a.asset_brand, sortKey: 'asset_brand', defaultVisible: true },
    { key: 'asset_serial', label: 'Serienommer', render: (a) => a.asset_serial, sortKey: 'asset_serial', defaultVisible: true },
    { key: 'assettype', label: 'Tipe', render: (a) => getAssettypeName(a), sortKey: 'assettype', defaultVisible: true },
    { key: 'isoutdoor', label: 'Buite', render: (a) => a.asset_isoutdoor ? 'Ja' : 'Nee', sortKey: 'isoutdoor', defaultVisible: false },
    { key: 'room', label: 'Lokaal', render: (a) => getRoomName(a), sortKey: 'room', defaultVisible: true },
    { key: 'status', label: 'Status', render: (a) => getStatusLabel(a.asset_status), sortKey: 'status', defaultVisible: true },
    { key: 'created', label: 'Geskep', render: (a) => a.asset_created_datetime ? new Date(a.asset_created_datetime).toLocaleDateString('af-ZA') : '-', sortKey: 'created', defaultVisible: false },
  ];
  const colVis = useColumnVisibility('asset-page', ASSET_COLUMNS);
  const colWidths = useColumnWidths('asset-page', ASSET_COLUMNS);
  const colPickerRef = useRef(null);
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [cascadeToast, setCascadeToast] = useState(null);
  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const [roomFilter, setRoomFilter] = useState("");
  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, rooms, assets), [terrains, buildings, rooms, assets]);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [selectedAsset, setSelectedAsset] = useState(null);
  const [jobs, setJobs] = useState([]);
  const [assetHistory, setAssetHistory] = useState([]);
  const [assetImages, setAssetImages] = useState([]);
  const [selectedImageFiles, setSelectedImageFiles] = useState([]);
  const [selectedImagePreviewUrls, setSelectedImagePreviewUrls] = useState([]);
  const [imagesToDelete, setImagesToDelete] = useState([]);
  const [activeImageViewer, setActiveImageViewer] = useState(null);
  const MAX_ASSET_IMAGES = 1;

  const [showTypeModal, setShowTypeModal] = useState(false);
  const [isEditingType, setIsEditingType] = useState(false);
  const [editingTypeId, setEditingTypeId] = useState(null);
  const [newType, setNewType] = useState({
    assettype_name: "",
    assettype_avg_lifespan: "",
    assettype_min_lifespan: "",
    assettype_max_lifespan: "",
    assettype_service_interval: "",
    assettype_replacement_threshold: "",
  });

  const [newAsset, setNewAsset] = useState({
    asset_name: "",
    asset_brand: "",
    asset_serial: "AK ", 
    asset_isoutdoor: false,
    asset_status: "Aktief",
    assettype_id: null,
    room_id: "",
    location_id: "",
    building_id: "",
  });

  const [invalidFields, setInvalidFields] = useState({});
  const fieldRefs = useRef({});

  useEffect(() => {
    const loadInitialData = async () => {
      await Promise.all([fetchAssets(), fetchAssettypes(), fetchRooms(), fetchBuildings(), fetchTerrains(), fetchJobs()]);
    };
    loadInitialData();
  }, []);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await authAPI.me();
      } catch (err) {
        try { sessionStorage.clear(); localStorage.clear(); } catch(_) {}
        window.location.replace(window.location.origin + '/login');
      }
    })();
    return () => { mounted = false; };
  }, []);

  useEffect(() => {
    if (user?.role_id === 2 && user?.location_id) {
      setTerrainFilter(String(user.location_id));
    } else {
      setTerrainFilter("");
    }
  }, [user]);

  const fetchAssets = async () => {
    try {
      const response = await assetsAPI.getAll();
      setAssets(response.data || []);
    } catch (error) {
      console.error("Error fetching assets:", error);
    } finally {
      setLoading(false);
    }
  };

  const fetchAssettypes = async () => {
    try {
      const response = await assettypesAPI.getAll();
      setAssettypes(response.data || []);
    } catch (error) {
      console.error("Error fetching asset types:", error);
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

  const fetchJobs = async () => {
    try {
      const response = await workOrdersAPI.getAll();
      setJobs(response.data || []);
    } catch (error) {
      console.error("Error fetching jobs:", error);
      setJobs([]);
    }
  };

  const fetchAssetHistory = async (asset_id) => {
    if (!asset_id) return;
    try {
      const response = await assetsAPI.getHistory(asset_id);
      setAssetHistory(response.data || []);
    } catch (error) {
      console.error("Error fetching asset history:", error);
      setAssetHistory([]);
    }
  };

  const fetchAssetImages = async (assetId) => {
    if (!assetId) {
      setAssetImages([]);
      return;
    }

    try {
      const response = await apiClient.image.getByParent("asset", assetId);
      setAssetImages(response.data || []);
    } catch (error) {
      console.error("Fout by laai van bate-beelde:", error);
      setAssetImages([]);
    }
  };

  const getAssetImageUrl = (imageId) => {
    if (!imageId) return null;
    return apiClient.image?.getFileUrl ? apiClient.image.getFileUrl(imageId) : null;
  };

  const handleImageFilesChange = (event) => {
    const files = Array.from(event.target.files || []);
    const remainingSlots = Math.max(0, MAX_ASSET_IMAGES - (selectedImageFiles.length + assetImages.length));
    const incomingFiles = files.slice(0, remainingSlots);

    if (files.length > remainingSlots) {
      showToast({ type: 'warning', title: `Jy kan maksimaal ${MAX_ASSET_IMAGES} beeld per bate oplaai.` });
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

    setAssetImages((prev) => prev.filter((image) => image.image_id !== imageId));
    setImagesToDelete((prev) => (prev.includes(imageId) ? prev : [...prev, imageId]));
  };

  const handleSerialChange = (e) => {
    const value = e.target.value;
    if (!value.startsWith("AK ")) {
      setNewAsset({ ...newAsset, asset_serial: "AK " });
    } else {
      setNewAsset({ ...newAsset, asset_serial: value });
    }
  };

  const handleSaveAsset = async () => {
    let assetData = {};
    let savedAssetId = isEditing ? editingId : null;
    
    try {
      const errors = {};
      if (!newAsset.asset_name.trim()) errors.asset_name = true;
      if (!newAsset.asset_brand.trim()) errors.asset_brand = true;
      const cleanedSerial = newAsset.asset_serial.trim();
      const serialRegex = /^AK [A-Za-z]{2}\d{6}$/;
      if (!serialRegex.test(cleanedSerial)) {
        showToast({ type: 'warning', title: 'Ongeldige serienommer-formaat! Dit moet in die formaat AK XX000000 wees (bv. AK MT123456).' });
        return;
      }
      const isDuplicate = assets.some((asset) => {
        if (isEditing) {
          return asset.asset_serial.toLowerCase() === cleanedSerial.toLowerCase() && asset.asset_id !== editingId;
        } else {
          return asset.asset_serial.toLowerCase() === cleanedSerial.toLowerCase();
        }
      });
      if (isDuplicate) {
        showToast({ type: 'warning', title: `Hierdie serienommer (${cleanedSerial}) is reeds in gebruik. Voer asseblief 'n unieke serienommer in.` });
        return;
      }
      if (!newAsset.assettype_id) errors.assettype_id = true;
      if (!newAsset.room_id) errors.location_id = true;
      if (Object.keys(errors).length > 0) {
        setInvalidFields(errors);
        const firstKey = Object.keys(errors)[0];
        fieldRefs.current[firstKey]?.scrollIntoView({ behavior: "smooth", block: "center" });
        fieldRefs.current[firstKey]?.focus();
        return;
      }
      setInvalidFields({});

      assetData = {
        asset_name: newAsset.asset_name,
        asset_brand: newAsset.asset_brand,
        asset_serial: cleanedSerial,
        asset_status: newAsset.asset_status,
        asset_isoutdoor: newAsset.asset_isoutdoor,
        assettype_id: Number(newAsset.assettype_id),
        room_id: Number(newAsset.room_id),
      };

      if (isEditing) {
        await assetsAPI.update(editingId, assetData);
        savedAssetId = editingId;
      } else {
        const response = await assetsAPI.create(assetData);
        savedAssetId = response?.data?.asset_id ?? response?.data?.id ?? null;
      }

      if (!savedAssetId) {
        throw new Error("Kon nie die bate-ID na stoor terugkry nie.");
      }

      if (isEditing) {
        for (const imageId of imagesToDelete) {
          await apiClient.image.delete(imageId);
        }
      }

      if (selectedImageFiles.length > 0) {
        for (const file of selectedImageFiles.slice(0, MAX_ASSET_IMAGES)) {
          const formData = new FormData();
          formData.append("file", file);
          await apiClient.image.uploadForParent(savedAssetId, "asset", formData);
        }
      }

      handleCloseModal();
      fetchAssets();
      fetchAssetImages(savedAssetId);
    } catch (error) {
      console.error("Bate stoor het gefaal", error);
      if (error.response) {
        console.error(`Status Kode: ${error.response.status}`);
        console.error("Data:", error.response.data);
      } else if (error.request) {
        console.error("Geen antwoord van die bediener nie.");
      }
      showToast({ type: 'error', title: 'Fout tydens besparing.' });
    }
  };

  const handleDeleteAsset = async (id) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie item verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;
    try {
      await assetsAPI.delete(id);
      fetchAssets();
    } catch (error) {
      console.error("Error deleting asset:", error);
      showToast({ type: 'error', title: 'Fout tydens verwydering. Probeer asseblief weer.' });
    }
  };

  const handleEditAsset = (item) => {
    const room = rooms.find((r) => r.room_id === item.room_id);
    const building = room ? buildings.find((b) => b.building_id === room.building_id) : null;
    
    setIsEditing(true);
    setEditingId(item.asset_id);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewAsset({
      asset_name: item.asset_name || "",
      asset_brand: item.asset_brand || "",
      asset_serial: item.asset_serial || "AK ",
      asset_isoutdoor: item.asset_isoutdoor || false,
      asset_status: item.asset_status || "Aktief",
      assettype_id: item.assettype_id || null,
      room_id: item.room_id ? Number(item.room_id) : "",
      location_id: building ? building.location_id : "",
      building_id: room ? room.building_id : ""
    });
    fetchAssetImages(item.asset_id);
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setAssetImages([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewAsset({ asset_name: "", asset_brand: "", asset_serial: "AK ", asset_isoutdoor: false, asset_status: "Aktief", assettype_id: null, room_id: "", location_id: "", building_id: "" });
  };

  const handleNewAsset = () => {
    setIsEditing(false);
    setEditingId(null);
    setSelectedImageFiles([]);
    setSelectedImagePreviewUrls([]);
    setAssetImages([]);
    setImagesToDelete([]);
    setActiveImageViewer(null);
    setNewAsset({ asset_name: "", asset_brand: "", asset_serial: "AK ", asset_isoutdoor: false, asset_status: "Aktief", assettype_id: null, room_id: "", location_id: "", building_id: "" });
    setShowModal(true);
  };

  const getStatusLabel = (status) => {
    switch (status) {
      case "Aktief": return "Aktief";
      case "Instandhouding": return "Onderhoud";
      case "Afgedank": return "Afgedank";
      case "Onaktief": return "Onaktief";
      default: return status;
    }
  };

  const getRoomName = (item) => {
    if (!item.room_id) return "-";
    const room = rooms.find((roomItem) => roomItem.room_id === item.room_id);
    return room ? room.room_name : `Room ${item.room_id}`;
  };

  const getAssettypeName = (item) => {
    if (!item.assettype_id) return "-";
    const at = assettypes.find((t) => t.assettype_id === item.assettype_id);
    return at ? at.assettype_name : `Tipe ${item.assettype_id}`;
  };

  const getAssetLocationId = (asset) => {
    if (!asset.room_id) return null;
    const room = rooms.find((r) => r.room_id === asset.room_id);
    if (!room) return null;
    const building = buildings.find((b) => b.building_id === room.building_id);
    return building ? building.location_id : null;
  };

  const getAssetBuildingId = (asset) => {
    if (!asset.room_id) return null;
    const room = rooms.find((r) => r.room_id === asset.room_id);
    return room ? room.building_id : null;
  };

  const handleViewHistory = (asset) => {
    setSelectedAsset(asset);
    fetchAssetHistory(asset.asset_id);
    setShowHistoryModal(true);
  };

  const handleOpenJobcard = (jobcardId) => {
    setShowHistoryModal(false);
    navigate(`/work-orders?search=${jobcardId}`);
  };

  // ---- Asset Type CRUD ----

  const handleOpenTypeModal = (typeItem) => {
    if (typeItem) {
      setIsEditingType(true);
      setEditingTypeId(typeItem.assettype_id);
      setNewType({
        assettype_name: typeItem.assettype_name || "",
        assettype_avg_lifespan: typeItem.assettype_avg_lifespan != null ? String(typeItem.assettype_avg_lifespan) : "",
        assettype_min_lifespan: typeItem.assettype_min_lifespan != null ? String(typeItem.assettype_min_lifespan) : "",
        assettype_max_lifespan: typeItem.assettype_max_lifespan != null ? String(typeItem.assettype_max_lifespan) : "",
        assettype_service_interval: typeItem.assettype_service_interval != null ? String(typeItem.assettype_service_interval) : "",
        assettype_replacement_threshold: typeItem.assettype_replacement_threshold != null ? String(typeItem.assettype_replacement_threshold) : "",
      });
    } else {
      setIsEditingType(false);
      setEditingTypeId(null);
      setNewType({
        assettype_name: "",
        assettype_avg_lifespan: "",
        assettype_min_lifespan: "",
        assettype_max_lifespan: "",
        assettype_service_interval: "",
        assettype_replacement_threshold: "",
      });
    }
    setShowTypeModal(true);
  };

  const handleCloseTypeModal = () => {
    setShowTypeModal(false);
    setIsEditingType(false);
    setEditingTypeId(null);
  };

  const handleSaveType = async () => {
    if (!newType.assettype_name.trim()) {
      showToast({ type: 'warning', title: "Voer asseblief 'n tipe naam in." });
      return;
    }
    const payload = {
      assettype_name: newType.assettype_name.trim(),
      assettype_avg_lifespan: newType.assettype_avg_lifespan ? Number(newType.assettype_avg_lifespan) : null,
      assettype_min_lifespan: newType.assettype_min_lifespan ? Number(newType.assettype_min_lifespan) : null,
      assettype_max_lifespan: newType.assettype_max_lifespan ? Number(newType.assettype_max_lifespan) : null,
      assettype_service_interval: newType.assettype_service_interval ? Number(newType.assettype_service_interval) : null,
      assettype_replacement_threshold: newType.assettype_replacement_threshold ? Number(newType.assettype_replacement_threshold) : null,
    };
    try {
      if (isEditingType) {
        await assettypesAPI.update(editingTypeId, payload);
      } else {
        await assettypesAPI.create(payload);
      }
      handleCloseTypeModal();
      fetchAssettypes();
    } catch (error) {
      console.error("Error saving asset type:", error);
      showToast({ type: 'error', title: 'Fout tydens stoor van bate tipe.' });
    }
  };

  const handleDeleteType = async (id) => {
    const confirmed = await confirm({ message: "Is jy seker jy wil hierdie bate tipe verwyder?", variant: 'danger', confirmLabel: 'Verwyder', cancelLabel: 'Kanselleer' });
    if (!confirmed) return;
    try {
      await assettypesAPI.delete(id);
      fetchAssettypes();
    } catch (error) {
      console.error("Error deleting asset type:", error);
      showToast({ type: 'error', title: 'Fout tydens verwydering van bate tipe.' });
    }
  };
  
  const filteredItems = [...assets]
    .filter((asset) => {
      if (terrainFilter) {
        const locId = getAssetLocationId(asset);
        if (String(locId) !== String(terrainFilter)) return false;
      }
      if (buildingFilter) {
        const bldId = getAssetBuildingId(asset);
        if (String(bldId) !== String(buildingFilter)) return false;
      }
      if (roomFilter) {
        if (String(asset.room_id) !== String(roomFilter)) return false;
      }
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;
      const getColumnValue = (column) => {
        switch (column) {
          case "asset_name": return asset.asset_name;
          case "asset_brand": return asset.asset_brand;
          case "asset_serial": return asset.asset_serial;
          case "asset_isoutdoor": return asset.asset_isoutdoor ? "Ja" : "Nee";
          case "room": return getRoomName(asset);
          case "status": return getStatusLabel(asset.asset_status);
          default: return `${asset.asset_name || ""} ${asset.asset_serial || ""} ${getRoomName(asset)} ${getStatusLabel(asset.asset_status)}`;
        }
      };
      if (filterColumn === "all") {
        return [asset.asset_name, asset.asset_serial, getRoomName(asset), getStatusLabel(asset.asset_status)]
          .some((value) => String(value).toLowerCase().includes(query));
      }
      return String(getColumnValue(filterColumn) ?? "").toLowerCase().includes(query);
    })
    .sort((a, b) => {
      if (!sortKey) return 0;
      const dir = sortDirection === "asc" ? 1 : -1;
      if (sortKey === "asset_name") return String(a.asset_name || "").localeCompare(String(b.asset_name || ""), "af", { sensitivity: "base" }) * dir;
      if (sortKey === "asset_brand") return String(a.asset_brand || "").localeCompare(String(b.asset_brand || ""), "af", { sensitivity: "base" }) * dir;
      if (sortKey === "asset_serial") return String(a.asset_serial || "").localeCompare(String(b.asset_serial || ""), "af", { sensitivity: "base" }) * dir;
      if (sortKey === "assettype") return String(getAssettypeName(a) || "").localeCompare(String(getAssettypeName(b) || ""), "af", { sensitivity: "base" }) * dir;
      if (sortKey === "isoutdoor") return String(a.asset_isoutdoor ? "Ja" : "Nee").localeCompare(String(b.asset_isoutdoor ? "Ja" : "Nee"), "af", { sensitivity: "base" }) * dir;
      if (sortKey === "room") return String(getRoomName(a) || "").localeCompare(String(getRoomName(b) || ""), "af", { sensitivity: "base" }) * dir;
      if (sortKey === "status") return String(getStatusLabel(a.asset_status)).localeCompare(String(getStatusLabel(b.asset_status)), "af", { sensitivity: "base" }) * dir;
      return 0;
    });

  const getStatusClass = (status) => {
    switch (status) {
      case "Aktief": return "status-aktief";
      case "Instandhouding": return "status-onderhoud";
      case "Afgedank": return "status-waarskuwing";
      case "Onaktief": return "status-waarskuwing";
      default: return "status-waarskuwing";
    }
  };

  const assettypeOptions = assettypes.map(at => ({
    value: String(at.assettype_id),
    label: at.assettype_name
  }));

  const filterColumnOptions = [
    { value: "all", label: "Alle kolomme" },
    { value: "asset_name", label: "Naam" },
    { value: "asset_brand", label: "Brand" },
    { value: "asset_serial", label: "Serienommer" },
    { value: "asset_isoutdoor", label: "Buite" },
    { value: "room", label: "Lokaal" },
    { value: "status", label: "Status" }
  ];


  const statusOptions = [
    { value: "Aktief", label: "Aktief" },
    { value: "Instandhouding", label: "Onderhoud" },
    { value: "Afgedank", label: "Afgedank" },
    { value: "Onaktief", label: "Onaktief" }
  ];

  if (loading) {
    return <div className="main"><div className="content">Laai...</div></div>;
  }

  const pageContent = (
    <>
      <div className="controls">
        <div className="controls-left">
          <div style={{ display: "flex", alignItems: "center", gap: "0.35rem" }}>
            <input
              type="text"
              placeholder="Soek bates..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <Select
            className="basic-single"
            classNamePrefix="select"
            value={filterColumnOptions.find(option => option.value === filterColumn)}
            onChange={(selectedOption) => setFilterColumn(selectedOption.value)}
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
                          return option.data._cascadeLevel <= 2 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        if (cascadeCount === 1)
                          return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 2 && String(option.data._fields.location_id) === String(terrainFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        if (cascadeCount === 2)
                          return option.data._cascadeLevel >= 2 && option.data._cascadeLevel <= 2 && String(option.data._fields.building_id) === String(buildingFilter) && option.label.toLowerCase().includes(rawInput.toLowerCase());
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
            columns={ASSET_COLUMNS}
            visibleColumns={colVis.visibleColumns}
            toggleColumn={colVis.toggleColumn}
            resetVisibility={colVis.resetVisibility}
            onResetWidths={colWidths.resetWidths}
          />
          <button className="btn-add" onClick={() => handleOpenTypeModal(null)}>Bestuur Bate Tipes</button>
          <button className="btn-add" onClick={handleNewAsset}>+ Nuwe Bate</button>
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
            <th style={{ width: '120px' }}>Aksies</th>
          </tr>
        </thead>
        <tbody>
          {filteredItems.length === 0 ? (
            <tr><td colSpan={colVis.visibleColumns.length + 1} style={{ textAlign: 'center', padding: '20px' }}>Geen bates gevind</td></tr>
          ) : (
            filteredItems.map((item) => (
              <tr key={item.asset_id} onClick={() => handleEditAsset(item)} style={{ cursor: "pointer" }}>
                {colVis.visibleColumns.map((col) => (
                  <td key={col.key}>{col.render(item)}</td>
                ))}
                <td onClick={e => e.stopPropagation()}>
                  <button className="btn-edit" onClick={() => { setSelectedAsset(item); fetchAssetHistory(item.asset_id); fetchAssetImages(item.asset_id); setShowHistoryModal(true); }}>Geskiedenis</button>
                  <button className="btn-delete" onClick={() => handleDeleteAsset(item.asset_id)}>Verwyder</button>
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
          <h3>{isEditing ? "Wysig" : "Nuwe"} Bate {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
          <span className="close" onClick={handleCloseModal}>&times;</span>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>Naam *</label>
            <input
              ref={el => fieldRefs.current.asset_name = el}
              type="text"
              className={invalidFields.asset_name ? "field-invalid" : ""}
              value={newAsset.asset_name}
              onChange={(e) => {
                setNewAsset({ ...newAsset, asset_name: e.target.value });
                if (invalidFields.asset_name) setInvalidFields(prev => { const n = {...prev}; delete n.asset_name; return n; });
              }}
            />
          </div>
          <div className="input-group">
            <label>Brand *</label>
            <input
              ref={el => fieldRefs.current.asset_brand = el}
              type="text"
              className={invalidFields.asset_brand ? "field-invalid" : ""}
              value={newAsset.asset_brand}
              onChange={(e) => {
                setNewAsset({ ...newAsset, asset_brand: e.target.value });
                if (invalidFields.asset_brand) setInvalidFields(prev => { const n = {...prev}; delete n.asset_brand; return n; });
              }}
            />
          </div>
          <div className="input-group">
            <label>Serienommer *</label>
            <input
              type="text"
              value={newAsset.asset_serial}
              onChange={handleSerialChange}
              placeholder="bv. AK MT000001"
            />
          </div>
        </div>
        <div className="input-row">
          <div className="input-group">
            <label>
              <input
                type="checkbox"
                checked={newAsset.asset_isoutdoor}
                onChange={(e) => setNewAsset({ ...newAsset, asset_isoutdoor: e.target.checked })}
              />
              Buite
            </label>
          </div>
          <div className={invalidFields.assettype_id ? "input-group field-invalid" : "input-group"}>
            <label>Bate Tipe *</label>
            <Select
              className="basic-single"
              classNamePrefix="select"
              placeholder="Kies 'n tipe..."
              isSearchable={true}
              options={assettypeOptions}
              value={assettypeOptions.find(o => Number(o.value) === Number(newAsset.assettype_id)) || null}
              onChange={(selected) => {
                setNewAsset({ ...newAsset, assettype_id: selected ? Number(selected.value) : null });
                if (invalidFields.assettype_id) setInvalidFields(prev => { const n = {...prev}; delete n.assettype_id; return n; });
              }}
            />
          </div>
        </div>

        <div className="input-row">
          <div className={invalidFields.location_id ? "input-group field-invalid" : "input-group"} style={{ position: "relative", flex: 1 }}>
            <label>Ligging *</label>
            {(() => {
              const cascadeCount = [newAsset.location_id, newAsset.building_id, newAsset.room_id].filter(Boolean).length;
              const clearFromLevel = (levelIndex) => {
                if (levelIndex <= 0) setNewAsset(p => ({...p, location_id: "", building_id: "", room_id: ""}));
                else if (levelIndex === 1) setNewAsset(p => ({...p, building_id: "", room_id: ""}));
                else if (levelIndex === 2) setNewAsset(p => ({...p, room_id: ""}));
              };
              const breadcrumbData = [{ level: -1, name: "Terreine" }];
              if (newAsset.location_id) breadcrumbData.push({ level: 0, name: terrains?.find(t => String(t.location_id) === String(newAsset.location_id))?.location_name || newAsset.location_id });
              if (newAsset.building_id) breadcrumbData.push({ level: 1, name: buildings?.find(b => String(b.building_id) === String(newAsset.building_id))?.building_name || newAsset.building_id });
              if (newAsset.room_id) breadcrumbData.push({ level: 2, name: rooms?.find(r => String(r.room_id) === String(newAsset.room_id))?.room_name || newAsset.room_id });
              const renderBreadcrumb = () => (
                <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: "4px", fontSize: "13px", color: "#111827", marginTop: "6px", marginBottom: "6px" }}>
                  {breadcrumbData.map((item, i) => {
                    const isLast = i === breadcrumbData.length - 1;
                    const showArrow = isLast ? cascadeCount < 3 : true;
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
                      placeholder={["Kies Terrein...","Kies Gebou...","Kies Lokaal...","Ligging voltooi"][cascadeCount]}
                      isClearable
                      isDisabled={cascadeCount >= 3}
                      closeMenuOnSelect={false}
                      components={{ Control: CascadeControl }}
                      options={allLocationOptions}
                      filterOption={(option, rawInput) => {
                        if (rawInput) {
                          if (cascadeCount === 0)
                            return option.data._cascadeLevel <= 2 && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 1)
                            return option.data._cascadeLevel >= 1 && option.data._cascadeLevel <= 2 && String(option.data._fields.location_id) === String(newAsset.location_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                          if (cascadeCount === 2)
                            return option.data._cascadeLevel >= 2 && option.data._cascadeLevel <= 2 && String(option.data._fields.building_id) === String(newAsset.building_id) && option.label.toLowerCase().includes(rawInput.toLowerCase());
                        }
                        if (cascadeCount === 0) return option.data._cascadeLevel === 0;
                        if (cascadeCount === 1) return option.data._cascadeLevel === 1 && String(option.data._parentId) === String(newAsset.location_id);
                        if (cascadeCount === 2) return option.data._cascadeLevel === 2 && String(option.data._parentId) === String(newAsset.building_id);
                        return false;
                      }}
                      value={null}
                      onChange={(selectedOption) => {
                        if (!selectedOption) return;
                        setNewAsset(p => ({...p, ...selectedOption._fields}));
                        if (invalidFields.location_id) setInvalidFields(prev => { const n = {...prev}; delete n.location_id; return n; });
                        const labels = ["Terrein","Gebou","Lokaal"];
                        setCascadeToast(`✓ ${labels[selectedOption._cascadeLevel]} suksesvol geselekteer`);
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

        <div className="input-row">
          <div className="input-group">
            <label>Status</label>
            <Select
              className="basic-single"
              classNamePrefix="select"
              value={statusOptions.find(option => option.value === newAsset.asset_status)}
              onChange={(selectedOption) => setNewAsset({ ...newAsset, asset_status: selectedOption ? selectedOption.value : "Aktief" })}
              options={statusOptions}
              isSearchable={false}
            />
          </div>
        </div>

        <div className="input-row">
          <div className="input-group" style={{ width: "100%" }}>
            <label>Beelde</label>
            <input type="file" accept="image/*" multiple onChange={handleImageFilesChange} />
            <div className="image-preview-grid">
              {assetImages.map((image) => (
                <div key={image.image_id} className="record-image-card">
                  <img
                    src={getAssetImageUrl(image.image_id)}
                    alt={image.filename || "Batebeeld"}
                    className="record-image-thumb"
                    onClick={() => setActiveImageViewer(getAssetImageUrl(image.image_id))}
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
          <button className="btn-add" onClick={handleSaveAsset}>{isEditing ? "Opdateer" : "Stoor"}</button>
        </div>
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

        {/* History Modal */}
        {showHistoryModal && selectedAsset && (
          <div className="modal" style={{ display: "flex" }}>
            <div className="modal-content">
              <div className="modal-header">
                <h3>Geskiedenis van {(selectedAsset.asset_serial)} - {selectedAsset.asset_name}</h3>
                <span className="close" onClick={() => setShowHistoryModal(false)}>&times;</span>
              </div>
              <div className="modal-body">
                {assetHistory && assetHistory.length > 0 ? (
                  <table className="assets-table">
                    <tbody>
                      {assetHistory.map((event) => {
                        const eventDate = new Date(event.event_datetime).toLocaleDateString('af-ZA');
                        const eventTime = new Date(event.event_datetime).toLocaleTimeString('af-ZA', {
                          hour: '2-digit',
                          minute: '2-digit',
                        });
                        const eventText = event.event_description
                          ? `${event.event_title} — ${event.event_description}`
                          : event.event_title;

                        return (
                          <React.Fragment key={`${event.source}-${event.event_id || event.event_datetime}`}>
                            <tr>
                              <td colSpan="3" className="history-date-row">
                                {eventDate}
                              </td>
                              <td>{eventTime}</td>
                              <td>{eventText}</td>
                              <td>
                                {event.source === 'job' && event.event_id ? (
                                  <button
                                    type="button"
                                    className="btn-view"
                                    onClick={() => handleOpenJobcard(event.event_id)}
                                  >
                                    Bekyk
                                  </button>
                                ) : (
                                  <span></span>
                                )}
                              </td>
                            </tr>
                          </React.Fragment>
                        );
                      })}
                    </tbody>
                  </table>
                ) : (
                  <p>Geen geskiedenis beskikbaar vir hierdie bate.</p>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Asset Type Management Modal */}
        {showTypeModal && (
          <div className="modal" style={{ display: "flex" }}>
            <div className="modal-content" style={{ maxWidth: "700px" }}>
              <div className="modal-header">
                <h3>{isEditingType ? "Wysig Bate Tipe" : "Nuwe Bate Tipe"}</h3>
                <span className="close" onClick={handleCloseTypeModal}>&times;</span>
              </div>
              <div className="modal-body">
                <div className="input-row">
                  <div className="input-group" style={{ width: "100%" }}>
                    <label>Naam *</label>
                    <input
                      type="text"
                      value={newType.assettype_name}
                      onChange={(e) => setNewType({ ...newType, assettype_name: e.target.value })}
                      placeholder="bv. Algemene Toerusting"
                    />
                  </div>
                </div>
                <div className="input-row">
                  <div className="input-group">
                    <label>Gem. Lewensduur (maande)</label>
                    <input
                      type="number"
                      min="0"
                      value={newType.assettype_avg_lifespan}
                      onChange={(e) => setNewType({ ...newType, assettype_avg_lifespan: e.target.value })}
                    />
                  </div>
                  <div className="input-group">
                    <label>Min Lewensduur (maande)</label>
                    <input
                      type="number"
                      min="0"
                      value={newType.assettype_min_lifespan}
                      onChange={(e) => setNewType({ ...newType, assettype_min_lifespan: e.target.value })}
                    />
                  </div>
                  <div className="input-group">
                    <label>Maks Lewensduur (maande)</label>
                    <input
                      type="number"
                      min="0"
                      value={newType.assettype_max_lifespan}
                      onChange={(e) => setNewType({ ...newType, assettype_max_lifespan: e.target.value })}
                    />
                  </div>
                </div>
                <div className="input-row">
                  <div className="input-group">
                    <label>Diensinterval (maande)</label>
                    <input
                      type="number"
                      min="0"
                      value={newType.assettype_service_interval}
                      onChange={(e) => setNewType({ ...newType, assettype_service_interval: e.target.value })}
                    />
                  </div>
                  <div className="input-group">
                    <label>Vervangingsdrempel (foute)</label>
                    <input
                      type="number"
                      min="0"
                      value={newType.assettype_replacement_threshold}
                      onChange={(e) => setNewType({ ...newType, assettype_replacement_threshold: e.target.value })}
                    />
                  </div>
                </div>

                <h4 style={{ marginTop: "20px", marginBottom: "8px", color: "#6b3f1d" }}>Bestaande Bate Tipes</h4>
                <div style={{ maxHeight: "250px", overflowY: "auto" }}>
                  <table className="standard-table">
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>Naam</th>
                        <th>Gem. Lewensduur</th>
                        <th>Diensinterval</th>
                        <th>Drempel</th>
                        <th>Aksies</th>
                      </tr>
                    </thead>
                    <tbody>
                      {assettypes.map((at) => (
                        <tr key={at.assettype_id}>
                          <td>{at.assettype_id}</td>
                          <td>{at.assettype_name}</td>
                          <td>{at.assettype_avg_lifespan != null ? `${at.assettype_avg_lifespan}m` : '-'}</td>
                          <td>{at.assettype_service_interval != null ? `${at.assettype_service_interval}m` : '-'}</td>
                          <td>{at.assettype_replacement_threshold != null ? at.assettype_replacement_threshold : '-'}</td>
                          <td>
                            <button className="btn-edit" onClick={() => handleOpenTypeModal(at)}>Wysig</button>
                            <button className="btn-delete" onClick={() => handleDeleteType(at.assettype_id)}>Verwyder</button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
              <div className="modal-footer">
                <button className="btn-cancel" onClick={handleCloseTypeModal}>Kanselleer</button>
                <button className="btn-add" onClick={handleSaveType}>{isEditingType ? "Opdateer" : "Stoor"}</button>
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
      {imageViewerContent}

      {/* History Modal */}
      {showHistoryModal && selectedAsset && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>Geskiedenis van {(selectedAsset.asset_serial)} - {selectedAsset.asset_name}</h3>
              <span className="close" onClick={() => setShowHistoryModal(false)}>&times;</span>
            </div>
            <div className="modal-body">
              {assetHistory && assetHistory.length > 0 ? (
                <table className="assets-table">
                  <tbody>
                    {assetHistory.map((event) => {
                      const eventDate = new Date(event.event_datetime).toLocaleDateString('af-ZA');
                      const eventTime = new Date(event.event_datetime).toLocaleTimeString('af-ZA', {
                        hour: '2-digit',
                        minute: '2-digit',
                      });
                      const eventText = event.event_description
                        ? `${event.event_title} — ${event.event_description}`
                        : event.event_title;

                      return (
                        <React.Fragment key={`${event.source}-${event.event_id || event.event_datetime}`}>
                          <tr>
                            <td colSpan="3" className="history-date-row">
                              {eventDate}
                            </td>
                            <td>{eventTime}</td>
                            <td>{eventText}</td>
                            <td>
                              {event.source === 'job' && event.event_id ? (
                                <button
                                  type="button"
                                  className="btn-view"
                                  onClick={() => handleOpenJobcard(event.event_id)}
                                >
                                  Bekyk
                                </button>
                              ) : (
                                <span></span>
                              )}
                            </td>
                          </tr>
                        </React.Fragment>
                      );
                    })}
                  </tbody>
                </table>
              ) : (
                <p>Geen geskiedenis beskikbaar vir hierdie bate.</p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Asset Type Management Modal */}
      {showTypeModal && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content" style={{ maxWidth: "700px" }}>
            <div className="modal-header">
              <h3>{isEditingType ? "Wysig Bate Tipe" : "Nuwe Bate Tipe"}</h3>
              <span className="close" onClick={handleCloseTypeModal}>&times;</span>
            </div>
            <div className="modal-body">
              {/* Type form */}
              <div className="input-row">
                <div className="input-group" style={{ width: "100%" }}>
                  <label>Naam *</label>
                  <input
                    type="text"
                    value={newType.assettype_name}
                    onChange={(e) => setNewType({ ...newType, assettype_name: e.target.value })}
                    placeholder="bv. Algemene Toerusting"
                  />
                </div>
              </div>
              <div className="input-row">
                <div className="input-group">
                  <label>Gem. Lewensduur (maande)</label>
                  <input
                    type="number"
                    min="0"
                    value={newType.assettype_avg_lifespan}
                    onChange={(e) => setNewType({ ...newType, assettype_avg_lifespan: e.target.value })}
                  />
                </div>
                <div className="input-group">
                  <label>Min Lewensduur (maande)</label>
                  <input
                    type="number"
                    min="0"
                    value={newType.assettype_min_lifespan}
                    onChange={(e) => setNewType({ ...newType, assettype_min_lifespan: e.target.value })}
                  />
                </div>
                <div className="input-group">
                  <label>Maks Lewensduur (maande)</label>
                  <input
                    type="number"
                    min="0"
                    value={newType.assettype_max_lifespan}
                    onChange={(e) => setNewType({ ...newType, assettype_max_lifespan: e.target.value })}
                  />
                </div>
              </div>
              <div className="input-row">
                <div className="input-group">
                  <label>Diensinterval (maande)</label>
                  <input
                    type="number"
                    min="0"
                    value={newType.assettype_service_interval}
                    onChange={(e) => setNewType({ ...newType, assettype_service_interval: e.target.value })}
                  />
                </div>
                <div className="input-group">
                  <label>Vervangingsdrempel (foute)</label>
                  <input
                    type="number"
                    min="0"
                    value={newType.assettype_replacement_threshold}
                    onChange={(e) => setNewType({ ...newType, assettype_replacement_threshold: e.target.value })}
                  />
                </div>
              </div>

              {/* Existing types table */}
              <h4 style={{ marginTop: "20px", marginBottom: "8px", color: "#6b3f1d" }}>Bestaande Bate Tipes</h4>
              <div style={{ maxHeight: "250px", overflowY: "auto" }}>
                <table className="standard-table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Naam</th>
                      <th>Gem. Lewensduur</th>
                      <th>Diensinterval</th>
                      <th>Drempel</th>
                      <th>Aksies</th>
                    </tr>
                  </thead>
                  <tbody>
                    {assettypes.map((at) => (
                      <tr key={at.assettype_id}>
                        <td>{at.assettype_id}</td>
                        <td>{at.assettype_name}</td>
                        <td>{at.assettype_avg_lifespan != null ? `${at.assettype_avg_lifespan}m` : '-'}</td>
                        <td>{at.assettype_service_interval != null ? `${at.assettype_service_interval}m` : '-'}</td>
                        <td>{at.assettype_replacement_threshold != null ? at.assettype_replacement_threshold : '-'}</td>
                        <td>
                          <button className="btn-edit" onClick={() => handleOpenTypeModal(at)}>Wysig</button>
                          <button className="btn-delete" onClick={() => handleDeleteType(at.assettype_id)}>Verwyder</button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseTypeModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleSaveType}>{isEditingType ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}
      {dialog}
    </div>
  );
}

export default AssetPage;