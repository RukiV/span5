import { useState, useCallback, useRef } from 'react';
import ConfirmDialog from './ConfirmDialog';

export function useConfirmDialog() {
  const [dialogProps, setDialogProps] = useState(null);
  const resolveRef = useRef(null);

  const confirm = useCallback(({ title = 'Confirm', message = '', confirmLabel = 'Confirm', cancelLabel = 'Cancel', variant = 'info' } = {}) => {
    return new Promise((resolve) => {
      resolveRef.current = resolve;
      setDialogProps({ title, message, confirmLabel, cancelLabel, variant });
    });
  }, []);

  const handleClose = useCallback(() => {
    resolveRef.current?.(false);
    resolveRef.current = null;
    setDialogProps(null);
  }, []);

  const handleConfirm = useCallback(() => {
    resolveRef.current?.(true);
    resolveRef.current = null;
    setDialogProps(null);
  }, []);

  const dialog = dialogProps ? (
    <ConfirmDialog
      isOpen={true}
      onClose={handleClose}
      onConfirm={handleConfirm}
      title={dialogProps.title}
      message={dialogProps.message}
      confirmLabel={dialogProps.confirmLabel}
      cancelLabel={dialogProps.cancelLabel}
      variant={dialogProps.variant}
    />
  ) : null;

  return { confirm, dialog };
}
