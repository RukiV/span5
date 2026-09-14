import { isSessionExpired, markUserActivity, clearAuthSession, INACTIVITY_TIMEOUT_MS } from '../authSession';

beforeEach(() => {
  sessionStorage.clear();
  localStorage.clear();
});

test('markUserActivity stores timestamp', () => {
  markUserActivity();
  const stored = sessionStorage.getItem('auth_last_activity');
  expect(stored).toBeTruthy();
  expect(Number(stored)).toBeGreaterThan(0);
});

test('isSessionExpired returns false when no token', () => {
  expect(isSessionExpired()).toBe(false);
});

test('isSessionExpired returns false when recent activity', () => {
  sessionStorage.setItem('token', 'abc123');
  markUserActivity();
  expect(isSessionExpired()).toBe(false);
});

test('isSessionExpired returns true after inactivity timeout', () => {
  sessionStorage.setItem('token', 'abc123');
  const oldTime = Date.now() - INACTIVITY_TIMEOUT_MS - 1000;
  sessionStorage.setItem('auth_last_activity', String(oldTime));
  expect(isSessionExpired()).toBe(true);
});

test('clearAuthSession clears storage but preserves build ID', () => {
  sessionStorage.setItem('token', 'abc123');
  localStorage.setItem('active_build_id', 'build-42');
  clearAuthSession();
  expect(sessionStorage.getItem('token')).toBeNull();
  expect(localStorage.getItem('active_build_id')).toBe('build-42');
});
