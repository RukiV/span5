import React, { useState, useRef, useEffect } from 'react';
import './ColumnPicker.css';

/**
 * ColumnPicker — Dropdown checklist for toggling column visibility.
 *
 * Props:
 *   columns        – [{ key, label }] — all possible columns
 *   visibleColumns – [{ key, label }] — currently visible columns
 *   toggleColumn(key)  – toggle one column
 *   resetVisibility()  – restore defaults
 *   onResetWidths()    – optional; reset column widths too
 *
 * To trigger right-click from a <th>:
 *   <th onContextMenu={(e) => picker.openAt(e)}>
 *
 * Use a ref: const picker = useRef(null);
 *   <ColumnPicker ref={picker} ... />
 *   <th onContextMenu={(e) => picker.current?.openAt(e)} />
 */
const ColumnPicker = React.forwardRef(function ColumnPicker(
  { columns, visibleColumns, toggleColumn, resetVisibility, onResetWidths },
  ref,
) {
  const [open, setOpen] = useState(false);
  const [position, setPosition] = useState(null); // { x, y } for right-click position
  const dropdownRef = useRef(null);
  const btnRef = useRef(null);

  // Expose openAt for parent to call on right-click
  React.useImperativeHandle(ref, () => ({
    openAt(e) {
      setPosition({ x: e.clientX, y: e.clientY });
      setOpen(true);
    },
  }));

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    const handler = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target) &&
          btnRef.current && !btnRef.current.contains(e.target)) {
        setOpen(false);
        setPosition(null);
      }
    };
    const timer = setTimeout(() => document.addEventListener('click', handler), 0);
    return () => { clearTimeout(timer); document.removeEventListener('click', handler); };
  }, [open]);

  // Close on Escape
  useEffect(() => {
    if (!open) return;
    const handler = (e) => { if (e.key === 'Escape') { setOpen(false); setPosition(null); } };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [open]);

  const visibleKeys = new Set(visibleColumns.map((c) => c.key));
  const hiddenCount = columns.length - visibleKeys.size;

  return (
    <>
      {/* Dedicated button */}
      <button
        ref={btnRef}
        className={`colpick-btn ${open ? 'colpick-btn--active' : ''} ${hiddenCount > 0 ? 'colpick-btn--has-hidden' : ''}`}
        onClick={(e) => {
          e.stopPropagation();
          const rect = e.currentTarget.getBoundingClientRect();
          setPosition({ x: rect.left, y: rect.bottom + 4 });
          setOpen((p) => !p);
        }}
        title="Kies kolomme om te vertoon"
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
          <rect x="1" y="2" width="14" height="2" rx="1"/>
          <rect x="1" y="7" width="14" height="2" rx="1"/>
          <rect x="1" y="12" width="14" height="2" rx="1"/>
          <rect x="11" y="3" width="2" height="1" fill="transparent"/>
          <rect x="11" y="8" width="2" height="1" fill="transparent"/>
        </svg>
        Kolomme
        {hiddenCount > 0 && <span className="colpick-badge">{hiddenCount}</span>}
      </button>

      {/* Dropdown */}
      {open && (
        <div
          ref={dropdownRef}
          className="colpick-dropdown"
          style={{ position: 'fixed', left: position.x, top: position.y, zIndex: 10000 }}
          onMouseDown={(e) => e.stopPropagation()}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="colpick-header">
            <span>Wys kolomme</span>
            <button type="button" className="colpick-close" onClick={() => { setOpen(false); setPosition(null); }}>&times;</button>
          </div>
          <div className="colpick-list">
            {columns.map((col) => {
              const checked = visibleKeys.has(col.key);
              return (
                <label key={col.key} className="colpick-item" onClick={() => toggleColumn(col.key)}>
                  <span className={`colpick-checkmark ${checked ? 'checked' : ''}`}>
                    {checked ? '✓' : ''}
                  </span>
                  <span className="colpick-label">{col.label}</span>
                </label>
              );
            })}
          </div>
          <div className="colpick-footer">
            <button type="button" className="colpick-reset" onClick={() => { resetVisibility(); if (onResetWidths) onResetWidths(); setOpen(false); }}>
              Reset na verstek
            </button>
          </div>
        </div>
      )}
    </>
  );
});

export default ColumnPicker;
