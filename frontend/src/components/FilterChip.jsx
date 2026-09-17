import React from 'react';

/**
 * FilterChip - Wegwerpbare aktiewe-URL-filter kapsule (Afrikaans UI).
 * Toon 'n aktiewe filter met 'n skoonmaak (×) knoppie wat die URL-parameter verwyder.
 */
const FilterChip = ({ label, onClear }) => (
  <span
    className="filter-chip"
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      background: '#fef3c7',
      border: '1px solid #f59e0b',
      color: '#92400e',
      padding: '4px 10px',
      borderRadius: '999px',
      fontSize: '12px',
      fontWeight: 600,
    }}
  >
    {label}
    <button
      type="button"
      onClick={onClear}
      aria-label="Verwyder filter"
      style={{
        background: 'none',
        border: 'none',
        cursor: 'pointer',
        fontWeight: 'bold',
        color: '#92400e',
        fontSize: '14px',
        lineHeight: 1,
        padding: 0,
        marginLeft: '2px',
      }}
    >
      ×
    </button>
  </span>
);

export default FilterChip;