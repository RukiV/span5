import React from 'react';
import Modal from './Modal';

function AlertDialog({ isOpen, onClose, title = 'Alert', message = '' }) {
  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      size="sm"
      footer={
        <button className="btn-add" onClick={onClose}>OK</button>
      }
    >
      <p style={{ margin: 0, fontSize: '14px', lineHeight: '1.6' }}>{message}</p>
    </Modal>
  );
}

export default AlertDialog;
