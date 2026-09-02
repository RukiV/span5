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
  onAction,
  actions,
  children,
  title = 'Confirm',
  message = '',
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  variant = 'info',
  cascade = false,
  size,
}) {
  const style = VARIANT_STYLES[variant] || VARIANT_STYLES.info;

  // As daar aksie-knoppies verskaf word, gebruik daardie in plaas van die
  // standaard Kanselleer/Bevestig-paar. Elke aksie roep onAction(key).
  const footer = actions && actions.length > 0 ? (
    <>
      <button className="btn-cancel" onClick={onClose}>{cancelLabel}</button>
      {actions.map((a) => {
        const aStyle = VARIANT_STYLES[a.variant] || style;
        return (
          <button
            key={a.key}
            className="btn-add"
            style={{ background: aStyle.background, marginLeft: '0.5rem' }}
            onClick={() => { onAction?.(a.key); onClose(); }}
          >
            {a.label}
          </button>
        );
      })}
    </>
  ) : (
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
  );

  const body = children ? children : cascade ? (
    <div>
      <div
        style={{
          border: '2px solid #dc3545',
          borderRadius: '8px',
          padding: '16px',
          background: '#fff5f5',
          margin: 0,
        }}
      >
        <p style={{ margin: '0 0 10px', fontSize: '16px', fontWeight: 700, color: '#b02a37' }}>
          ⚠️ Waarskuwing
        </p>
        <p style={{ margin: 0, fontSize: '15px', lineHeight: '1.6', color: '#842029' }}>
          {message}
        </p>
      </div>
      <p
        style={{
          margin: '14px 0 0',
          fontSize: '13px',
          lineHeight: '1.5',
          color: '#6c757d',
          fontStyle: 'italic',
        }}
      >
        Hierdie aksie kan nie ongedaan gemaak word nie.
      </p>
    </div>
  ) : (
    <p style={{ margin: 0, fontSize: '14px', lineHeight: '1.6' }}>{message}</p>
  );

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      size={size || (cascade ? 'md' : 'sm')}
      footer={footer}
    >
      {body}
    </Modal>
  );
}

export default ConfirmDialog;
