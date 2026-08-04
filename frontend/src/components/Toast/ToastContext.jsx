import React, { createContext, useContext, useState, useCallback, useRef } from 'react';
import { IoCheckmarkCircle, IoCloseCircle, IoWarning, IoInformation } from 'react-icons/io5';
import './Toast.css';

const ToastContext = createContext(null);

let toastId = 0;

const TYPE_CONFIG = {
  success: { icon: IoCheckmarkCircle },
  error: { icon: IoCloseCircle },
  warning: { icon: IoWarning },
  info: { icon: IoInformation },
};

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const timersRef = useRef({});

  const removeToast = useCallback((id) => {
    setToasts(prev => prev.map(t => t.id === id ? { ...t, exiting: true } : t));
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id));
    }, 250);
    clearTimeout(timersRef.current[id]);
    delete timersRef.current[id];
  }, []);

  const showToast = useCallback(({ type = 'info', title, message, duration = 4000 }) => {
    const id = ++toastId;
    const config = TYPE_CONFIG[type] || TYPE_CONFIG.info;
    const Icon = config.icon;
    setToasts(prev => [...prev, { id, type, title, message, Icon, exiting: false }]);
    if (duration > 0) {
      timersRef.current[id] = setTimeout(() => removeToast(id), duration);
    }
    return id;
  }, [removeToast]);

  return (
    <ToastContext.Provider value={{ showToast, removeToast }}>
      {children}
      <div className="toast-container">
        {toasts.map(t => (
          <div key={t.id} className={`toast-item toast-${t.type}${t.exiting ? ' toast-exiting' : ''}`}>
            <t.Icon className="toast-icon" />
            <div className="toast-content">
              {t.title && <div className="toast-title">{t.title}</div>}
              {t.message && <div className="toast-message">{t.message}</div>}
            </div>
            <button className="toast-close-btn" onClick={() => removeToast(t.id)}>&times;</button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToastContext() {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToastContext must be used within ToastProvider');
  return ctx;
}
