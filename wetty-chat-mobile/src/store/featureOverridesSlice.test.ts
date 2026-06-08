import { describe, expect, it, vi } from 'vitest';
vi.mock('@/utils/db', () => ({
  kvSet: vi.fn(),
}));
import reducer, {
  hydrateFeatureOverrides,
  resetFeatureOverrides,
  setDeveloperModeEnabled,
  setFeatureOverride,
  type FeatureOverridesState,
} from './featureOverridesSlice';

describe('featureOverridesSlice', () => {
  it('stores per-user developer mode and overrides', () => {
    const baseState: FeatureOverridesState = { byUid: {} };
    const withDeveloperMode = reducer(baseState, setDeveloperModeEnabled({ uid: 7, enabled: true }));
    const withFeatureOverride = reducer(
      withDeveloperMode,
      setFeatureOverride({ uid: 7, feature: 'developerSettings', enabled: true }),
    );

    expect(withFeatureOverride.byUid['7']?.enabled).toBe(true);
    expect(withFeatureOverride.byUid['7']?.overrides.developerSettings).toBe(true);
  });

  it('resets only the targeted user overrides', () => {
    const state: FeatureOverridesState = {
      byUid: {
        '7': { enabled: true, overrides: { developerSettings: true } },
        '8': { enabled: true, overrides: { developerSettings: false } },
      },
    };

    const nextState = reducer(state, resetFeatureOverrides({ uid: 7 }));
    expect(nextState.byUid['7']).toEqual({ enabled: false, overrides: {} });
    expect(nextState.byUid['8']).toEqual({ enabled: true, overrides: { developerSettings: false } });
  });

  it('sanitizes persisted data during hydration', () => {
    const hydrated = hydrateFeatureOverrides({
      byUid: {
        '7': {
          enabled: true,
          overrides: {
            developerSettings: true,
            unknownFeature: true,
          },
        },
      },
    });

    expect(hydrated.byUid['7']?.overrides.developerSettings).toBe(true);
    expect((hydrated.byUid['7']?.overrides as Record<string, unknown>).unknownFeature).toBeUndefined();
  });
});
