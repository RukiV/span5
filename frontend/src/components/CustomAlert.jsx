import React from "react";

function CustomAlert({ show, title, message, onClose }) {
  if (!show) return null;

  return (
    <div className="modal" onClick={onClose}>
      <div className="modal-content" style={{ width: "450px" }} onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h3>{title}</h3>
          <span className="close" onClick={onClose}>&times;</span>
        </div>
        <div style={{ padding: "20px", fontSize: "14px", lineHeight: "1.6" }}>
          {message}
        </div>
        <div className="modal-footer">
          <button className="btn-add" onClick={onClose}>OK</button>
        </div>
      </div>
    </div>
  );
}

export default CustomAlert;
