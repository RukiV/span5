import React, { useState, useRef, useEffect } from 'react';
import './SortPicker.css';

/**
 * SortPicker — Button + dropdown for multi-column sorting.
 *
 * Maintains an ordered list of sort criteria (primary first). Styling mirrors
 * the ColumnPicker so both fit naturally in the same toolbar.
 *
 * Props:
 *   columns            – [{ key, label }] — all sortable columns
 *   sorts              – [{ key, direction: 'asc'|'desc' }, ...] in priority order
 *   onAdd(key)         – append a column at the lowest priority
 *   onRemove(key)      – remove a column from sorting
 *   onToggleDirection(key) – flip asc/desc for a column
 *   onMove(key, delta) – reorder a column by -1 (up) or +1 (down)
 *   onClear()          – remove all sort criteria
 */
export default function SortPicker({
  columns,
  sorts,
  onAdd,
  onRemove,
  onToggleDirection,
  onMove,
  onClear,
}) {
  const [open, setOpen] = useState(false);
  const [position, setPosition] = useState(null);
  const dropdownRef = useRef(null);
  const btnRef = useRef(null);

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

  const sortedKeys = sorts.map((s) => s.key);
  const addableColumns = columns.filter((c) => !sortedKeys.includes(c.key));

  return (
    <>
      <button
        ref={btnRef}
        className={`colpick-btn sortpick-btn ${open ? 'colpick-btn--active' : ''} ${
          sorts.length > 0 ? 'sortpick-btn--has-sorts' : ''
        }`}
        onClick={(e) => {
          e.stopPropagation();
          const rect = e.currentTarget.getBoundingClientRect();
          setPosition({ x: rect.left, y: rect.bottom + 4 });
          setOpen((p) => !p);
        }}
        title="Kies kolomme om op te sorteer"
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
          <path d="M3 2.5h10a.5.5 0 0 1 0 1H3a.5.5 0 0 1 0-1z"/>
          <path d="M3 6.5h6a.5.5 0 0 1 0 1H3a.5.5 0 0 1 0-1z"/>
          <path d="M3 10.5h6a.5.5 0 0 1 0 1H3a.5.5 0 0 1 0-1z"/>
          <path d="M11.5 5V12.8m0 0l-1.5-1.7m1.5 1.7l1.5-1.7" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
        </svg>
        Sorteer
        {sorts.length > 0 && <span className="colpick-badge">{sorts.length}</span>}
      </button>

      {open && (
        <div
          ref={dropdownRef}
          className="colpick-dropdown sortpick-dropdown"
          style={{ position: 'fixed', left: position.x, top: position.y, zIndex: 10000 }}
          onMouseDown={(e) => e.stopPropagation()}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="colpick-header">
            <span>Sorteer volgens</span>
            <button type="button" className="colpick-close" onClick={() => setOpen(false)}>&times;</button>
          </div>
          <div className="sortpick-list">
            {sorts.length === 0 && (
              <div className="sortpick-empty">Nog geen sortering gekies nie.</div>
            )}
            {sorts.map((sort, index) => {
              const label = columns.find((c) => c.key === sort.key)?.label || sort.key;
              return (
                <div key={sort.key} className="sortpick-item">
                  <span className="sortpick-ordinal">{index + 1}</span>
                  <span className="sortpick-label">{label}</span>
                  <button
                    type="button"
                    className="sortpick-mini"
                    title={sort.direction === 'asc' ? 'Oplopend (A–Z)' : 'Aflopend (Z–A)'}
                    onClick={() => onToggleDirection(sort.key)}
                  >
                    {sort.direction === 'asc' ? '↑' : '↓'}
                  </button>
                  <button
                    type="button"
                    className="sortpick-mini"
                    title="Beweeg hoër prioriteit"
                    disabled={index === 0}
                    onClick={() => onMove(sort.key, -1)}
                  >
                    ▲
                  </button>
                  <button
                    type="button"
                    className="sortpick-mini"
                    title="Beweeg laer prioriteit"
                    disabled={index === sorts.length - 1}
                    onClick={() => onMove(sort.key, 1)}
                  >
                    ▼
                  </button>
                  <button
                    type="button"
                    className="sortpick-mini sortpick-remove"
                    title="Verwyder kolom"
                    onClick={() => onRemove(sort.key)}
                  >
                    &times;
                  </button>
                </div>
              );
            })}
            {addableColumns.length > 0 && (
              <>
                <div className="sortpick-section">Voeg kolom by</div>
                {addableColumns.map((col) => (
                  <div
                    key={col.key}
                    className="sortpick-item sortpick-add"
                    onClick={() => onAdd(col.key)}
                  >
                    <span className="sortpick-plus">+</span>
                    <span className="sortpick-label">{col.label}</span>
                  </div>
                ))}
              </>
            )}
          </div>
          <div className="colpick-footer">
            <button
              type="button"
              className="colpick-reset"
              onClick={() => {
                onClear();
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
}