import React from 'react';

function DetailCard({ children, style }) {
  return (
    <div className="detail-card" style={style}>
      {children}
    </div>
  );
}

export default DetailCard;
