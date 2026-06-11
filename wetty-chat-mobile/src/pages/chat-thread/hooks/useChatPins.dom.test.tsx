import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import type { AxiosResponse } from 'axios';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { PinResponse } from '@/api/pins';
import { listPins } from '@/api/pins';
import { useChatPins } from './useChatPins';

function response<T>(data: T): AxiosResponse<T> {
  return { data } as AxiosResponse<T>;
}

vi.mock('@/api/pins', () => ({
  listPins: vi.fn(),
}));

const dispatch = vi.fn();
const selectorState = {
  pins: {
    byChatId: {} as Record<string, { pins: PinResponse[]; loaded: boolean }>,
    dismissedPinId: {},
  },
};
vi.mock('react-redux', () => ({
  useDispatch: () => dispatch,
  useSelector: (selector: (state: typeof selectorState) => unknown) => selector(selectorState),
}));

interface HookState {
  pins: PinResponse[];
  pinListOpen: boolean;
  openPinList: () => void;
  closePinList: () => void;
}

function TestComponent({
  chatId,
  threadId,
  onRender,
}: {
  chatId: string;
  threadId?: string;
  onRender: (state: HookState) => void;
}) {
  const state = useChatPins({ chatId, threadId });
  onRender(state);
  return null;
}

describe('useChatPins', () => {
  let host: HTMLDivElement;
  let root: Root;
  let state: HookState;

  async function renderHook(threadId?: string) {
    await act(async () => {
      root.render(<TestComponent chatId="chat-1" threadId={threadId} onRender={(nextState) => (state = nextState)} />);
      await Promise.resolve();
    });
  }

  beforeEach(() => {
    host = document.createElement('div');
    document.body.appendChild(host);
    root = createRoot(host);
    (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
    selectorState.pins.byChatId = {};
    vi.mocked(listPins).mockResolvedValue(response({ pins: [] }));
  });

  afterEach(() => {
    act(() => {
      root.unmount();
    });
    host.remove();
    vi.clearAllMocks();
  });

  it('loads pins for main chat and stores them in Redux', async () => {
    await renderHook();

    expect(listPins).toHaveBeenCalledWith('chat-1');
    expect(dispatch).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'pins/setPins',
        payload: { chatId: 'chat-1', pins: [] },
      }),
    );
  });

  it('does not load pins inside a thread', async () => {
    await renderHook('thread-1');

    expect(listPins).not.toHaveBeenCalled();
  });

  it('does not load pins when the chat pins are already loaded', async () => {
    selectorState.pins.byChatId['chat-1'] = { pins: [], loaded: true };

    await renderHook();

    expect(listPins).not.toHaveBeenCalled();
  });

  it('exposes pin list open and close actions', async () => {
    await renderHook();

    act(() => {
      state.openPinList();
    });
    expect(state.pinListOpen).toBe(true);

    act(() => {
      state.closePinList();
    });
    expect(state.pinListOpen).toBe(false);
  });
});
