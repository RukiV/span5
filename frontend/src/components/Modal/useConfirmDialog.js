import { useState, useCallback, useRef } from 'react';
import ConfirmDialog from './ConfirmDialog';

export function useConfirmDialog() {
  const [dialogProps, setDialogProps] = useState(null);
  const resolveRef = useRef(null);

  // `confirm({ title, message, confirmLabel, cancelLabel, variant, cascade,
  //             size, children, actions })`
  //  - Sonder `actions`: los op as `true` (Bevestig) of `false` (Kanselleer) —
  //    terugwaarts-verenigbaar met al die bestaande oproepers.
  //  - Met `actions` (array van { key, label, variant }): los op met die
  //    geklikte aksie se `key`, of `false` op Kanselleer/toemaak.
  const confirm = useCallback(({ title = 'Confirm', message = '', confirmLabel = 'Confirm', cancelLabel = 'Cancel', variant = 'info', cascade = false, size, children, actions } = {}) => {
    return new Promise((resolve) => {
      resolveRef.current = resolve;
      setDialogProps({ title, message, confirmLabel, cancelLabel, variant, cascade, size, children, actions });
    });
  }, []);

  const settle = useCallback((value) => {
    resolveRef.current?.(value);
    resolveRef.current = null;
    setDialogProps(null);
  }, []);

  const handleClose = useCallback(() => settle(false), [settle]);

  const handleConfirm = useCallback(() => settle(true), [settle]);

  const handleAction = useCallback((key) => settle(key), [settle]);

  const { actions } = dialogProps || {};
  const isChooser = Array.isArray(actions) && actions.length > 0;

  const dialog = dialogProps ? (
    <ConfirmDialog
      isOpen={true}
      onClose={handleClose}
      onConfirm={handleConfirm}
      onAction={handleAction}
      title={dialogProps.title}
      message={dialogProps.message}
      confirmLabel={dialogProps.confirmLabel}
      cancelLabel={dialogProps.cancelLabel}
      variant={dialogProps.variant}
      cascade={dialogProps.cascade}
      size={dialogProps.size}
      actions={dialogProps.actions}
      children={dialogProps.children}
    />
  ) : null;

  return { confirm, dialog };
}
