import { useToastContext } from './ToastContext';

export function useToast() {
  const { showToast } = useToastContext();
  return { showToast };
}
