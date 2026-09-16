import React, { useRef, useCallback } from 'react';

const RESIZER_WIDTH = 6;

/**
 * ResizableTh — Table header cell with a drag-to-resize handle.
 *
 * Drop-in replacement for the existing <th> in the standard tables.
 * Preserves sorting (onClick) and the right-click column picker
 * (onContextMenu). Adds a thin drag handle on the right edge that
 * resizes the column via a useColumnWidths hook.
 *
 * Props:
 *   col         – { key, label, sortKey?, render? }
 *   colWidths   – return value of useColumnWidths(storageKey, columns)
 *   className   – extra classes (e.g. sortable state classes)
 *   onClick     – sort toggle handler (or undefined for non-sortable)
 *   onContextMenu – right-click handler for the column picker
 *   children    – optional custom content (falls back to col.label)
 */
export default function ResizableTh({
  col,
  colWidths,
  className = '',
  onClick,
  onContextMenu,
  children,
  title,
}) {
  const thRef = useRef(null);
  const dragState = useRef(null);

  const onMouseDown = useCallback((e) => {
    e.preventDefault();
    e.stopPropagation(); // don't trigger column sort
    const th = thRef.current;
    if (!th) return;

    const startX = e.clientX;
    const startWidth = th.getBoundingClientRect().width;

    dragState.current = { startX, startWidth };

    const onMouseMove = (ev) => {
      const st = dragState.current;
      if (!st) return;
      const delta = ev.clientX - st.startX;
      colWidths.setWidth(col.key, st.startWidth + delta);
    };

    const onMouseUp = () => {
      dragState.current = null;
      document.removeEventListener('mousemove', onMouseMove);
      document.removeEventListener('mouseup', onMouseUp);
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    };

    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
  }, [col.key, colWidths]);

  return (
    <th
      ref={thRef}
      className={className}
      onClick={onClick}
      onContextMenu={onContextMenu}
      style={{ position: 'relative', ...colWidths.getStyle(col.key) }}
      title={title}
    >
      {children != null ? children : col.label}
      <span
        className={`col-resizer ${colWidths.isResized(col.key) ? 'col-resizer--active' : ''}`}
        onMouseDown={onMouseDown}
        onDoubleClick={() => colWidths.resetWidths()}
        style={{ width: RESIZER_WIDTH }}
        title="Sleep om breedte aan te pas"
      />
    </th>
  );
}
