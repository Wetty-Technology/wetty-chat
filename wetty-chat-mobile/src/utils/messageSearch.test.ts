import { describe, expect, it } from 'vitest';
import { isMessageSearchQueryReady } from './messageSearch';

describe('message search helpers', () => {
  it('requires at least two trimmed characters before searching', () => {
    expect(isMessageSearchQueryReady('')).toBe(false);
    expect(isMessageSearchQueryReady('  a ')).toBe(false);
    expect(isMessageSearchQueryReady('你')).toBe(false);
    expect(isMessageSearchQueryReady('你好')).toBe(true);
    expect(isMessageSearchQueryReady(' hi ')).toBe(true);
  });
});
