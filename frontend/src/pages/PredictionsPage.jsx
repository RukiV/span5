import React, { useState, useEffect } from 'react';
import Select from "react-select";
import { authAPI, apiClient, locationAPI, buildingsAPI, roomsAPI } from "../services/api";
import { useCurrentUser } from "../hooks/useCurrentUser";
import '../styles/App.css';
import '../styles/Predictions.css';
import { useLogout } from './Page.jsx';
import Sidebar from '../components/Sidebar';

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
  const { isAdmin, user } = useCurrentUser();
  const logout = useLogout();
  const [predictions, setPredictions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [expandedId, setExpandedId] = useState(null);
  const [terrains, setTerrains] = useState([]);
  const [buildings, setBuildings] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [assets, setAssets] = useState([]);
  const [terrainFilter, setTerrainFilter] = useState('');
  const [buildingFilter, setBuildingFilter] = useState('');
  const [roomFilter, setRoomFilter] = useState('');
  const [drillLevel, setDrillLevel] = useState(0);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await authAPI.me();
        const response = await apiClient.get('/predictions');
        if (!mounted) return;
        setPredictions(response.data || []);
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
    let mounted = true;
    (async () => {
      try {
        const [tRes, bRes, rRes, aRes] = await Promise.all([
          locationAPI.getAll(),
          buildingsAPI.getAll(),
          roomsAPI.getAll(),
          apiClient.get('/assets'),
        ]);
        if (!mounted) return;
        setTerrains(tRes.data || []);
        setBuildings(bRes.data || []);
        setRooms(rRes.data || []);
        setAssets(aRes.data || []);
      } catch (err) {
        console.error('Kon terrains/geboue/lokale/bates nie laai nie:', err);
      }
    })();
    return () => { mounted = false; };
  }, []);

  useEffect(() => {
    if (user?.role_id === 2 && user?.location_id && terrainFilter === '') {
      setTerrainFilter(String(user.location_id));
      setDrillLevel(1);
    }
  }, [user]);

  const drillOptions = React.useMemo(() => {
    if (drillLevel === 0) return terrains.map(t => ({ value: `loc:${t.location_id}`, label: t.location_name }));
    if (drillLevel === 1 && terrainFilter) return [
      { value: '__back', label: '\u2190 Terrein keuse' },
      ...buildings.filter(b => Number(b.location_id) === Number(terrainFilter)).map(b => ({ value: `bld:${b.building_id}`, label: b.building_name }))
    ];
    if (drillLevel === 2 && buildingFilter) return [
      { value: '__back', label: '\u2190 Gebou keuse' },
      ...rooms.filter(r => Number(r.building_id) === Number(buildingFilter)).map(r => ({ value: `rm:${r.room_id}`, label: r.room_name }))
    ];
    return [];
  }, [drillLevel, terrainFilter, buildingFilter, terrains, buildings, rooms]);

  const handleDrillChange = (selected) => {
    if (!selected) { setTerrainFilter(''); setBuildingFilter(''); setRoomFilter(''); setDrillLevel(0); return; }
    if (selected.value === '__back') { setDrillLevel(d => d - 1); return; }
    const [type, id] = selected.value.split(':');
    if (type === 'loc') { setTerrainFilter(id); setBuildingFilter(''); setRoomFilter(''); setDrillLevel(1); }
    else if (type === 'bld') { setBuildingFilter(id); setRoomFilter(''); setDrillLevel(2); }
    else if (type === 'rm') { setRoomFilter(id); }
  };

  if (loading) {
    return (
      <div style={{ display: 'flex' }}>
        <div className="main"><div className="content">Laai voorspellings...</div></div>
      </div>
    );
  }

  const filteredPredictions = predictions.filter(p => {
    if (!terrainFilter && !buildingFilter && !roomFilter) return true;
    const asset = assets.find(a => Number(a.asset_id) === Number(p.asset_id));
    if (!asset) return false;
    if (roomFilter && Number(asset.room_id) !== Number(roomFilter)) return false;
    if (buildingFilter || terrainFilter) {
      const room = rooms.find(r => Number(r.room_id) === Number(asset.room_id));
      if (!room) return false;
      if (buildingFilter && Number(room.building_id) !== Number(buildingFilter)) return false;
      if (terrainFilter) {
        const building = buildings.find(b => Number(b.building_id) === Number(room.building_id));
        if (!building || Number(building.location_id) !== Number(terrainFilter)) return false;
      }
    }
    return true;
  });

  const currentDrillValue = drillLevel === 0 ? null
    : drillLevel === 1 && terrainFilter ? drillOptions.find(o => o.value === `loc:${terrainFilter}`) || null
    : drillLevel === 2 && buildingFilter ? drillOptions.find(o => o.value === `bld:${buildingFilter}`) || null
    : null;

  const needsAttention = filteredPredictions.filter(
    (p) => p.maintenance_overdue || p.lifespan_exceeded || p.replacement_suggested
  ).length;

  return (
    <div>
      <Sidebar currentPath="/predictions" isAdmin={isAdmin} onLogout={logout} />

      <div className="main">
        <div className="navbar">
          <h3>Bate Voorspellings</h3>
          <div className="user-profile-box" style={{ textAlign: 'right', fontSize: '14px', lineHeight: '1.3' }}>
            {user ? (
              <>
                <div className="user-name" style={{ fontWeight: 'bold' }}>
                  {user.user_name} {user.user_surname}
                </div>
                <div className="user-role" style={{ fontSize: '12px', color: '#935e28', fontWeight: '600' }}>
                  {user.role_id === 3 ? 'Administrateur' : user.role_id === 2 ? 'Personeel' : 'Student'}
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
          {error ? <div className="pred-empty-state">{error}</div> : null}

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

          <div className="controls">
            <div className="controls-left">
              <Select
                className="basic-single"
                classNamePrefix="select"
                placeholder={drillLevel === 0 ? "Kies 'n terrein..." : drillLevel === 1 ? "Kies 'n gebou..." : "Kies 'n lokaal..."}
                isSearchable={true}
                isClearable={true}
                options={drillOptions}
                value={currentDrillValue}
                onChange={handleDrillChange}
                styles={{ container: (base) => ({ ...base, minWidth: '260px', flex: 1 }) }}
              />
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
    </div>
  );
}

export default PredictionsPage;
