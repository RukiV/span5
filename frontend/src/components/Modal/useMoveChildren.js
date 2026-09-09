import { useState, useCallback, useRef } from 'react';
import MoveChildrenDialog from './MoveChildrenDialog';

// Bestuur 'n MoveChildrenDialog. Gee `openMoveChildren(config)` terug wat 'n
// Promise los: `{ [childId]: newParentId | null }` (null = saam met ouer
// verwyder), of `false` as die gebruiker gekanselleer het.
export function useMoveChildren() {
  const [config, setConfig] = useState(null);
  const resolveRef = useRef(null);

  const openMoveChildren = useCallback((cfg) => {
    return new Promise((resolve) => {
      resolveRef.current = resolve;
      setConfig(cfg);
    });
  }, []);

  const settle = useCallback((value) => {
    resolveRef.current?.(value);
    resolveRef.current = null;
    setConfig(null);
  }, []);

  const dialog = (
    <MoveChildrenDialog
      config={config}
      onClose={() => settle(false)}
      onConfirm={(assignments) => settle(assignments)}
    />
  );

  return { openMoveChildren, moveChildrenDialog: dialog };
}
