import { useState, useCallback } from 'react';

/**
 * useColumnSort — Column-click sort state management.
 *
 * Returns helpers to wire up click-to-sort table headers. The actual
 * sorting happens in your existing filter/sort chain using the returned
 * sortKey & sortDirection values.
 *
 * Usage:
 *   const { handleSort, sortKey, sortDirection, getSortIndicator } =
 *     useColumnSort({ defaultSortKey: null, defaultDirection: 'asc' });
 *
 *   // In your filter chain:
 *   .sort((a, b) => {
 *     if (!sortKey) return 0;
 *     const dir = sortDirection === 'asc' ? 1 : -1;
 *     if (sortKey === 'name')
 *       return String(a.name).localeCompare(String(b.name), 'af', { sensitivity: 'base' }) * dir;
 *     // ...
 *   })
 *
 *   // In JSX:
 *   <th onClick={() => handleSort('name')} className={getSortClass('name')}>
 *     Naam{getSortIndicator('name')}
 *   </th>
 */
export default function useColumnSort({
  defaultSortKey = null,
  defaultDirection = 'asc',
} = {}) {
  const [sortKey, setSortKey] = useState(defaultSortKey);
  const [sortDirection, setSortDirection] = useState(defaultDirection);

  const handleSort = useCallback((key) => {
    setSortKey((prev) => {
      if (prev === key) {
        setSortDirection((d) => (d === 'asc' ? 'desc' : 'asc'));
        return prev;
      }
      setSortDirection('asc');
      return key;
    });
  }, []);

  const getSortIndicator = useCallback(
    (key) => {
      if (sortKey !== key) return '';
      return sortDirection === 'asc' ? ' ▲' : ' ▼';
    },
    [sortKey, sortDirection],
  );

  const getSortClass = useCallback(
    (key) => {
      if (sortKey !== key) return 'sortable';
      return sortDirection === 'asc' ? 'sortable sorted-asc' : 'sortable sorted-desc';
    },
    [sortKey, sortDirection],
  );

  return { handleSort, sortKey, sortDirection, getSortIndicator, getSortClass };
}
