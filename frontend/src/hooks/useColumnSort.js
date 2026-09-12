import { useState, useCallback, useEffect } from 'react';

const STORAGE_PREFIX = 'colsort_';

function loadSorts(storageKey, columns, defaultSorts) {
  if (!storageKey) return defaultSorts || [];
  try {
    const raw = localStorage.getItem(STORAGE_PREFIX + storageKey);
    if (!raw) return defaultSorts || [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return defaultSorts || [];
    const validKeys = new Set(columns.map((c) => c.key));
    const cleaned = [];
    for (const item of parsed) {
      if (!item || !validKeys.has(item.key)) continue;
      if (cleaned.some((s) => s.key === item.key)) continue;
      cleaned.push({ key: item.key, direction: item.direction === 'desc' ? 'desc' : 'asc' });
    }
    if (cleaned.length > 0) return cleaned;
    return defaultSorts || [];
  } catch (e) {
    return defaultSorts || [];
  }
}

/**
 * useColumnSort — Multi-column sort state management with persistence.
 *
 * Supports an ordered list of sort criteria (primary first). Persists per-page
 * to localStorage under `colsort_<storageKey>` (cleared automatically when the
 * app logs out). Use applySort with a per-page `getSortValue(row, key)`
 * getter to sort rows.
 *
 * Usage:
 *   const { sorts, addSort, removeSort, toggleDirection, moveSort,
 *           clearSorts, applySort } = useColumnSort({
 *     columns: COLUMNS,
 *     storageKey: 'users-page',
 *     defaultSorts: [{ key: 'id', direction: 'asc' }],
 *   });
 *
 *   // In your filter chain:
 *   const ordered = applySort(filtered, (row, key) => {
 *     switch (key) {
 *       case 'id': return Number(row.user_id);
 *       case 'name': return String(row.user_name);
 *       ...
 *     }
 *   });
 */
export default function useColumnSort({
  columns = [],
  storageKey = null,
  defaultSorts = [],
} = {}) {
  const [sorts, setSorts] = useState(() =>
    loadSorts(storageKey, columns, defaultSorts),
  );

  useEffect(() => {
    if (!storageKey) return;
    try {
      localStorage.setItem(STORAGE_PREFIX + storageKey, JSON.stringify(sorts));
    } catch (e) {
      // ignore storage errors (private mode etc.)
    }
  }, [storageKey, sorts]);

  const addSort = useCallback((key) => {
    setSorts((prev) =>
      prev.some((s) => s.key === key)
        ? prev
        : [...prev, { key, direction: 'asc' }],
    );
  }, []);

  const removeSort = useCallback((key) => {
    setSorts((prev) => prev.filter((s) => s.key !== key));
  }, []);

  const toggleDirection = useCallback((key) => {
    setSorts((prev) =>
      prev.map((s) =>
        s.key === key
          ? { ...s, direction: s.direction === 'asc' ? 'desc' : 'asc' }
          : s,
      ),
    );
  }, []);

  const moveSort = useCallback((key, delta) => {
    setSorts((prev) => {
      const idx = prev.findIndex((s) => s.key === key);
      if (idx < 0) return prev;
      const target = idx + delta;
      if (target < 0 || target >= prev.length) return prev;
      const next = [...prev];
      const [item] = next.splice(idx, 1);
      next.splice(target, 0, item);
      return next;
    });
  }, []);

  const clearSorts = useCallback(() => setSorts([]), []);

  const applySort = useCallback(
    (rows, getSortValue) => {
      if (!sorts.length) return rows;
      return [...rows].sort((a, b) => {
        for (const { key, direction } of sorts) {
          const va = getSortValue(a, key);
          const vb = getSortValue(b, key);
          let cmp;
          if (typeof va === 'number' && typeof vb === 'number') {
            cmp = va - vb;
          } else {
            cmp = String(va ?? '').localeCompare(
              String(vb ?? ''),
              'af',
              { sensitivity: 'base' },
            );
          }
          if (cmp !== 0) return direction === 'asc' ? cmp : -cmp;
        }
        return 0;
      });
    },
    [sorts],
  );

  return {
    sorts,
    addSort,
    removeSort,
    toggleDirection,
    moveSort,
    clearSorts,
    applySort,
  };
}