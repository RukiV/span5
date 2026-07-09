export const AUTH_ACTIVITY_KEY = 'auth_last_activity';
export const INACTIVITY_TIMEOUT_MS = 15 * 60 * 1000;

export function markUserActivity() {
  try {
    sessionStorage.setItem(AUTH_ACTIVITY_KEY, Date.now().toString());
  } catch (_) {
    // Ignore storage errors and continue gracefully.
  }
}

export function clearAuthSession() {
  try {
    const buildId = localStorage.getItem('active_build_id');
    sessionStorage.clear();
    localStorage.clear();
    if (buildId) {
      localStorage.setItem('active_build_id', buildId);
    }
  } catch (_) {
    // Ignore storage errors and continue gracefully.
  }
}

export function isSessionExpired() {
  const token = sessionStorage.getItem('token');
  if (!token) {
    return false;
  }

  const lastActivity = Number(sessionStorage.getItem(AUTH_ACTIVITY_KEY) || 0);
  if (!lastActivity) {
    markUserActivity();
    return false;
  }

  return Date.now() - lastActivity >= INACTIVITY_TIMEOUT_MS;
}
