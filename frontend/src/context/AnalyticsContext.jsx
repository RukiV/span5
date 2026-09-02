import React, { createContext, useContext, useState, useCallback } from 'react';

const AnalyticsContext = createContext(null);

export function AnalyticsProvider({ children }) {
  const [isOpen, setIsOpen] = useState(false);
  const toggle = useCallback(() => setIsOpen(o => !o), []);
  const close = useCallback(() => setIsOpen(false), []);
  return (
    <AnalyticsContext.Provider value={{ isOpen, toggle, close }}>
      {children}
    </AnalyticsContext.Provider>
  );
}

export function useAnalytics() {
  const ctx = useContext(AnalyticsContext);
  if (!ctx) throw new Error('useAnalytics must be used within AnalyticsProvider');
  return ctx;
}
