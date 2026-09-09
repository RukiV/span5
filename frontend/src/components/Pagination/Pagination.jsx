import React from 'react';
import './Pagination.css';

/**
 * Pagination — 100 rekords per bladsy, Afrikaans UI.
 *
 * Props:
 *   currentPage  – huidige bladsy (1-based)
 *   totalPages   – totale aantal bladsye
 *   onPageChange(page) – callback
 *   totalItems   – totale rekords (vir “Wys X-Y van Z”)
 *   pageSize     – default 100
 */
export default function Pagination({ currentPage, totalPages, onPageChange, totalItems, pageSize = 100 }) {
  // Always render sticky bar (user requested still sticky even when single page)
  // Clamp totalPages to at least 1 for display
  const safeTotalPages = Math.max(1, totalPages || 1);
  const startItem = totalItems === 0 ? 0 : (currentPage - 1) * pageSize + 1;
  const endItem = Math.min(currentPage * pageSize, totalItems);

  // Build page numbers with ellipsis
  const getPageNumbers = () => {
    const pages = [];
    const delta = 1; // neighbours around current
    const range = [];
    for (let i = 1; i <= safeTotalPages; i++) {
      if (i === 1 || i === safeTotalPages || (i >= currentPage - delta && i <= currentPage + delta)) {
        range.push(i);
      }
    }
    let prev = null;
    for (const p of range) {
      if (prev !== null && p - prev > 1) pages.push('ellipsis-' + prev);
      pages.push(p);
      prev = p;
    }
    // Ensure we show at least first 3 and last when many pages but current near start/end
    // If totalPages > 5 and we have gaps, keep ellipsis
    return pages;
  };

  const pageNumbers = getPageNumbers();

  return (
    <div className="pagination pagination--sticky" role="navigation" aria-label="Bladsy navigasie">
      <div className="pagination-info">
        Wys {startItem}-{endItem} van {totalItems}
      </div>
      <div className="pagination-controls">
        <button
          className="pagination-btn pagination-btn--nav"
          disabled={currentPage === 1}
          onClick={() => onPageChange(1)}
          title="Eerste bladsy"
          aria-label="Eerste bladsy"
        >
          «
        </button>
        <button
          className="pagination-btn pagination-btn--nav"
          disabled={currentPage === 1}
          onClick={() => onPageChange(currentPage - 1)}
          aria-label="Vorige bladsy"
        >
          Vorige
        </button>

        {pageNumbers.map((p) => {
          if (typeof p === 'string' && p.startsWith('ellipsis')) {
            return <span key={p} className="pagination-ellipsis">…</span>;
          }
          return (
            <button
              key={p}
              className={`pagination-btn ${p === currentPage ? 'pagination-btn--active' : ''}`}
              onClick={() => onPageChange(p)}
              aria-label={`Bladsy ${p}`}
              aria-current={p === currentPage ? 'page' : undefined}
            >
              {p}
            </button>
          );
        })}

        <button
          className="pagination-btn pagination-btn--nav"
          disabled={currentPage === safeTotalPages}
          onClick={() => onPageChange(currentPage + 1)}
          aria-label="Volgende bladsy"
        >
          Volgende
        </button>
        <button
          className="pagination-btn pagination-btn--nav"
          disabled={currentPage === safeTotalPages}
          onClick={() => onPageChange(safeTotalPages)}
          title="Laaste bladsy"
          aria-label="Laaste bladsy"
        >
          »
        </button>
      </div>
      <div className="pagination-meta">
        Bladsy {currentPage} van {safeTotalPages}
      </div>
    </div>
  );
}
