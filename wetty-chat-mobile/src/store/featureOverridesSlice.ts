import { createSlice, current, type PayloadAction } from '@reduxjs/toolkit';
import { FEATURES, type Feature } from '@/features';
import { kvSet } from '@/utils/db';
import type { RootState } from './index';

export interface FeatureOverrideEntry {
  enabled: boolean;
  overrides: Partial<Record<Feature, boolean>>;
}

export interface FeatureOverridesState {
  byUid: Record<string, FeatureOverrideEntry>;
}

const defaultEntry: FeatureOverrideEntry = {
  enabled: false,
  overrides: {},
};

const initialState: FeatureOverridesState = {
  byUid: {},
};

const validFeatures = Object.keys(FEATURES) as Feature[];

function sanitizeEntry(value: unknown): FeatureOverrideEntry {
  const source = (value && typeof value === 'object' ? value : {}) as Partial<FeatureOverrideEntry>;
  const enabled = source.enabled === true;
  const overridesSource = source.overrides;
  const overrides: Partial<Record<Feature, boolean>> = {};
  if (overridesSource && typeof overridesSource === 'object') {
    for (const feature of validFeatures) {
      const raw = (overridesSource as Record<string, unknown>)[feature];
      if (typeof raw === 'boolean') {
        overrides[feature] = raw;
      }
    }
  }
  return { enabled, overrides };
}

export function hydrateFeatureOverrides(saved: unknown): FeatureOverridesState {
  if (!saved || typeof saved !== 'object') {
    return initialState;
  }
  const byUidSource = (saved as { byUid?: unknown }).byUid;
  if (!byUidSource || typeof byUidSource !== 'object') {
    return initialState;
  }

  const byUid: Record<string, FeatureOverrideEntry> = {};
  for (const [uid, value] of Object.entries(byUidSource as Record<string, unknown>)) {
    if (!uid.trim()) continue;
    byUid[uid] = sanitizeEntry(value);
  }

  return { byUid };
}

function persistFeatureOverrides(state: FeatureOverridesState) {
  const snapshot = current(state);
  void kvSet('featureOverrides', snapshot);
}

function ensureEntry(state: FeatureOverridesState, uid: number): FeatureOverrideEntry {
  const key = String(uid);
  if (!state.byUid[key]) {
    state.byUid[key] = { ...defaultEntry };
  }
  return state.byUid[key];
}

const featureOverridesSlice = createSlice({
  name: 'featureOverrides',
  initialState,
  reducers: {
    setDeveloperModeEnabled(state, action: PayloadAction<{ uid: number; enabled: boolean }>) {
      const entry = ensureEntry(state, action.payload.uid);
      entry.enabled = action.payload.enabled;
      persistFeatureOverrides(state);
    },
    setFeatureOverride(state, action: PayloadAction<{ uid: number; feature: Feature; enabled: boolean }>) {
      const entry = ensureEntry(state, action.payload.uid);
      entry.overrides[action.payload.feature] = action.payload.enabled;
      persistFeatureOverrides(state);
    },
    resetFeatureOverrides(state, action: PayloadAction<{ uid: number }>) {
      const entry = ensureEntry(state, action.payload.uid);
      entry.enabled = false;
      entry.overrides = {};
      persistFeatureOverrides(state);
    },
  },
});

export const { setDeveloperModeEnabled, setFeatureOverride, resetFeatureOverrides } = featureOverridesSlice.actions;

export const selectFeatureOverrideEntryByUid = (state: RootState, uid: number | null): FeatureOverrideEntry => {
  if (uid == null) return defaultEntry;
  return state.featureOverrides.byUid[String(uid)] ?? defaultEntry;
};

export default featureOverridesSlice.reducer;
