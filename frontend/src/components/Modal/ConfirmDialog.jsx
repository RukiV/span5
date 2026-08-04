import React from 'react';
import Modal from './Modal';

const VARIANT_STYLES = {
  danger: { background: '#dc3545', hover: '#c82333' },
  warning: { background: '#e0a800', hover: '#c99700' },
  info: { background: '#2a5f9e', hover: '#0e1e3b' },
};

function ConfirmDialog({
  isOpen,
  onClose,
  onConfirm,
  title = 'Confirm',
  message = '',
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  variant = 'info',
}) {
  const style = VARIANT_STYLES[variant] || VARIANT_STYLES.info;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      size="sm"
      footer={
        <>
          <button className="btn-cancel" onClick={onClose}>{cancelLabel}</button>
          <button
            className="btn-add"
            style={{ background: style.background }}
            onClick={() => { onConfirm(); onClose(); }}
          >
            {confirmLabel}
          </button>
        </>
      }
    >
      <p style={{ margin: 0, fontSize: '14px', lineHeight: '1.6' }}>{message}</p>
    </Modal>
  );
}

export default ConfirmDialog;
