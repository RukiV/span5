import React, { useState, useRef, useEffect } from 'react';
import Select from 'react-select';
import useCascadeMenu from '../../hooks/useCascadeMenu';
import {
  CascadeControl,
  CascadeIndicatorsContainer,
  NoCascadeClearIndicator,
  renderBreadcrumb,
} from '../controlHelpers';
import './FilterPicker.css';

/**
 * FilterPicker — consolidated toolbar filter (search text + location cascade).
 *
 * Renders a "Filtreer" button (with an active-filter badge) that opens a
 * dropdown containing a text search input (synced to the page's search state)
 * and the Terrein › Gebou › Lokaal location cascade. Optional `onStatusChange`
 * / `statusValue` adds a status column filter. Styling mirrors SortPicker and
 * ColumnPicker so the control fits naturally in the same toolbar.
 *
 * Props:
 *   search / onSearch          – text search (page's header search state)
 *   filterColumn/onFilterColumnChange/filterColumnOptions – optional "Soek per
 *                               kolom" select that scopes the text search
 *   terrainFilter/buildingFilter/roomFilter – location cascade values ('' = none)
 *   onLocationChange(terrain, building, room) – called whenever the cascade
 *                                               changes (also on clear)
 *   locationOptions            – flat options from buildFlatLocationOptions(...)
 *   maxLevel                   – 3 (default) or 2 (rooms-only list)
 *   lockedTerrain              – non-admin auto-scope location id; when set the
 *                                terrain level is fixed by the backend scope and
 *                                excluded from the active-filter badge
 *   statusValue/onStatusChange – optional status filter ("" = nie gefiltreer nie)
 *   statusOptions              – [{ value, label }] for the status select
 *   onReset                    – clears search + all cascade levels (+ status)
 */
