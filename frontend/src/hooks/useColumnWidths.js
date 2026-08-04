import { useState, useCallback } from 'react';

const MIN_WIDTH = 60;
const MAX_WIDTH = 600;

/**
 * useColumnWidths — Manage resizable table column widths.
 *
 * Stores widths in localStorage (keyed by storageKey) so user
 * preferences persist across sessions. Widths are in pixels.
 *
 * Usage:
 *   const colWidths = useColumnWidths('stock-page', STOCK_COLUMNS);
 *
 *   // In <th>:
 *   <th style={colWidths.getStyle(col.key)}>...</th>
 *   // or with <ResizableTh>: <ResizableTh col={col} colWidths={colWidths} ... />
 *
 * Returns:
 *   getWidth(key)   → number | null (null = auto)
 *   getStyle(key)   → { width } style object for the <th>
 *   setWidth(key, px) → clamp + persist
 *   resetWidths()   → clear all persisted widths
 *   isResized(key)  → true if a width is stored for key
 */
export default function useColumnWidths(storageKey, columnDefs) {
  const [widths, setWidths] = useState(() => {
    try {
      const stored = localStorage.getItem(`colwidths_${storageKey}`);
      if (stored) {
        const parsed = JSON.parse(stored);
        if (parsed && typeof parsed === 'object') {
          // Only keep keys that still exist in columnDefs
          const valid = {};
          columnDefs.forEach((c) => {
            const w = Number(parsed[c.key]);
            if (w && w >= MIN_WIDTH && w <= MAX_WIDTH) valid[c.key] = w;
          });
          return valid;
        }
      }
    } catch (_) { /* ignore */ }
    return {};
  });

  // Persist to localStorage
  const persist = useCallback((next) => {
    try { localStorage.setItem(`colwidths_${storageKey}`, JSON.stringify(next)); }
    catch (_) { /* ignore */ }
  }, [storageKey]);

  const setWidth = useCallback((key, px) => {
    const clamped = Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, Math.round(px)));
    setWidths((prev) => {
      const next = { ...prev, [key]: clamped };
      persist(next);
      return next;
    });
  }, [persist]);

  const getWidth = useCallback((key) => (widths[key] ?? null), [widths]);

  const getStyle = useCallback((key) => {
    const w = widths[key];
    return w ? { width: `${w}px` } : {};
  }, [widths]);

  const resetWidths = useCallback(() => {
    setWidths({});
    try { localStorage.removeItem(`colwidths_${storageKey}`); }
    catch (_) { /* ignore */ }
  }, [storageKey]);

  const isResized = useCallback((key) => widths[key] != null, [widths]);

  return { getWidth, getStyle, setWidth, resetWidths, isResized };
}
