import React from 'react';

function DetailRow({ label, children }) {
  return (
    <div className="detail-row">
      <span className="detail-row-label">{label}</span>
      <span className="detail-row-value">{children || <span className="detail-empty">-</span>}</span>
    </div>
  );
}

export default DetailRow;
