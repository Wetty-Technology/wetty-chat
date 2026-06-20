import { useSyncExternalStore } from 'react';
import { kvDelete, kvGet, kvSet } from '@/utils/db';

// ============================================================
// Adding a new advanced setting:
//   1. Add a property + default to ADVANCED_DEFAULTS
//   2. (Optional) Add a typed getter / hook below
// That's it. Lock resets everything automatically.
// ============================================================

// --- Advanced settings schema ---

// eslint-disable-next-line @typescript-eslint/no-empty-object-type -- populated by future commits
interface AdvancedSettings {}
// --- Pub/Sub ---

type Listener = () => void;
const listeners = new Set<Listener>();

function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function notify(): void {
  for (const l of listeners) l();
}

// --- Single IDB key for all advanced settings ---

const SETTINGS_KEY = 'advanced_settings';
const UNLOCK_KEY = 'advanced_settings_unlocked';

let unlockedCache = false;

// --- Init (call once in bootstrap) ---

export async function initAdvancedSettings(): Promise<void> {
  const [storedUnlock] = await Promise.all([kvGet<boolean>(UNLOCK_KEY), kvGet<AdvancedSettings>(SETTINGS_KEY)]);
  unlockedCache = storedUnlock ?? false;
}

// --- Unlock / Lock ---

function getUnlockedSnapshot(): boolean {
  return unlockedCache;
}

export function isAdvancedSettingsUnlocked(): boolean {
  return unlockedCache;
}

export function unlockAdvancedSettings(): void {
  if (unlockedCache) return;
  unlockedCache = true;
  kvSet(UNLOCK_KEY, true);
  notify();
}

export function lockAdvancedSettings(): void {
  if (!unlockedCache) return;
  unlockedCache = false;
  kvSet(UNLOCK_KEY, false);
  kvDelete(SETTINGS_KEY);
  notify();
}

export function toggleAdvancedSettings(): void {
  if (unlockedCache) {
    lockAdvancedSettings();
  } else {
    unlockAdvancedSettings();
  }
}

export function useAdvancedSettingsUnlocked(): boolean {
  return useSyncExternalStore(subscribe, getUnlockedSnapshot, () => false);
}
