/**
 * Current user id for API auth (X-User-Id).
 * Stored in localStorage; defaults to 1 when not set.
 * A settings page will allow changing this later.
 */

const STORAGE_KEY = 'uid';
const DEFAULT_USER_ID = 1;

export function getCurrentUserId(): number {
  if (typeof window === 'undefined') return DEFAULT_USER_ID;
  try {
    const stored = sessionStorage.getItem(STORAGE_KEY);
    if (stored == null || stored === '') return DEFAULT_USER_ID;
    const n = parseInt(stored, 10);
    return Number.isFinite(n) ? n : DEFAULT_USER_ID;
  } catch {
    return DEFAULT_USER_ID;
  }
}

export function setCurrentUserId(uid: number): void {
  if (typeof window === 'undefined') return;
  try {
    sessionStorage.setItem(STORAGE_KEY, String(uid));
  } catch {
    // ignore
  }
}
