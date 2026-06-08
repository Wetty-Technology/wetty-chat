import { describe, expect, it } from 'vitest';
import reducer, { fetchCurrentUser, setUser, type UserState } from './userSlice';

describe('userSlice', () => {
  const baseState: UserState = {
    uid: null,
    username: null,
    avatarUrl: null,
    permissions: [],
    loading: true,
    error: null,
  };

  it('stores permissions from setUser', () => {
    const nextState = reducer(
      baseState,
      setUser({
        uid: 10,
        username: 'dev',
        avatarUrl: null,
        permissions: ['developer.access'],
      }),
    );

    expect(nextState.permissions).toEqual(['developer.access']);
  });

  it('stores permissions from fetchCurrentUser.fulfilled', () => {
    const nextState = reducer(
      baseState,
      fetchCurrentUser.fulfilled(
        {
          uid: 10,
          username: 'dev',
          avatarUrl: null,
          gender: 0,
          stickerPackOrder: [],
          permissions: ['developer.access'],
        },
        'req-1',
      ),
    );

    expect(nextState.loading).toBe(false);
    expect(nextState.permissions).toEqual(['developer.access']);
  });

  it('clears permissions on fetchCurrentUser.rejected', () => {
    const state: UserState = {
      ...baseState,
      permissions: ['developer.access'],
      loading: true,
    };
    const nextState = reducer(state, fetchCurrentUser.rejected(new Error('boom'), 'req-2', undefined, 'boom'));

    expect(nextState.loading).toBe(false);
    expect(nextState.permissions).toEqual([]);
  });
});
