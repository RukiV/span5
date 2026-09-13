import React from 'react';

function LocationBreadcrumb({ parts }) {
  const filtered = parts.filter(Boolean);
  if (filtered.length === 0) return <span className="detail-empty">Nie toegewys nie</span>;

  return (
    <div className="detail-location-bar">
      {filtered.map((part, i) => (
        <React.Fragment key={i}>
          {i > 0 && <span className="detail-location-separator">›</span>}
          <span className="detail-location-text">{part}</span>
        </React.Fragment>
      ))}
    </div>
  );
}

export default LocationBreadcrumb;