export default function FilterPicker({
  search = '',
  onSearch,
  filterColumn = 'all',
  onFilterColumnChange = null,
  filterColumnOptions = [],
  terrainFilter = '',
  buildingFilter = '',
  roomFilter = '',
  onLocationChange,
  locationOptions = [],
  maxLevel = 3,
  lockedTerrain = null,
  statusValue = '',
  onStatusChange = null,
  statusOptions = [],
  onReset,
}) {
  const [open, setOpen] = useState(false);
  const [position, setPosition] = useState(null);
  const dropdownRef = useRef(null);
  const btnRef = useRef(null);
  const filterCascade = useCascadeMenu();

  const depthLevels = maxLevel === 2 ? 2 : 3;
  const placeholders =
    depthLevels === 2
      ? ['Kies Terrein...', 'Kies Gebou...', 'Filter voltooi']
      : ['Kies Terrein...', 'Kies Gebou...', 'Kies Lokaal...', 'Filter voltooi'];

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    const handler = (e) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(e.target) &&
        btnRef.current &&
        !btnRef.current.contains(e.target)
      ) {
        setOpen(false);
      }
    };
    const timer = setTimeout(() => document.addEventListener('click', handler), 0);
    return () => {
      clearTimeout(timer);
      document.removeEventListener('click', handler);
    };
  }, [open]);

  // Close on Escape
  useEffect(() => {
    if (!open) return;
    const handler = (e) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [open]);

  const cascadeCount = [terrainFilter, buildingFilter, roomFilter].filter(Boolean).length;
  const locationActive = lockedTerrain
    ? Math.max(0, cascadeCount - 1)
    : cascadeCount;
  const badgeCount =
    (search && search.trim() ? 1 : 0) +
    (filterColumn && filterColumn !== 'all' ? 1 : 0) +
    locationActive +
    (statusValue ? 1 : 0);

  const columnValue = filterColumnOptions.find(
    (o) => String(o.value) === String(filterColumn),
  ) || filterColumnOptions.find((o) => o.value === 'all') || null;

  // Skat die wydte wat nodig is om die wydste opsie-etiket van die huidige
  // kaskade-vlak te wys (die oop keuselys moet wyer word namate die ligging
  // gekies word, sodat lang etikette soos "12 - Konferensiekamer (Hoofgebou)"
  // volledig lees). Is 'n rugsteun — CSS `width: max-content` doen die groei.
  const pxPerChar = 7.6;
  const textWidthPx = (chars) => Math.ceil(chars * pxPerChar + 64);
  const longestLabel = (options) =>
    options.reduce((m, o) => Math.max(m, o && o.label ? o.label.length : 0), 0);
  const cascadeLevel = Math.min(cascadeCount, depthLevels - 1);
  const cascadeWidth = Math.max(
    260,
    textWidthPx(
      longestLabel(
        locationOptions.filter((o) => o._cascadeLevel === cascadeLevel),
      ),
    ),
  );

  const findOption = (level, value) =>
    locationOptions.find(
      (o) =>
        o._cascadeLevel === level &&
        o.value != null &&
        String(o.value) === String(value),
    );

  const currentDisplayValue = cascadeCount === 0 ? null
    : cascadeCount === 1 && terrainFilter
      ? (() => { const o = findOption(0, terrainFilter); return { value: terrainFilter, label: o ? o.label : terrainFilter }; })()
      : cascadeCount === 2 && buildingFilter
        ? (() => { const o = findOption(1, buildingFilter); return { value: buildingFilter, label: o ? o.label : buildingFilter }; })()
        : null;

  const clearFromLevel = (levelIndex) => {
    if (levelIndex <= 0) onLocationChange('', '', '');
    else if (levelIndex === 1) onLocationChange(terrainFilter, '', '');
    else if (levelIndex === 2) onLocationChange(terrainFilter, buildingFilter, '');
  };

  const breadcrumbData = [{ level: -1, name: 'Terreine' }];
  if (terrainFilter) {
    const o = findOption(0, terrainFilter);
    breadcrumbData.push({ level: 0, name: o ? o.label : terrainFilter });
  }
  if (buildingFilter) {
    const o = findOption(1, buildingFilter);
    breadcrumbData.push({ level: 1, name: o ? o.label : buildingFilter });
  }
  if (roomFilter) {
    const o = findOption(2, roomFilter);
    breadcrumbData.push({ level: 2, name: o ? o.label : roomFilter });
  }

  return (
    <>
      <button
        ref={btnRef}
        className={`colpick-btn filterpick-btn ${open ? 'colpick-btn--active' : ''} ${
          badgeCount > 0 ? 'filterpick-btn--has-filters' : ''
        }`}
        onClick={(e) => {
          e.stopPropagation();
          const rect = e.currentTarget.getBoundingClientRect();
          setPosition({ x: rect.left, y: rect.bottom + 4 });
          setOpen((p) => !p);
        }}
        title="Filtreer deur teks of ligging"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
          <path d="M4.25 5.61C6.27 8.2 10 13 10 13v6c0 .55.45 1 1 1h2c.55 0 1-.45 1-1v-6s3.72-4.8 5.74-7.39C20.25 4.95 19.78 4 18.95 4H5.04c-.83 0-1.3.95-.79 1.61z"/>
        </svg>
        Filtreer
        {badgeCount > 0 && <span className="colpick-badge">{badgeCount}</span>}
      </button>

      {open && (
        <div
          ref={dropdownRef}
          className="colpick-dropdown filterpick-dropdown"
          style={{ position: 'fixed', left: position.x, top: position.y, zIndex: 10000 }}
          onMouseDown={(e) => e.stopPropagation()}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="colpick-header">
            <span>Filtreer</span>
            <button type="button" className="colpick-close" onClick={() => setOpen(false)}>&times;</button>
          </div>
          <div className="filterpick-body">
            <div className="filterpick-section-label">Tekstsoektog</div>
            <div className="control-input-shell filterpick-search">
              <input
                type="text"
                placeholder="Tik om te filter..."
                value={search}
                onChange={(e) => onSearch && onSearch(e.target.value)}
              />
            </div>

            {filterColumnOptions.length > 0 && (
              <>
                <div className="filterpick-section-label">Soek per kolom</div>
                <Select
                  className="react-select-container"
                  classNamePrefix="react-select"
                  placeholder={columnValue?.label || 'Alle kolomme'}
                  isSearchable={false}
                  closeMenuOnSelect={false}
                  blurInputOnSelect={false}
                  value={columnValue}
                  onChange={(o) =>
                    onFilterColumnChange && onFilterColumnChange(o ? o.value : 'all')
                  }
                  options={filterColumnOptions}
                />
              </>
            )}

            {onLocationChange && (
              <>
            <div className="filterpick-section-label">Ligging</div>
            {lockedTerrain && (
              <div className="filterpick-locked">
                Terrein vasgesluit: {currentNameForLevel(0, terrainFilter) || terrainFilter}
              </div>
            )}
            <div className="control-cascade-stack filterpick-cascade" ref={filterCascade.containerRef}>
              <div className="control-cascade-breadcrumb">
                {renderBreadcrumb({ breadcrumbData, cascadeCount, clearFromLevel, maxLevel: depthLevels })}
              </div>
              <Select
                className="react-select-container"
                classNamePrefix="react-select"
                placeholder={placeholders[cascadeCount] || 'Filter voltooi'}
                isClearable
                isDisabled={cascadeCount >= depthLevels}
                closeMenuOnSelect={false}
                menuIsOpen={filterCascade.menuIsOpen}
                onMenuOpen={filterCascade.onMenuOpen}
                onMenuClose={filterCascade.onMenuClose}
                components={{
                  Control: (p) => <CascadeControl {...p} cascadeCount={cascadeCount} clearFromLevel={clearFromLevel} />,
                  IndicatorsContainer: CascadeIndicatorsContainer,
                  ClearIndicator: NoCascadeClearIndicator,
                }}
                styles={{
                  container: (base) => ({ ...base, minWidth: cascadeWidth }),
                  menu: (base) => ({ ...base, minWidth: cascadeWidth }),
                }}
                options={locationOptions}
                filterOption={(option, rawInput) => {
                  const level = cascadeCount;
                  const d = option.data;
                  const q = rawInput ? option.label.toLowerCase().includes(rawInput.toLowerCase()) : false;
                  if (level === 0) {
                    if (rawInput) return d._cascadeLevel <= depthLevels - 1 && q;
                    return d._cascadeLevel === 0;
                  }
                  if (level === 1) {
                    if (rawInput) return d._cascadeLevel >= 1 && d._cascadeLevel <= depthLevels - 1 && String(d._fields.location_id) === String(terrainFilter) && q;
                    return d._cascadeLevel === 1 && String(d._parentId) === String(terrainFilter);
                  }
                  if (level === 2) {
                    if (rawInput) return d._cascadeLevel === 2 && String(d._fields.building_id) === String(buildingFilter) && q;
                    return d._cascadeLevel === 2 && String(d._parentId) === String(buildingFilter);
                  }
                  return false;
                }}
                value={currentDisplayValue}
                onChange={(selectedOption) => {
                  if (!selectedOption) { onLocationChange('', '', ''); return; }
                  const f = selectedOption._fields || {};
                  onLocationChange(f.location_id || '', f.building_id || '', f.room_id || '');
                }}
              />
            </div>
              </>
            )}

            {onStatusChange && statusOptions.length > 0 && (
              <>
                <div className="filterpick-section-label">Status</div>
                <Select
                  className="react-select-container"
                  classNamePrefix="react-select"
                  placeholder="Alle statusse"
                  isClearable
                  closeMenuOnSelect={false}
                  blurInputOnSelect={false}
                  value={
                    statusValue
                      ? statusOptions.find((o) => String(o.value) === String(statusValue)) || { value: statusValue, label: statusValue }
                      : null
                  }
                  onChange={(o) => onStatusChange(o ? o.value : '')}
                  options={statusOptions}
                />
              </>
            )}
          </div>
          <div className="colpick-footer">
            <button
              type="button"
              className="colpick-reset"
              onClick={() => {
                onReset && onReset();
                onFilterColumnChange && onFilterColumnChange('all');
                setOpen(false);
              }}
            >
              Maak skoon
            </button>
          </div>
        </div>
      )}
    </>
  );

  function currentNameForLevel(level, value) {
    const o = findOption(level, value);
    return o ? o.label : '';
  }
}