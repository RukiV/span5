import { useState, useMemo, useEffect, useCallback } from 'react';

/**
 * usePagination — Client-side pagination slicing.
 *
 * Slices `data` into pages of `pageSize` (default 100).
 * Clamps currentPage when data length shrinks (delete/filter).
 *
 * Usage:
 *   const { currentPage, totalPages, paginatedData, goToPage, nextPage, prevPage } = usePagination(filteredItems, 100);
 *   // Render paginatedData.map instead of filteredItems.map
 *   // <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={goToPage} ... />
 *   // Reset on filter change: useEffect(()=> goToPage(1), [searchTerm, sortKey, ...])
 */
export default function usePagination(data = [], pageSize = 100) {
  const [currentPage, setCurrentPage] = useState(1);

  const totalItems = Array.isArray(data) ? data.length : 0;
  const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));

  // Clamp currentPage if data shrinks (e.g., after delete or filter)
  useEffect(() => {
    if (currentPage > totalPages) {
      setCurrentPage(totalPages);
    }
  }, [currentPage, totalPages]);

  const paginatedData = useMemo(() => {
    if (!Array.isArray(data) || data.length === 0) return [];
    const start = (currentPage - 1) * pageSize;
    return data.slice(start, start + pageSize);
  }, [data, currentPage, pageSize]);

  const goToPage = useCallback((page) => {
    const p = Math.min(Math.max(1, Number(page) || 1), totalPages);
    setCurrentPage(p);
  }, [totalPages]);

  const nextPage = useCallback(() => {
    setCurrentPage((p) => Math.min(p + 1, totalPages));
  }, [totalPages]);

  const prevPage = useCallback(() => {
    setCurrentPage((p) => Math.max(p - 1, 1));
  }, []);

  const resetPage = useCallback(() => setCurrentPage(1), []);

  return {
    currentPage,
    totalPages,
    totalItems,
    pageSize,
    paginatedData,
    goToPage,
    nextPage,
    prevPage,
    resetPage,
    setCurrentPage,
  };
}
