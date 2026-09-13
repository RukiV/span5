import { useState, useCallback, useEffect, useMemo } from 'react';

const STORAGE_PREFIX = 'colfilter_';

const EMPTY_FILTER = {
  search: '',
  location_id: '',
  building_id: '',
  room_id: '',
  status: '',
};

function sanitize(raw) {
  const out = { ...EMPTY_FILTER };
  if (raw && typeof raw === 'object') {
    for (const key of Object.keys(EMPTY_FILTER)) {
      if (typeof raw[key] === 'string') out[key] = raw[key];
    }
  }
  return out;
}

function loadFilters(storageKey) {
  if (!storageKey) return { ...EMPTY_FILTER };
  try {
    const raw = localStorage.getItem(STORAGE_PREFIX + storageKey);
    if (!raw) return { ...EMPTY_FILTER };
    return sanitize(JSON.parse(raw));
  } catch (e) {
    return { ...EMPTY_FILTER };
  }
}

/**
 * useFilterState — persisted page filter state (search text, location cascade,
 * optional status column value).
 *
 * Mirrors useColumnSort persistence: stored under `colfilter_<storageKey>` in
 * localStorage (cleared automatically when the app logs out). It is a
 * side-channel for filter state — pages may seed their own useState from
 * `value` and write back via `set`, leaving their existing filter logic
 * untouched.
 *
 * Returns:
 *   value        – { search, location_id, building_id, room_id, status }
 *   set(patch)   – merge a partial patch into the current value
 *   reset()      – restore the empty filter
 *   isActive     – true when at least one filter field is non-empty
 *   activeCount  – number of non-empty filter fields
 */
export default function useFilterState({ storageKey = null } = {}) {
  const [value, setValue] = useState(() => loadFilters(storageKey));

  useEffect(() => {
    if (!storageKey) return;
    try {
      localStorage.setItem(STORAGE_PREFIX + storageKey, JSON.stringify(value));
    } catch (e) {
      // ignore storage errors (private mode etc.)
    }
  }, [storageKey, value]);

  const set = useCallback((patch) => {
    setValue((prev) => {
      const next = { ...prev, ...sanitize(patch) };
      const changed = Object.keys(EMPTY_FILTER).some((k) => next[k] !== prev[k]);
      return changed ? next : prev;
    });
  }, []);

  const reset = useCallback(() => setValue({ ...EMPTY_FILTER }), []);

  const activeKeys = Object.keys(EMPTY_FILTER).filter((k) => value[k]);
  const isActive = activeKeys.length > 0;

  return useMemo(
    () => ({ value, set, reset, isActive, activeCount: activeKeys.length }),
    [value, set, reset, isActive, activeKeys],
  );
}