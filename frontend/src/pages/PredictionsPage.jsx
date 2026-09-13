import React, { useState, useEffect, useMemo, useRef } from 'react';
import { Link } from 'react-router-dom';
import { Line, Bar, Doughnut } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
} from 'chart.js';
import { authAPI } from "../services/api";
import { apiClient, assetsAPI, locationAPI, buildingsAPI, roomsAPI } from "../services/api";
import { workOrdersAPI, ticketsAPI } from "../services/api";
import Select, { components } from "react-select";
import { IoReturnUpBack } from "react-icons/io5";
import { useCurrentUser } from "../hooks/useCurrentUser";
import useColumnSort from "../hooks/useColumnSort";
import useColumnVisibility from "../hooks/useColumnVisibility";
import ColumnPicker from "../components/ColumnPicker/ColumnPicker";
import SortPicker from "../components/ColumnPicker/SortPicker";
import useColumnWidths from "../hooks/useColumnWidths";
import usePagination from "../hooks/usePagination";
import Pagination from "../components/Pagination/Pagination";
import ResizableTh from "../components/ResizableTh";
import { cachedFetch } from '../utils/cache';
import '../styles/App.css';
import '../styles/Predictions.css';
import { buildFlatLocationOptions } from './locationSearchUtils';
import useCascadeMenu from "../hooks/useCascadeMenu";
import { CascadeIndicatorsContainer, NoCascadeClearIndicator } from "../components/controlHelpers";
import { analyticsAPI } from '../services/analyticsAPI';
import { useToast } from '../components/Toast/useToast';
import { useConfirmDialog } from '../components/Modal/useConfirmDialog';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, BarElement, Title, Tooltip, Legend, ArcElement);

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

