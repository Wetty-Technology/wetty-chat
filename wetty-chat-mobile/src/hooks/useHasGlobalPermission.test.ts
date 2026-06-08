import { describe, expect, it } from 'vitest';
import { hasGlobalPermission } from './useHasGlobalPermission';

describe('hasGlobalPermission', () => {
  it('returns true when explicit permission exists', () => {
    expect(hasGlobalPermission(['developer.access'], 'developer.access')).toBe(true);
  });

  it('returns false when permission is missing', () => {
    expect(hasGlobalPermission(['chat.create'], 'developer.access')).toBe(false);
  });

  it('returns true when permission.all exists', () => {
    expect(hasGlobalPermission(['permission.all'], 'developer.access')).toBe(true);
  });

  it('supports arrays of allowed permissions', () => {
    expect(hasGlobalPermission(['invite.create'], ['developer.access', 'invite.create'])).toBe(true);
  });
});
