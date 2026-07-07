import React, { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import Select from "react-select";
import { assetsAPI, roomsAPI, authAPI, workOrdersAPI, buildingsAPI, locationAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import "../styles/App.css";
import "../styles/Asset.css";
import "./Page.jsx";
import { useLogout } from "./Page.jsx";
import Sidebar from '../components/Sidebar';

function AssetPage() {
  const { isAdmin, user } = useCurrentUser();
  const logout = useLogout();
  const navigate = useNavigate();
  const [assets, setAssets] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [terrains, setTerrains] = useState([]); 
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterColumn, setFilterColumn] = useState("all");
  const [sortBy, setSortBy] = useState("default");
  const [sortDirection, setSortDirection] = useState("asc");
  const [showModal, setShowModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [selectedAsset, setSelectedAsset] = useState(null);
  const [jobs, setJobs] = useState([]);
  const [assetHistory, setAssetHistory] = useState([]);

  const [newAsset, setNewAsset] = useState({
    asset_name: "",
    asset_brand: "",
    asset_serial: "AK-", 
    asset_isoutdoor: false,
    asset_status: "Aktief", // Verander vanaf "active" na backend-verwagte waarde
    assettype_id: 1, 
    room_id: "",
  });

  useEffect(() => {
    const loadInitialData = async () => {
      await Promise.all([fetchAssets(), fetchRooms(), fetchBuildings(), fetchTerrains(), fetchJobs()]);
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

  const handleSerialChange = (e) => {
    const value = e.target.value;
    if (!value.startsWith("AK-")) {
      setNewAsset({ ...newAsset, asset_serial: "AK-" });
    } else {
      setNewAsset({ ...newAsset, asset_serial: value });
    }
  };

  const handleSaveAsset = async () => {
    let assetData = {};
    
    try {
      if (!newAsset.asset_name.trim()) {
        alert("Voer asseblief 'n batenaam in");
        return;
      }
      
      const cleanedSerial = newAsset.asset_serial.trim();

      const serialRegex = /^AK-[A-Za-z]{2}\d{6}$/;
      if (!serialRegex.test(cleanedSerial)) {
        alert("Ongeldige serienommer-formaat! Dit moet in die formaat AK-XX000000 wees (bv. AK-MT123456).");
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
        alert(`Hierdie serienommer (${cleanedSerial}) is reeds in gebruik. Voer asseblief 'n unieke serienommer in.`);
        return;
      }

      if (!newAsset.room_id) {
        alert("Kies asseblief 'n lokaal vir hierdie bate.");
        return;
      }

      assetData = {
        asset_name: newAsset.asset_name,
        asset_brand: newAsset.asset_brand,
        asset_serial: cleanedSerial,
        asset_status: newAsset.asset_status,
        asset_isoutdoor: newAsset.asset_isoutdoor,
        assettype_id: 1,
        room_id: Number(newAsset.room_id),
      };

      console.log("--- POGING OM BATE TE STOOR ---");
      console.log("Payload wat na API gestuur word:", assetData);

      if (isEditing) {
        await assetsAPI.update(editingId, assetData);
      } else {
        await assetsAPI.create(assetData);
      }

      handleCloseModal();
      fetchAssets();
    } catch (error) {
      console.error("!!! BATE STOOR HET GEFAAL !!!");
      console.error("Besonderhede van die Axios/Netwerk fout:", error);
      
      if (error.response) {
        console.error(`Status Kode: ${error.response.status}`);
        console.error("Data teruggestuur deur Backend (Valideringsfout):", error.response.data);
        console.log("Die data wat jy probeer stuur het was:", assetData);
      } else if (error.request) {
        console.error("Geen antwoord van die bediener ontvang nie. Is die API aan?", error.request);
      } else {
        console.error("Fout met die opstel van die versoek:", error.message);
      }

      alert("Fout tydens besparing. Maak jou F12 Browser Console oop vir volledige besonderhede.");
    }
  };

  const handleDeleteAsset = async (id) => {
    if (!window.confirm("Is jy seker jy wil hierdie item verwyder?")) {
      return;
    }
    try {
      await assetsAPI.delete(id);
      fetchAssets();
    } catch (error) {
      console.error("Error deleting asset:", error);
      alert("Fout tydens verwydering. Probeer asseblief weer.");
    }
  };

  const handleEditAsset = (item) => {
    const room = rooms.find((r) => r.room_id === item.room_id);
    const building = room ? buildings.find((b) => b.building_id === room.building_id) : null;
    
    setIsEditing(true);
    setEditingId(item.asset_id);
    setNewAsset({
      asset_name: item.asset_name || "",
      asset_brand: item.asset_brand || "",
      asset_serial: item.asset_serial || "AK-",
      asset_isoutdoor: item.asset_isoutdoor || false,
      asset_status: item.asset_status || "Aktief", // Verander na "Aktief" as terugval
      assettype_id: item.assettype_id || 1,
      room_id: item.room_id ? Number(item.room_id) : "",
      location_id: building ? building.location_id : "",
      building_id: room ? room.building_id : ""
    });
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setIsEditing(false);
    setEditingId(null);
    setNewAsset({ asset_name: "", asset_brand: "", asset_serial: "AK-", asset_isoutdoor: false, asset_status: "Aktief", assettype_id: 1, room_id: "" });
  };

  const handleNewAsset = () => {
    setIsEditing(false);
    setEditingId(null);
    setNewAsset({ asset_name: "", asset_brand: "", asset_serial: "AK-", asset_isoutdoor: false, asset_status: "Aktief", assettype_id: 1, room_id: "" });
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

  const handleViewHistory = (asset) => {
    setSelectedAsset(asset);
    fetchAssetHistory(asset.asset_id);
    setShowHistoryModal(true);
  };

  const handleOpenJobcard = (jobcardId) => {
    setShowHistoryModal(false);
    navigate(`/work-orders?search=${jobcardId}`);
  };
  
  const filteredItems = [...assets]
    .filter((asset) => {
      const query = searchTerm.trim().toLowerCase();
      if (!query) return true;

      const getColumnValue = (column) => {
        switch (column) {
          case "asset_id": return asset.asset_id;
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
      if (sortBy === "default") return 0;
      const direction = sortDirection === "asc" ? 1 : -1;
      if (sortBy === "asset_id") return (Number(a.asset_id || 0) - Number(b.asset_id || 0)) * direction;
      if (sortBy === "asset_name") return String(a.asset_name || "").localeCompare(String(b.asset_name || ""), "af", { sensitivity: "base" }) * direction;
      if (sortBy === "status") return String(getStatusLabel(a.asset_status)).localeCompare(String(getStatusLabel(b.asset_status)), "af", { sensitivity: "base" }) * direction;
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

  const terrainOptions = terrains.map(t => ({
    value: String(t.location_id),
    label: t.location_name
  }));

  const buildingOptions = buildings
    .filter(b => Number(b.location_id) === Number(newAsset.location_id))
    .map(b => ({
      value: String(b.building_id),
      label: b.building_name
    }));

  const roomOptions = rooms
    .filter(r => Number(r.building_id) === Number(newAsset.building_id))
    .map(r => ({
      value: String(r.room_id),
      label: r.room_name
    }));

  const filterColumnOptions = [
    { value: "all", label: "Alle kolomme" },
    { value: "asset_id", label: "ID" },
    { value: "asset_name", label: "Naam" },
    { value: "asset_brand", label: "Brand" },
    { value: "asset_serial", label: "Serienommer" },
    { value: "asset_isoutdoor", label: "Buite" },
    { value: "room", label: "Lokaal" },
    { value: "status", label: "Status" }
  ];

  const sortByOptions = [
    { value: "default", label: "Standaard" },
    { value: "asset_id", label: "ID" },
    { value: "asset_name", label: "Naam" },
    { value: "status", label: "Status" }
  ];

  // Waardes hier verander om presies te pas by die backend DB-verwagtinge
  const statusOptions = [
    { value: "Aktief", label: "Aktief" },
    { value: "Instandhouding", label: "Onderhoud" },
    { value: "Afgedank", label: "Afgedank" },
    { value: "Onaktief", label: "Onaktief" }
  ];

  if (loading) {
    return <div style={{ display: "flex" }}><div className="main"><div className="content">Laai...</div></div></div>;
  }

  return (
    <div>
      <Sidebar currentPath="/assets" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Bates Bestuur</h3>
    
          <div className="user-profile-box" style={{ textAlign: 'right', fontSize: '14px', lineHeight: '1.3' }}>
            {user ? (
              <>
                <div className="user-name" style={{ fontWeight: 'bold' }}>
                  {user.user_name} {user.user_surname}
                </div>
                <div className="user-role" style={{ fontSize: '12px', color: '#935e28', fontWeight: '600' }}>
                  {user.role_id === 3 ? "Administrateur" : user.role_id === 2 ? "Personeel" : "Student"}
                </div>
                <div className="user-email" style={{ fontSize: '11px', color: '#666' }}>
                  {user.user_email}
                </div>
              </>
            ) : (
              <div className="user-loading" style={{ color: '#999' }}>Laai profiel...</div>
            )}
          </div>
        </div>

        <div className="content">
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
            </div>
            <div className="controls-right">
              <Select 
                className="basic-single"
                classNamePrefix="select"
                value={sortByOptions.find(option => option.value === sortBy)}
                onChange={(selectedOption) => setSortBy(selectedOption.value)}
                options={sortByOptions}
                isSearchable={false}
                styles={{ container: (base) => ({ ...base, minWidth: '140px' }) }}
              />
              <div style={{ display: "flex", gap: "0.25rem" }}>
                <button type="button" className="btn-add" onClick={() => setSortDirection("asc")} style={{ minWidth: "40px", background: sortDirection === "asc" ? "#935e28" : undefined }} title="Stygend">▲</button>
                <button type="button" className="btn-add" onClick={() => setSortDirection("desc")} style={{ minWidth: "40px", background: sortDirection === "desc" ? "#935e28" : undefined }} title="Dalend">▼</button>
              </div>
              <button className="btn-add" onClick={handleNewAsset}>+ Nuwe Bate</button>
            </div>
          </div>

          <table className="standard-table">
            <thead>
              <tr>
                <th>ID Bate</th>
                <th>Naam</th>
                <th>Serienommer</th>
                <th>Buite</th>
                <th>Lokaal</th>
                <th>Status</th>
                <th>Aksies</th>
              </tr>
            </thead>
            <tbody>
              {filteredItems.map((item) => (
                <tr key={item.asset_id}>
                  <td>{item.asset_id}</td>
                  <td>{item.asset_name}</td>
                  <td>{item.asset_serial}</td>
                  <td>{item.asset_isoutdoor ? "Ja" : "Nee"}</td>
                  <td>{getRoomName(item)}</td>
                  <td>
                    <span className={`status ${getStatusClass(item.asset_status)}`}>
                      {getStatusLabel(item.asset_status)}
                    </span>
                  </td>
                  <td>
                    <button className="btn-view" onClick={() => handleViewHistory(item)}>
                      Besigtig Geskiedenis
                    </button>
                    <button className="btn-edit" onClick={() => handleEditAsset(item)}>Wysig</button>
                    <button className="btn-delete" onClick={() => handleDeleteAsset(item.asset_id)}>Verwyder</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal" style={{ display: "flex" }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>{isEditing ? "Wysig" : "Nuwe"} Bate {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
              <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            <div className="input-row">
              <div className="input-group">
                <label>Naam</label>
                <input
                  type="text"
                  value={newAsset.asset_name}
                  onChange={(e) => setNewAsset({ ...newAsset, asset_name: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Brand</label>
                <input
                  type="text"
                  value={newAsset.asset_brand}
                  onChange={(e) => setNewAsset({ ...newAsset, asset_brand: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Serienommer</label>
                <input
                  type="text"
                  value={newAsset.asset_serial}
                  onChange={handleSerialChange}
                  placeholder="bv. AK-MT000001"
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
            </div>

            <div className="input-row">
              {/* Terrein Dropdown */}
              <div className="input-group">
                <label>Terrein</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder="Kies 'n terrein..."
                  isSearchable={true}
                  options={terrainOptions}
                  value={terrainOptions.find(o => Number(o.value) === Number(newAsset.location_id)) || null}
                  onChange={(selected) => {
                    setNewAsset({
                      ...newAsset,
                      location_id: selected ? Number(selected.value) : "",
                      building_id: "",
                      room_id: ""
                    });
                  }}
                />
              </div>

              {/* Gebou Dropdown */}
              <div className="input-group">
                <label>Gebou</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder={!newAsset.location_id ? "Kies eers 'n terrein" : "Kies 'n gebou..."}
                  isSearchable={true}
                  isDisabled={!newAsset.location_id}
                  options={buildingOptions}
                  value={buildingOptions.find(o => Number(o.value) === Number(newAsset.building_id)) || null}
                  onChange={(selected) => {
                    setNewAsset({
                      ...newAsset,
                      building_id: selected ? Number(selected.value) : "",
                      room_id: ""
                    });
                  }}
                />
              </div>
            </div>

            <div className="input-row">
              {/* Lokaal Dropdown */}
              <div className="input-group" style={{ width: "50%" }}>
                <label>Lokaal *</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder={!newAsset.building_id ? "Kies eers 'n gebou" : "Kies lokaal *"}
                  isSearchable={true}
                  isDisabled={!newAsset.building_id}
                  options={roomOptions}
                  value={roomOptions.find(o => Number(o.value) === Number(newAsset.room_id)) || null}
                  onChange={(selected) => {
                    setNewAsset({
                      ...newAsset,
                      room_id: selected ? Number(selected.value) : ""
                    });
                  }}
                />
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
            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleSaveAsset}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}

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
    </div>
  );
}

export default AssetPage;