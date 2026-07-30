import React, { useState, useEffect, useMemo } from 'react';
import { authAPI } from "../services/api";
import { apiClient, assetsAPI, locationAPI, buildingsAPI, roomsAPI } from "../services/api";
import Select, { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import '../styles/Predictions.css';
import { buildFlatLocationOptions } from './locationSearchUtils';

const formatDate = (value) => {
  if (!value) return '-';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '-';
  return d.toLocaleDateString('af-ZA', { year: 'numeric', month: 'short', day: 'numeric' });
};

const getMaintenanceBadge = (overdue) => {
  if (overdue) return { class: 'badge-danger', label: 'Agterstallig' };
  return { class: 'badge-ok', label: 'Op skedule' };
};

const getLifespanBadge = (pct) => {
  if (pct == null) return { class: 'badge-muted', label: 'Onbekend' };
  if (pct >= 100) return { class: 'badge-danger', label: 'Oorskry' };
  if (pct >= 80) return { class: 'badge-warning', label: `${pct}%` };
  return { class: 'badge-ok', label: `${pct}%` };
};

const getReplacementBadge = (suggested) => {
  if (suggested) return { class: 'badge-danger', label: 'Ja' };
  return { class: 'badge-ok', label: 'Nee' };
};

function PredictionsPage() {
  const { user } = useCurrentUser();
  const [predictions, setPredictions] = useState([]);
  const [assets, setAssets] = useState([]);
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [expandedId, setExpandedId] = useState(null);
  const [terrainFilter, setTerrainFilter] = useState("");
  const [buildingFilter, setBuildingFilter] = useState("");
  const [roomFilter, setRoomFilter] = useState("");

  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, rooms, null), [terrains, buildings, rooms]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await authAPI.me();
        const [predRes, assetsRes, terrainsRes, buildingsRes, roomsRes] = await Promise.all([
          apiClient.get('/predictions'),
          assetsAPI.getAll(),
          locationAPI.getAll(),
          buildingsAPI.getAll(),
          roomsAPI.getAll(),
        ]);
        if (!mounted) return;
        setPredictions(predRes.data || []);
        setAssets(assetsRes.data || []);
        setTerrains(terrainsRes.data || []);
        setBuildings(buildingsRes.data || []);
        setRooms(roomsRes.data || []);
      } catch (err) {
        if (!mounted) return;
        setError('Kon voorspellingsdata nie laai nie.');
        try { sessionStorage.clear(); localStorage.clear(); } catch (_) {}
        window.location.replace(window.location.origin + '/login');
      } finally {
        if (mounted) setLoading(false);
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

  const getPredictionLocationId = (pred) => {
    const asset = assets.find(a => Number(a.asset_id) === Number(pred.asset_id));
    if (!asset || !asset.room_id) return null;
    const room = rooms.find(r => r.room_id === asset.room_id);
    if (!room) return null;
    const building = buildings.find(b => b.building_id === room.building_id);
    return building ? building.location_id : null;
  };

  const getPredictionBuildingId = (pred) => {
    const asset = assets.find(a => Number(a.asset_id) === Number(pred.asset_id));
    if (!asset || !asset.room_id) return null;
    const room = rooms.find(r => r.room_id === asset.room_id);
    return room ? room.building_id : null;
  };

  const getPredictionRoomId = (pred) => {
    const asset = assets.find(a => Number(a.asset_id) === Number(pred.asset_id));
    return asset ? asset.room_id : null;
  };

  const filteredPredictions = predictions.filter(p => {
    if (terrainFilter) {
      const locId = getPredictionLocationId(p);
      if (String(locId) !== terrainFilter) return false;
    }
    if (buildingFilter) {
      const bldId = getPredictionBuildingId(p);
      if (String(bldId) !== buildingFilter) return false;
    }
    if (roomFilter) {
      const rmId = getPredictionRoomId(p);
      if (String(rmId) !== roomFilter) return false;
    }
    return true;
  });

  const needsAttention = filteredPredictions.filter(
    (p) => p.maintenance_overdue || p.lifespan_exceeded || p.replacement_suggested
  ).length;



  if (loading) {
    return (
      <div className="main"><div className="content">Laai voorspellings...</div></div>
    );
  }

  return (
    <div className="main">
      <div className="content">
          {error ? <div className="pred-empty-state">{error}</div> : null}

          <div className="controls" style={{ marginBottom: '0.75rem' }}>
            <div className="controls-left">
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
                        if (!selectedOption) return;
                        const f = selectedOption._fields;
                        setTerrainFilter(f.location_id); setBuildingFilter(f.building_id); setRoomFilter(f.room_id);
                      }}
                    />
                  </div>
                );
              })()}
            </div>
            <div className="controls-right"></div>
          </div>
          <div className="pred-kpi-grid">
            <div className="pred-kpi-card">
              <h4>Totale Bates</h4>
              <p className="pred-kpi-value">{filteredPredictions.length}</p>
            </div>
            <div className="pred-kpi-card">
              <h4>Benodig Aandag</h4>
              <p className="pred-kpi-value pred-kpi-warning">{needsAttention}</p>
              <span className="pred-kpi-caption">Onderhoud / lewensduur / vervanging</span>
            </div>
            <div className="pred-kpi-card">
              <h4>Vervanging Voorgestel</h4>
              <p className="pred-kpi-value pred-kpi-danger">{filteredPredictions.filter(p => p.replacement_suggested).length}</p>
            </div>
            <div className="pred-kpi-card">
              <h4>Onderhoud Agterstallig</h4>
              <p className="pred-kpi-value pred-kpi-danger">{filteredPredictions.filter(p => p.maintenance_overdue).length}</p>
            </div>
          </div>

          <div className="predictions-table-wrapper">
            <table className="standard-table">
              <thead>
                <tr>
                  <th>Bate</th>
                  <th>Serienommer</th>
                  <th>Tipe</th>
                  <th>Onderhoud</th>
                  <th>Lewensduur</th>
                  <th>Vervang</th>
                  <th>Foute (12m)</th>
                </tr>
              </thead>
              <tbody>
                {filteredPredictions.map((pred) => {
                  const maint = getMaintenanceBadge(pred.maintenance_overdue);
                  const life = getLifespanBadge(pred.lifespan_pct_used);
                  const repl = getReplacementBadge(pred.replacement_suggested);
                  const isExpanded = expandedId === pred.asset_id;

                  return (
                    <React.Fragment key={pred.asset_id}>
                      <tr
                        className={pred.replacement_suggested ? 'row-danger' : pred.maintenance_overdue ? 'row-warning' : ''}
                        onClick={() => setExpandedId(isExpanded ? null : pred.asset_id)}
                        style={{ cursor: 'pointer' }}
                      >
                        <td>{pred.asset_name}</td>
                        <td>{pred.asset_serial}</td>
                        <td>{pred.assettype_name || '-'}</td>
                        <td><span className={`pred-badge ${maint.class}`}>{maint.label}</span></td>
                        <td><span className={`pred-badge ${life.class}`}>{life.label}</span></td>
                        <td><span className={`pred-badge ${repl.class}`}>{repl.label}</span></td>
                        <td>{pred.fault_count_12months}</td>
                      </tr>
                      {isExpanded && (
                        <tr className="pred-detail-row">
                          <td colSpan="7">
                            <div className="pred-detail-grid">
                              <div className="pred-detail-section">
                                <h5>Onderhoud</h5>
                                {pred.last_maintenance_date ? (
                                  <>
                                    <p><strong>Laaste:</strong> {formatDate(pred.last_maintenance_date)}</p>
                                    <p><strong>Volgende:</strong> {formatDate(pred.next_maintenance_date)}</p>
                                    <p><strong>Interval:</strong> {pred.maintenance_interval_months} maande</p>
                                  </>
                                ) : (
                                  <p>Geen onderhoudsgeskiedenis</p>
                                )}
                              </div>
                              <div className="pred-detail-section">
                                <h5>Lewensduur</h5>
                                {pred.creation_date ? (
                                  <>
                                    <p><strong>Geskep:</strong> {formatDate(pred.creation_date)}</p>
                                    <p><strong>Gem. lewensduur:</strong> {pred.avg_lifespan_months} maande</p>
                                    <p><strong>Einddatum:</strong> {formatDate(pred.lifespan_end_date)}</p>
                                    <p><strong>Verbruik:</strong> {pred.lifespan_pct_used != null ? `${pred.lifespan_pct_used}%` : 'N/A'}</p>
                                  </>
                                ) : (
                                  <p>Geen skeppingsdatum</p>
                                )}
                              </div>
                              <div className="pred-detail-section">
                                <h5>Vervangingsvoorstel</h5>
                                {pred.replacement_suggested ? (
                                  <p className="pred-reason">{pred.replacement_reason}</p>
                                ) : (
                                  <p>Geen vervanging benodig nie</p>
                                )}
                              </div>
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>
  );
}

export default PredictionsPage;
