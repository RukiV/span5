import React, { useEffect, useCallback, useRef } from 'react';
import './Modal.css';

const SIZE_MAP = {
  sm: '400px',
  md: '600px',
  lg: '900px',
  xl: '1140px',
};

function Modal({
  isOpen,
  onClose,
  title,
  children,
  footer,
  size = 'md',
  closeOnBackdrop = true,
  closeOnEsc = true,
  showCloseButton = true,
}) {
  const panelRef = useRef(null);

  const handleBackdropClick = useCallback((e) => {
    if (closeOnBackdrop && e.target === e.currentTarget) {
      onClose();
    }
  }, [closeOnBackdrop, onClose]);

  useEffect(() => {
    if (!closeOnEsc || !isOpen) return;
    const handler = (e) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [closeOnEsc, isOpen, onClose]);

  useEffect(() => {
    if (!isOpen) return;
    const focused = document.activeElement;
    panelRef.current?.focus();
    return () => focused?.focus();
  }, [isOpen]);

  if (!isOpen) return null;

  const width = SIZE_MAP[size] || SIZE_MAP.md;

  return (
    <div className="modal-overlay" onClick={handleBackdropClick}>
      <div
        className="modal-panel"
        style={{ maxWidth: width }}
        ref={panelRef}
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-label={title}
      >
        <div className="modal-panel-header">
          <h3>{title}</h3>
          {showCloseButton && (
            <span className="modal-close" onClick={onClose}>&times;</span>
          )}
        </div>
        <div className="modal-panel-body">
          {children}
        </div>
        {footer && (
          <div className="modal-panel-footer">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}

export default Modal;
