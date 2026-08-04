import React, { useState, useEffect } from 'react';
import Modal from './Modal';

function PromptDialog({
  isOpen,
  onClose,
  onConfirm,
  title = 'Input',
  message = '',
  initialValue = '',
  confirmLabel = 'OK',
  cancelLabel = 'Cancel',
}) {
  const [value, setValue] = useState(initialValue);

  useEffect(() => {
    if (isOpen) setValue(initialValue);
  }, [isOpen, initialValue]);

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
            onClick={() => { onConfirm(value); onClose(); }}
            disabled={!value.trim()}
          >
            {confirmLabel}
          </button>
        </>
      }
    >
      {message && <p style={{ margin: '0 0 12px', fontSize: '14px', lineHeight: '1.6' }}>{message}</p>}
      <input
        type="text"
        className="form-input"
        value={value}
        onChange={e => setValue(e.target.value)}
        style={{ width: '100%', padding: '8px 12px', boxSizing: 'border-box' }}
        autoFocus
      />
    </Modal>
  );
}

export default PromptDialog;
