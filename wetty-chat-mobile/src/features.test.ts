import { afterEach, describe, expect, it, vi } from 'vitest';

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('feature gates', () => {
  it('keeps demoPage behind an explicit gate by default', async () => {
    vi.stubGlobal('__FEATURE_GATES_ENABLED__', false);
    const { FEATURES, isFeatureEnabled } = await import('./features');

    expect(FEATURES.demoPage.enabled).toBe(false);
    expect(isFeatureEnabled('demoPage')).toBe(false);
  });

  it('keeps savedMessages controlled by an explicit feature gate', async () => {
    vi.stubGlobal('__FEATURE_GATES_ENABLED__', false);
    const { FEATURES, isFeatureEnabled } = await import('./features');

    expect(FEATURES.savedMessages.enabled).toBe(true);
    expect(isFeatureEnabled('savedMessages')).toBe(true);
  });

  it('applies runtime overrides when active', async () => {
    vi.stubGlobal('__FEATURE_GATES_ENABLED__', false);
    const { applyFeatureOverrides, isFeatureEnabled } = await import('./features');

    applyFeatureOverrides(true, { developerSettings: true, savedMessages: false });
    expect(isFeatureEnabled('developerSettings')).toBe(true);
    expect(isFeatureEnabled('savedMessages')).toBe(false);

    applyFeatureOverrides(false, {});
  });

  it('ignores runtime overrides when inactive', async () => {
    vi.stubGlobal('__FEATURE_GATES_ENABLED__', false);
    const { FEATURES, applyFeatureOverrides, isFeatureEnabled } = await import('./features');

    applyFeatureOverrides(false, { developerSettings: true });
    expect(isFeatureEnabled('developerSettings')).toBe(FEATURES.developerSettings.enabled);

    applyFeatureOverrides(false, {});
  });
});
