import React from 'react';

function DetailSection({ title, children }) {
  return (
    <div style={{ marginBottom: 25 }}>
      <h4 className="detail-section-header">{title}</h4>
      {children}
    </div>
  );
}

export default DetailSection;
