import React, { useCallback } from 'react';
import '../styles/DragHandle.css';

const MIN_PCT = 25;
const MAX_PCT = 50;

function DragHandle() {
  const handleMouseDown = useCallback((e) => {
    e.preventDefault();
    const startX = e.clientX;
    const startPct = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--analytics-width').trim()) || 33.33;

    const onMouseMove = (ev) => {
      const container = document.querySelector('.app-content');
      if (!container) return;
      const rect = container.getBoundingClientRect();
      const contentWidth = rect.width;
      if (contentWidth <= 0) return;
      const delta = startX - ev.clientX;
      const deltaPct = (delta / contentWidth) * 100;
      let newPct = startPct + deltaPct;
      newPct = Math.min(MAX_PCT, Math.max(MIN_PCT, newPct));
      document.documentElement.style.setProperty('--analytics-width', `${newPct}%`);
    };

    const onMouseUp = () => {
      document.removeEventListener('mousemove', onMouseMove);
      document.removeEventListener('mouseup', onMouseUp);
    };

    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
  }, []);

  return <div className="drag-handle" onMouseDown={handleMouseDown} />;
}

export default DragHandle;