const getSurvivalRiskBadge = (highRisk, available) => {
  if (!available) return { class: 'badge-muted', label: '—' };
  if (highRisk) return { class: 'badge-danger', label: 'HOOG' };
  return { class: 'badge-ok', label: 'LAAG' };
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

  // ── Grafieke (geskuif vanaf Paneelbord) ──
  const [summary, setSummary] = useState(null);
  const [allJobs, setAllJobs] = useState([]);
  const [allFaults, setAllFaults] = useState([]);
  const [insightData, setInsightData] = useState(null);
  const [executing, setExecuting] = useState({});
  const { rights } = useCurrentUser();
  const { showToast } = useToast();
  const { confirm, dialog: confirmDialog } = useConfirmDialog();
  const can = (r) => (rights || []).includes(r);

  const allLocationOptions = useMemo(() => buildFlatLocationOptions(terrains, buildings, rooms, null), [terrains, buildings, rooms]);
  const filterCascade = useCascadeMenu();

const getAssetName = (p) => p.asset_name || '-';
const getAssetSerial = (p) => p.asset_serial || '-';
const getAssetTypeName = (p) => p.assettype_name || '-';

const PREDICTION_COLUMNS = [
  { key: 'asset_name', label: 'Bate', render: (p) => getAssetName(p), sortKey: 'asset_name', defaultVisible: true },
  { key: 'serial', label: 'Serienommer', render: (p) => getAssetSerial(p), sortKey: 'serial', defaultVisible: true },
  { key: 'type', label: 'Tipe', render: (p) => getAssetTypeName(p), sortKey: 'type', defaultVisible: true },
  { key: 'maintenance', label: 'Onderhoud', render: (p) => { const b = getMaintenanceBadge(p.maintenance_overdue); return <span className={`pred-badge ${b.class}`}>{b.label}</span>; }, sortKey: 'maintenance', defaultVisible: true },
  { key: 'lifespan', label: 'Lewensduur', render: (p) => { const b = getLifespanBadge(p.lifespan_pct_used); return <span className={`pred-badge ${b.class}`}>{b.label}</span>; }, sortKey: 'lifespan', defaultVisible: true },
  { key: 'replacement', label: 'Vervang', render: (p) => { const b = getReplacementBadge(p.replacement_suggested); return <span className={`pred-badge ${b.class}`}>{b.label}</span>; }, sortKey: 'replacement', defaultVisible: true },
  { key: 'ml_risk', label: 'ML Risiko', render: (p) => { const b = getSurvivalRiskBadge(p.survival_high_risk, p.survival_model_available); return <span className={`pred-badge ${b.class}`}>{b.label}</span>; }, sortKey: null, defaultVisible: false },
  { key: 'ml_prob', label: 'Faalkans 12md', render: (p) => (p.survival_model_available && p.survival_failure_prob_12mo != null ? `${Math.round(p.survival_failure_prob_12mo * 100)}%` : '—'), sortKey: null, defaultVisible: false },
  { key: 'details', label: 'Besonderhede', render: (p) => null, sortKey: null, defaultVisible: true },
];
const { sorts, addSort, removeSort, toggleDirection, moveSort, clearSorts, applySort } = useColumnSort({
  columns: PREDICTION_COLUMNS.filter((c) => c.sortKey),
  storageKey: 'predictions-page',
});
const colVis = useColumnVisibility('predictions-page', PREDICTION_COLUMNS);
const colWidths = useColumnWidths('predictions-page', PREDICTION_COLUMNS);
const colPickerRef = useRef(null);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await authAPI.me();
        // Cache predictions for 10 minutes to avoid repeated backend scans
        const predRes = await cachedFetch('predictions-all', () => apiClient.get('/predictions'));
        const [assetsRes, terrainsRes, buildingsRes, roomsRes, summaryRes, jobsRes, faultsRes, insightsRes] = await Promise.all([
          assetsAPI.getAll(),
          locationAPI.getAll(),
          buildingsAPI.getAll(),
          roomsAPI.getAll(),
          Promise.resolve(apiClient.get('/analytics/dashboard-summary?include_ai_charts=true')).catch((e) => {
            console.warn('dashboard-summary failed, using fallback', e?.response?.status);
            return null;
          }),
          Promise.resolve(workOrdersAPI.getAll()).catch(() => ({ data: [] })),
          Promise.resolve(ticketsAPI.getAll()).catch(() => ({ data: [] })),
          Promise.resolve(analyticsAPI.getInsights('predictions')).catch(() => ({ data: null })),
        ]);
        if (!mounted) return;
        setPredictions(predRes.data || []);
        setAssets(assetsRes.data || []);
        setTerrains(terrainsRes.data || []);
        setBuildings(buildingsRes.data || []);
        setRooms(roomsRes.data || []);
        if (summaryRes?.data) {
          setSummary(summaryRes.data);
        } else {
          setSummary({
            kpis: { overdue_maintenance: 0, unassigned_high_faults: 0, overdue_jobs: 0, critical_stock: 0, replacement_suggested: 0, high_risk: 0 },
            risk_distribution: { veilig: 0, monitor: 0, vervang: 0 },
            faults_per_building: [],
            trend: { labels: ['Geen data'], faults_per_week: [0], jobs_completed_per_week: [0] },
            top_risk_assets: [],
            critical_stock_list: [],
            scope: 'all',
          });
        }
        setAllJobs(Array.isArray(jobsRes?.data) ? jobsRes.data : []);
        setAllFaults(Array.isArray(faultsRes?.data) ? faultsRes.data : []);
        setInsightData(insightsRes?.data || null);
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

  const filteredPredictions = applySort(
  predictions.filter(p => {
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
  }), (p, key) => {
    switch (key) {
      case 'asset_name': return String(p.asset_name || '');
      case 'serial': return String(p.asset_serial || '');
      case 'type': return String(p.assettype_name || '');
      case 'maintenance': return p.maintenance_overdue ? 1 : 0;
      case 'lifespan': return Number(p.lifespan_pct_used || 0);
      case 'replacement': return p.replacement_suggested ? 1 : 0;
      default: return '';
    }
  });
  const { currentPage, totalPages, paginatedData: paginatedPredictions, goToPage } = usePagination(filteredPredictions, 100);
  useEffect(() => { goToPage(1); }, [terrainFilter, buildingFilter, roomFilter, sorts, goToPage]);

  const needsAttention = filteredPredictions.filter(
    (p) => p.maintenance_overdue || p.lifespan_exceeded || p.replacement_suggested
  ).length;

  const mlModelAvailable = filteredPredictions.some((p) => p.survival_model_available);
  const mlRiskCount = mlModelAvailable ? filteredPredictions.filter((p) => p.survival_high_risk).length : '—';

  // ── Grafieke data-voorbereiding (van Paneelbord) ──
  const summaryData = summary || {};
  const risk = summaryData.risk_distribution || { veilig: 0, monitor: 0, vervang: 0 };
  const faultsPerBuilding = summaryData.faults_per_building || [];
  const trend = summaryData.trend || { labels: [], faults_per_week: [], jobs_completed_per_week: [] };
  const topRisk = summaryData.top_risk_assets || [];
  const criticalStockList = summaryData.critical_stock_list || [];

  const faultsPerBuildingData = {
    labels: faultsPerBuilding.length ? faultsPerBuilding.map((x) => x.building) : ['Geen foute 30d'],
    datasets: [
      {
        label: 'Foute 30 dae',
        data: faultsPerBuilding.length ? faultsPerBuilding.map((x) => x.count) : [0],
        backgroundColor: '#c97c3c',
        borderColor: '#935e28',
        borderWidth: 1,
      },
    ],
  };

  const riskData = {
    labels: ['Veilig', 'Monitor', 'Vervang'],
    datasets: [
      {
        label: 'Bates',
        data: [risk.veilig || 0, risk.monitor || 0, risk.vervang || 0],
        backgroundColor: ['#10b981', '#f59e0b', '#ef4444'],
        borderWidth: 0,
      },
    ],
  };

  const trendData = {
    labels: trend.labels || [],
    datasets: [
      {
        label: 'Foute geskep',
        data: trend.faults_per_week || [],
        borderColor: '#b91c1c',
        backgroundColor: 'rgba(185,28,28,0.08)',
        fill: false,
        tension: 0.3,
      },
      {
        label: 'Werksopdragte voltooi',
        data: trend.jobs_completed_per_week || [],
        borderColor: '#10b981',
        backgroundColor: 'rgba(16,185,129,0.12)',
        fill: true,
        tension: 0.3,
      },
    ],
  };

  const stockData = {
    labels: criticalStockList.length ? criticalStockList.map((s) => s.stock_name) : ['Geen kritieke voorraad'],
    datasets: [
      {
        label: 'Hoeveelheid',
        data: criticalStockList.length ? criticalStockList.map((s) => s.amount) : [0],
        backgroundColor: criticalStockList.length ? criticalStockList.map((s) => (s.amount < s.minimum ? '#ef4444' : '#d4a357')) : ['#94a3b8'],
        borderWidth: 0,
      },
      {
        label: 'Minimum',
        data: criticalStockList.length ? criticalStockList.map((s) => s.minimum) : [0],
        backgroundColor: 'rgba(148,163,184,0.35)',
        borderColor: '#64748b',
        borderWidth: 1,
        type: 'bar',
      },
    ],
  };

  const hasData = (arr) => arr && arr.some((v) => v > 0);

  const aiCharts = summaryData.ai_charts || {};
  const aiOrder = [
    'criticality_matrix',
    'sla_compliance',
    'failure_pareto',
    'health_status',
    'ticket_volume_backlog',
    'mttr_mtbf',
    'technician_load',
    'lifecycle_age',
    'strategy_mix',
  ];

  // Helpers vir direkte aksies gebaseer op lewendige data
  const firstOverdueJob = allJobs.find((j) => {
    const s = String(j.job_status || '').toLowerCase();
    if (['voltooid','gekanselleer','completed','cancelled'].includes(s)) return false;
    if (!j.job_scheduled_end_datetime) return false;
    return new Date(j.job_scheduled_end_datetime) < new Date();
  }) || null;
  const highFaults = allFaults.filter((f) => {
    const pri = String(f.fault_priority || '').toLowerCase();
    const stat = String(f.fault_status || '').toLowerCase();
    return (pri === 'hoog' || pri === 'high' || pri === 'dringend') && ['oop','open','wag','wait','bevestig'].includes(stat);
  });
  const firstHighFault = highFaults[0] || null;
  const firstCriticalStock = criticalStockList[0] || null;
  const firstTopRisk = topRisk[0] || null;
  const unassignedJob = allJobs.find((j) => !j.assigned_to && String(j.job_status||'').toLowerCase() !== 'voltooid') || null;

  const aiLinkMap = {
    criticality_matrix: '/predictions',
    sla_compliance: '/fault-tickets',
    failure_pareto: '/assets',
    health_status: '/assets',
    ticket_volume_backlog: '/fault-tickets',
    mttr_mtbf: '/work-orders',
    technician_load: '/work-orders',
    lifecycle_age: '/predictions',
    strategy_mix: '/work-orders',
  };

  const handleExecute = useMemo(() => async (suggestion, key) => {
    const needsStock = suggestion.type === 'reorder_stock';
    const requiredRight = needsStock ? 'stock.manage' : 'jobs.manage';
    if (!can(requiredRight)) {
      showToast({ type: 'error', title: 'Geen reg', message: 'Geen reg — vra Admin' });
      return;
    }
    const ok = await confirm({
      title: 'Bevestig aksie',
      message: `${suggestion.label}${suggestion.description ? ' — ' + suggestion.description : ''}`,
      confirmLabel: 'Uitvoer',
      cancelLabel: 'Kanselleer',
      variant: 'info',
    });
    if (!ok) return;
    setExecuting((prev) => ({ ...prev, [key]: true }));
    try {
      const res = await analyticsAPI.executeSuggestion(suggestion);
      showToast({ type: 'success', title: res.data?.message || 'Aksie uitgevoer' });
    } catch (err) {
      const msg = err?.response?.data?.detail || err?.message || 'Kon nie aksie uitvoer nie';
      showToast({ type: 'error', title: 'Fout', message: String(msg) });
    } finally {
      setExecuting((prev) => ({ ...prev, [key]: false }));
    }
  }, [can, confirm, showToast]);

  if (loading) {
    return (
      <div className="main"><div className="content">Laai voorspellings...</div></div>
    );
  }

  return (
    <div className="main">
      <div className="content">
          {error ? <div className="pred-empty-state">{error}</div> : null}

          <div className="controls controls--sticky">
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
                  <div className="breadcrumb-list">
                    {breadcrumbData.map((item, i) => {
                      const isLast = i === breadcrumbData.length - 1;
                      const showArrow = isLast ? cascadeCount < 3 : true;
                      return (
                        <React.Fragment key={i}>
                          <button type="button" className="breadcrumb-btn" data-current={isLast ? "true" : "false"} onClick={() => clearFromLevel(item.level + 1)}>{item.name}</button>
                          {showArrow && <span className="breadcrumb-arrow">›</span>}
                        </React.Fragment>
                      );
                    })}
                  </div>
                );
                const CascadeControl = ({ children, ...props }) => (
                  <components.Control {...props}>
                    {children}
                    {cascadeCount > 0 && (
                      <span className="cascade-back-indicator" onMouseDown={(e) => { e.stopPropagation(); e.preventDefault(); clearFromLevel(cascadeCount - 1); }} title="Vorige vlak">
                        <IoReturnUpBack size={18} />
                      </span>
                    )}
                  </components.Control>
                );
                return (
                  <div className="control-cascade-stack" ref={filterCascade.containerRef}>
                    <div className="control-cascade-breadcrumb">
                      {renderBreadcrumb()}
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
                      components={{ Control: CascadeControl, IndicatorsContainer: CascadeIndicatorsContainer, ClearIndicator: NoCascadeClearIndicator }}
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
            <SortPicker
                columns={PREDICTION_COLUMNS.filter((c) => c.sortKey)}
                sorts={sorts}
                onAdd={addSort}
                onRemove={removeSort}
                onToggleDirection={toggleDirection}
                onMove={moveSort}
                onClear={clearSorts}
              />
              <ColumnPicker
                ref={colPickerRef}
                columns={PREDICTION_COLUMNS}
                visibleColumns={colVis.visibleColumns}
                toggleColumn={colVis.toggleColumn}
                resetVisibility={colVis.resetVisibility}
                onResetWidths={colWidths.resetWidths}
              />
            </div>
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
            <div className="pred-kpi-card">
              <h4>ML Hoë Risiko</h4>
              <p className={`pred-kpi-value ${mlRiskCount > 0 ? 'pred-kpi-danger' : ''}`}>{mlRiskCount}</p>
              <span className="pred-kpi-caption">{mlModelAvailable ? 'ML-faalkans ≥50% binne 12 maande' : 'Survival-model nie beskikbaar nie'}</span>
            </div>
          </div>

          {insightData && (insightData.summary || (insightData.insights && insightData.insights.length > 0)) && (
            <div className="pred-insights">
              <div className="pred-insights-header">ML-Analise</div>
              {insightData.summary && <div className="pred-insights-summary">{insightData.summary}</div>}
              {insightData.insights && insightData.insights.length > 0 && (
                <ul className="pred-insights-list">
                  {insightData.insights.map((ins, i) => <li key={i}>{ins}</li>)}
                </ul>
              )}
            </div>
          )}

          <div className="predictions-table-wrapper">
            <table className="standard-table">
              <thead>
                <tr>
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
                </tr>
              </thead>
              <tbody>
                {paginatedPredictions.map((pred) => {
                  const isExpanded = expandedId === pred.asset_id;

                  return (
                    <React.Fragment key={pred.asset_id}>
                      <tr
                        className={pred.replacement_suggested ? 'row-danger' : pred.maintenance_overdue ? 'row-warning' : ''}
                        onClick={() => setExpandedId(isExpanded ? null : pred.asset_id)}
                        style={{ cursor: 'pointer' }}
                      >
                        {colVis.visibleColumns.map((col) => (
                          <td key={col.key}>{col.render(pred)}</td>
                        ))}
                      </tr>
                      {isExpanded && (
                        <tr className="pred-detail-row">
                          <td colSpan={colVis.visibleColumns.length}>
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
                                <h5>ML-Voorspelling</h5>
                                {pred.survival_model_available ? (
                                  <>
                                    <p><strong>Faalkans 12 md:</strong> {pred.survival_failure_prob_12mo != null ? `${Math.round(pred.survival_failure_prob_12mo * 100)}%` : 'N/A'}</p>
                                    <p><strong>Risiko:</strong> {pred.survival_high_risk ? 'Hoog' : 'Laag'}</p>
                                    <p><strong>Mediaan:</strong> {pred.survival_median_days != null ? `${pred.survival_median_days} dae` : 'N/A'}</p>
                                    <p><strong>Model:</strong> {pred.survival_events_count != null ? `${pred.survival_events_count} gebeure, getraind ` : 'Getraind '}{formatDate(pred.survival_trained_at)}</p>
                                  </>
                                ) : (
                                  <p className="pred-muted">Survival-model nie beskikbaar (benodig ≥50 bates / ≥80 gebeure).</p>
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
      <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} totalItems={filteredPredictions.length} pageSize={100} />
          </div>

          {/* ── Grafieke (geskuif vanaf Paneelbord) ── */}
          <div className="charts-container" style={{ marginTop: '25px' }}>
            <div className="data-panel">
              <div className="panel-header">
                <h3>Bate Risiko-verdeling</h3>
                <Link to="/predictions" className="view-all">Bekyk besonderhede →</Link>
              </div>
              <div className="chart-container" style={{ height: '260px' }}>
                <Bar
                  data={riskData}
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    indexAxis: 'y',
                    plugins: { legend: { display: false } },
                    scales: { x: { beginAtZero: true, ticks: { precision: 0 } } },
                  }}
                />
              </div>
              <div style={{ display: 'flex', gap: '12px', justifyContent: 'center', marginTop: '8px', fontSize: '12px', color: '#6b7280' }}>
                <span><span style={{ display: 'inline-block', width: '10px', height: '10px', background: '#10b981', borderRadius: '2px', marginRight: '4px' }}></span>Veilig &lt;80%</span>
                <span><span style={{ display: 'inline-block', width: '10px', height: '10px', background: '#f59e0b', borderRadius: '2px', marginRight: '4px' }}></span>Monitor 80-99%</span>
                <span><span style={{ display: 'inline-block', width: '10px', height: '10px', background: '#ef4444', borderRadius: '2px', marginRight: '4px' }}></span>Vervang ≥100%/ML</span>
              </div>
            </div>
            <div className="data-panel">
              <div className="panel-header">
                <h3>Kritieke Voorraad — Hoeveelheid vs Minimum</h3>
                <Link to="/stock" className="view-all">Bestuur voorraad →</Link>
              </div>
              <div className="chart-container" style={{ height: '260px' }}>
                <Bar
                  data={stockData}
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { position: 'bottom' } },
                    scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                  }}
                />
              </div>
              {criticalStockList.length === 0 && (
                <div style={{ textAlign: 'center', color: '#10b981', fontSize: '13px', marginTop: '6px' }}>Geen kritieke items — voorraad OK.</div>
              )}
              {firstCriticalStock && (
                <div style={{ textAlign: 'center', marginTop: '10px' }}>
                  <button
                    className="dash-action-btn"
                    disabled={executing['stock-chart'] || !can('stock.manage')}
                    title={!can('stock.manage') ? 'Geen reg — vra Admin' : `Hervul ${firstCriticalStock.stock_name}`}
                    onClick={() => handleExecute({ type: 'reorder_stock', label: `Hervul ${firstCriticalStock.stock_name}`, description: `${firstCriticalStock.stock_name} (${firstCriticalStock.amount}/${firstCriticalStock.minimum})`, params: { stock_id: firstCriticalStock.stock_id, amount: (firstCriticalStock.minimum||10)*2 } }, 'stock-chart')}
                  >
                    {executing['stock-chart'] ? 'Besig...' : `Hervul ${firstCriticalStock.stock_name}`}
                  </button>
                </div>
              )}
            </div>
          </div>

          {/* ── RY 4: Tendens + Foute per Gebou ── */}
          <div className="charts-container" style={{ marginTop: '20px' }}>
            <div className="data-panel">
              <div className="panel-header">
                <h3>Tendens 8 Weke — Foute vs Herstel</h3>
                <Link to="/work-orders" className="view-all">Bekyk agterstand →</Link>
              </div>
              <div className="chart-container" style={{ height: '260px' }}>
                <Line
                  data={trendData}
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { position: 'bottom' } },
                    scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                  }}
                />
              </div>
              <div style={{ color: '#6b7280', fontSize: '12px', textAlign: 'center', marginTop: '6px' }}>
                Gap groei = agterstand neem toe. Geskep vs voltooi per week.
              </div>
            </div>
            <div className="data-panel">
              <div className="panel-header">
                <h3>Foute per Gebou (30 dae)</h3>
                <Link to="/fault-tickets" className="view-all">Bekyk foute →</Link>
              </div>
              <div className="chart-container" style={{ height: '260px' }}>
                <Bar
                  data={faultsPerBuildingData}
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { display: false } },
                    scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                  }}
                />
              </div>
              {!hasData(faultsPerBuildingData.datasets[0].data) && (
                <div style={{ textAlign: 'center', color: '#94a3b8', fontSize: '13px', marginTop: '6px' }}>Geen foute laaste 30 dae — stabiele terrein.</div>
              )}
            </div>
          </div>

          {/* ── RY 5: AI 9 Visuals ── */}
          {Object.keys(aiCharts).length > 0 && (
            <>
              <div style={{ marginTop: '24px', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                <h2 style={{ margin: 0, color: '#0e1e3b', fontSize: '18px' }}>AI Asset & Werksopdrag Analise</h2>
                <span style={{ background: '#d4edda', color: '#155724', padding: '3px 8px', borderRadius: '12px', fontSize: '11px', fontWeight: 700 }}>AI gegenereer • elke run vars</span>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: '20px' }}>
                {aiOrder.filter((k) => aiCharts[k]).map((key) => {
                  const chart = aiCharts[key];
                  const labels = chart.labels || [];
                  const datasets = (chart.datasets || []).map((ds, i) => ({
                    label: ds.label,
                    data: ds.data,
                    backgroundColor: chart.type === 'doughnut'
                      ? ['#935e28', '#b8863c', '#d4a357', '#e8c49a', '#f0dcc8', '#10b981', '#f59e0b', '#ef4444'].slice(0, (ds.data||[]).length)
                      : ds.backgroundColor || ['#935e28', '#b8863c', '#d4a357', '#10b981', '#f59e0b', '#ef4444'][i % 6],
                    borderColor: chart.type === 'line' ? '#935e28' : undefined,
                    borderWidth: chart.type === 'line' ? 2 : 0,
                    fill: chart.type === 'line' ? false : true,
                    tension: 0.3,
                  }));
                  const data = { labels, datasets };
                  const opts = {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                      legend: { position: chart.type === 'doughnut' ? 'bottom' : 'bottom' },
                      title: { display: false },
                    },
                    scales: chart.type === 'doughnut' ? {} : { y: { beginAtZero: true, ticks: { precision: 0 } }, x: { ticks: { maxRotation: 45 } } },
                  };
                  const cards = chart.cards;
                  const hasDirectAction = ['criticality_matrix','sla_compliance','failure_pareto','technician_load'].includes(key);
                  const aiSuggestion = (() => {
                    if (key === 'criticality_matrix' && firstTopRisk) return { type: 'create_work_order', label: `Werksopdrag vir ${firstTopRisk.asset_name} (Hoog/ Hoog)`, description: firstTopRisk.reason || 'Kritieke risiko/impak', params: { asset_id: firstTopRisk.asset_id, job_desc: `Kritiek: ${firstTopRisk.asset_name}`, job_priority: 'Dringend' } };
                    if (key === 'sla_compliance' && firstHighFault) return { type: 'create_work_order', label: `Werksopdrag vir SLA-oortreding fout #${firstHighFault.fault_id}`, description: String(firstHighFault.fault_description||'').slice(0,80), params: { fault_id: firstHighFault.fault_id, job_desc: String(firstHighFault.fault_description||''), room_id: firstHighFault.room_id, job_priority: 'Dringend' } };
                    if (key === 'failure_pareto' && firstTopRisk) return { type: 'create_work_order', label: `Werksopdrag vir pareto-bate ${firstTopRisk.asset_name}`, description: 'Top faling klas', params: { asset_id: firstTopRisk.asset_id, job_desc: `Pareto opvolg: ${firstTopRisk.asset_name}`, job_priority: 'Hoog' } };
                    if (key === 'technician_load' && unassignedJob) return { type: 'assign_job', label: `Ken werksopdrag #${unassignedJob.jobcard_id} aan my toe`, description: String(unassignedJob.job_desc||'').slice(0,80), params: { jobcard_id: unassignedJob.jobcard_id } };
                    return null;
                  })();
                  const viewLink = aiLinkMap[key] || '/predictions';
                  return (
                    <div key={key} className="data-panel">
                      <div className="panel-header">
                        <h3 style={{ fontSize: '14px' }}>{chart.title || key}</h3>
                        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                          <Link to={viewLink} className="view-all">Bekyk →</Link>
                          {hasDirectAction && aiSuggestion && (
                            <button
                              className="dash-action-btn dash-action-btn--small"
                              disabled={!!executing[`ai-${key}`] || (aiSuggestion.type==='reorder_stock' ? !can('stock.manage') : !can('jobs.manage'))}
                              title={(aiSuggestion.type==='reorder_stock' ? !can('stock.manage') : !can('jobs.manage')) ? 'Geen reg — vra Admin' : aiSuggestion.label}
                              onClick={() => handleExecute(aiSuggestion, `ai-${key}`)}
                            >
                              {executing[`ai-${key}`] ? 'Besig...' : 'Uitvoer'}
                            </button>
                          )}
                          {hasDirectAction && !aiSuggestion && (
                            <button className="dash-action-btn dash-action-btn--small" disabled title="Geen aksie benodig tans" style={{ opacity: 0.45 }}>Uitvoer</button>
                          )}
                        </div>
                      </div>
                      {cards && (
                        <div style={{ display: 'flex', gap: '10px', marginBottom: '8px' }}>
                          <div style={{ flex: 1, background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px', padding: '8px', textAlign: 'center' }}>
                            <div style={{ fontSize: '11px', color: '#065f46' }}>MTTR</div>
                            <div style={{ fontSize: '18px', fontWeight: 800, color: '#065f46' }}>{cards.mttr}h</div>
                          </div>
                          <div style={{ flex: 1, background: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '8px', padding: '8px', textAlign: 'center' }}>
                            <div style={{ fontSize: '11px', color: '#1e40af' }}>MTBF</div>
                            <div style={{ fontSize: '18px', fontWeight: 800, color: '#1e40af' }}>{cards.mtbf_days}d</div>
                          </div>
                        </div>
                      )}
                      <div className="chart-container" style={{ height: '260px' }}>
                        {chart.type === 'line' ? <Line data={data} options={opts} /> : chart.type === 'doughnut' ? <Doughnut data={data} options={opts} /> : <Bar data={data} options={opts} />}
                      </div>
                      {chart.insights && chart.insights.length > 0 && (
                        <div style={{ fontSize: '12px', color: '#6b7280', marginTop: '8px' }}>
                          {chart.insights.slice(0, 2).map((ins, idx) => <div key={idx}>• {ins}</div>)}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </>
          )}
        </div>
      {confirmDialog}
      </div>
  );
}

export default PredictionsPage;