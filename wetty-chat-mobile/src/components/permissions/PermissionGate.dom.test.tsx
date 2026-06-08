import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { Provider } from 'react-redux';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createStore } from '@/store';
import { setUser } from '@/store/userSlice';
import { PermissionGate } from './PermissionGate';

describe('PermissionGate', () => {
  let host: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    host = document.createElement('div');
    document.body.appendChild(host);
    root = createRoot(host);
    (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  });

  afterEach(() => {
    act(() => {
      root.unmount();
    });
    host.remove();
  });

  function renderWithPermissions(permissions: string[]) {
    const store = createStore();
    store.dispatch(
      setUser({
        uid: 1,
        username: 'User',
        avatarUrl: null,
        permissions,
      }),
    );

    act(() => {
      root.render(
        <Provider store={store}>
          <PermissionGate allow="developer.access" fallback={<span>Blocked</span>}>
            <span>Allowed</span>
          </PermissionGate>
        </Provider>,
      );
    });
  }

  it('renders fallback when permission is missing', () => {
    renderWithPermissions([]);
    expect(host.textContent).toContain('Blocked');
    expect(host.textContent).not.toContain('Allowed');
  });

  it('renders children when permission exists', () => {
    renderWithPermissions(['developer.access']);
    expect(host.textContent).toContain('Allowed');
  });

  it('renders children for permission.all users', () => {
    renderWithPermissions(['permission.all']);
    expect(host.textContent).toContain('Allowed');
  });
});
