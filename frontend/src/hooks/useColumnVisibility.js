import { useState, useCallback, useMemo } from 'react';

/**
 * useColumnVisibility — Manage which table columns are shown/hidden.
 *
 * Stores visibility state in localStorage (keyed by storageKey) so
 * user preferences persist across sessions.
 *
 * Usage:
 *   const COLUMNS = [
 *     { key: 'id',   label: 'ID' },
 *     { key: 'name', label: 'Naam', defaultVisible: true },
 *     { key: 'email', label: 'E-pos' },
 *   ];
 *   const { visibleColumns, toggleColumn, renderHeader, renderCell } =
 *     useColumnVisibility('stock-page', COLUMNS);
 *
 *   // In <thead>: {columns.map(c => renderHeader(c, sortProps))}
 *   // In <tbody>: columns.map(c => <td>{renderCell(item, c)}</td>)
 */
export default function useColumnVisibility(storageKey, columnDefs) {
  // Build defaults
  const defaults = useMemo(() => {
    const map = {};
    columnDefs.forEach((c) => { map[c.key] = c.defaultVisible !== false; });
    return map;
  }, [columnDefs]);

  const [visibility, setVisibility] = useState(() => {
    try {
      const stored = localStorage.getItem(`colvis_${storageKey}`);
      if (stored) {
        const parsed = JSON.parse(stored);
        // Merge with defaults so new columns show up
        return { ...defaults, ...parsed };
      }
    } catch (_) { /* ignore */ }
    return { ...defaults };
  });

  // Persist to localStorage
  const setAndPersist = useCallback((fn) => {
    setVisibility((prev) => {
      const next = typeof fn === 'function' ? fn(prev) : fn;
      try { localStorage.setItem(`colvis_${storageKey}`, JSON.stringify(next)); }
      catch (_) { /* ignore */ }
      return next;
    });
  }, [storageKey]);

  const toggleColumn = useCallback((key) => {
    setAndPersist((prev) => ({ ...prev, [key]: !prev[key] }));
  }, [setAndPersist]);

  const showColumn = useCallback((key) => !!visibility[key], [visibility]);

  const visibleColumns = useMemo(
    () => columnDefs.filter((c) => visibility[c.key] !== false),
    [columnDefs, visibility],
  );

  const hiddenColumns = useMemo(
    () => columnDefs.filter((c) => visibility[c.key] === false),
    [columnDefs, visibility],
  );

  const resetVisibility = useCallback(() => {
    setAndPersist({ ...defaults });
  }, [setAndPersist, defaults]);

  return {
    visibleColumns,
    hiddenColumns,
    toggleColumn,
    showColumn,
    resetVisibility,
    isVisible: (key) => visibility[key] !== false,
    columnDefs,
  };
}
