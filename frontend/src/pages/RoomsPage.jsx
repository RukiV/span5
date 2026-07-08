import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import Select from "react-select";
import Sidebar from '../components/Sidebar';
import { assetsAPI, buildingsAPI, roomsAPI, locationAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import "../styles/App.css";
import "../styles/Rooms.css";
import { useLogout } from "./Page.jsx";
import UserProfileHeader from '../components/UserProfileHeader';

function RoomsPage() {
  const { isAdmin } = useCurrentUser();
  const logout = useLogout();

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
  
  // Opdateer: Verander die standaard room_type na 'Ander' om by die backend te pas
  const [newRoom, setNewRoom] = useState({
    room_name: "",
    room_code: "",
    room_capacity: "",
    room_type: "Ander", 
    room_status: "Operasioneel",
    location_id: "",
    building_id: "",
  });

  useEffect(() => {
    const loadData = async () => {
      await Promise.all([fetchRooms(), fetchAssets(), fetchTerrains(), fetchBuildings()]);
    };
    loadData();
  }, []);

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
    if (!newRoom.room_name?.trim()) {
      alert("Voer asseblief 'n lokaalnaam in");
      return;
    }

    if (!newRoom.room_code?.trim()) {
      alert("Voer asseblief 'n lokaalkode in");
      return;
    }

    if (!newRoom.building_id) {
      alert("Voer asseblief 'n gebou in");
      return;
    }

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
      room_type: room.room_type || "Ander",
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

  const terrainOptions = terrains.map((t) => ({
    value: String(t.location_id),
    label: t.location_name
  }));

  const buildingOptions = buildings
    .filter((b) => b.location_id === Number(newRoom.location_id))
    .map((b) => ({
      value: String(b.building_id),
      label: b.building_name
    }));

  if (loading) {
    return (
      <div style={{ display: "flex" }}>
        <div className="main">
          <div className="content">Laai...</div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex' }}>
      <Sidebar currentPath="/rooms" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Lokale Bestuur</h3>
          <UserProfileHeader />
        </div>

        <div className="content">
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
                <tr key={room.room_id}>
                  <td>{room.room_name}</td>
                  <td>{room.room_code ?? '-'}</td>
                  <td>{translateRoomType(room.room_type || 'Ander')}</td>
                  <td>{translateRoomStatus(room.room_status || 'Operasioneel')}</td>
                  <td>{getBuildingName(room.building_id)}</td>
                  <td>{room.room_capacity ?? '-'}</td>
                  <td>
                    <button className="btn-view" onClick={() => handleViewAssets(room)}>
                      Besigtig Bates
                    </button>
                    <button className="btn-edit" onClick={() => handleEditRoom(room)}>
                      Wysig
                    </button>
                    <button className="btn-delete" onClick={() => handleDeleteRoom(room.room_id)}>
                      Verwyder
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal" style={{ display: 'flex' }}>
          <div className="modal-content">
            <div className="modal-header">
              <h3>{isEditing ? "Wysig" : "Nuwe"} lokaal {!isEditing && "(ID sal outomaties gegenereer word)"}</h3>
               <span className="close" onClick={handleCloseModal}>&times;</span>
            </div>
            
            <div className="input-row">
              <div className="input-group">
                <label>Naam</label>
                <input
                  type="text"
                  value={newRoom.room_name}
                  onChange={(e) => setNewRoom({ ...newRoom, room_name: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Lokaal Kode</label>
                <input
                  type="text"
                  placeholder="Bv. L10"
                  value={newRoom.room_code}
                  onChange={(e) => setNewRoom({ ...newRoom, room_code: e.target.value })}
                />
              </div>
            </div>

            <div className="input-row">
              <div className="input-group">
                <label>Kapasiteit</label>
                <input
                  type="number"
                  value={newRoom.room_capacity}
                  onChange={(e) => setNewRoom({ ...newRoom, room_capacity: e.target.value })}
                />
              </div>
              <div className="input-group">
                <label>Tipe</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  value={roomTypeOptions.find(o => o.value === newRoom.room_type)}
                  onChange={(selected) => setNewRoom({ ...newRoom, room_type: selected ? selected.value : "Ander" })}
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
              <div className="input-group">
                <label>Terrein</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder="Kies 'n terrein..."
                  isSearchable={true}
                  options={terrainOptions}
                  value={terrainOptions.find(o => Number(o.value) === Number(newRoom.location_id)) || null}
                  onChange={(selected) => {
                    setNewRoom({ 
                      ...newRoom, 
                      location_id: selected ? selected.value : "", 
                      building_id: "" 
                    });
                  }}
                />
              </div>
              
              <div className="input-group">
                <label>Gebou</label>
                <Select
                  className="basic-single"
                  classNamePrefix="select"
                  placeholder={!newRoom.location_id ? "Kies eers 'n terrein" : "Kies 'n gebou..."}
                  isSearchable={true}
                  isDisabled={!newRoom.location_id}
                  options={buildingOptions}
                  value={buildingOptions.find(o => Number(o.value) === Number(newRoom.building_id)) || null}
                  onChange={(selected) => {
                    setNewRoom({ 
                      ...newRoom, 
                      building_id: selected ? selected.value : "" 
                    });
                  }}
                />
              </div>
            </div>

            <div className="modal-footer">
              <button className="btn-cancel" onClick={handleCloseModal}>Kanselleer</button>
              <button className="btn-add" onClick={handleSaveRoom}>{isEditing ? "Opdateer" : "Stoor"}</button>
            </div>
          </div>
        </div>
      )}

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