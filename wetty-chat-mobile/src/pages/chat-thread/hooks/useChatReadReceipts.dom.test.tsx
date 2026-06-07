import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, describe, expect, it, vi, type Mock } from 'vitest';
import type { AxiosResponse } from 'axios';
import { READ_REQUEST_COOLDOWN_MS } from '@/constants/chatTiming';
import { useChatReadReceipts } from './useChatReadReceipts';

type HookProps = Parameters<typeof useChatReadReceipts>[0];
type HookApi = NonNullable<HookProps['api']>;

function axiosResponse<T>(data: T): AxiosResponse<T> {
  return {
    data,
    status: 200,
    statusText: 'OK',
    headers: {},
    config: { headers: {} as any },
  };
}

describe('useChatReadReceipts', () => {
  let host: HTMLDivElement;
  let root: Root;
  let dispatch: Mock<(action: any) => unknown>;
  let markChatMessagesAsRead: Mock<HookApi['markChatMessagesAsRead']>;
  let markThreadAsRead: Mock<HookApi['markThreadAsRead']>;
  let syncBadgeCount: Mock<HookApi['syncBadgeCount']>;
  let props: HookProps;

  function Harness() {
    useChatReadReceipts(props);
    return null;
  }

  function renderHook() {
    act(() => {
      root.render(<Harness />);
    });
  }

  async function flushPromises() {
    await act(async () => {
      await Promise.resolve();
    });
  }

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(READ_REQUEST_COOLDOWN_MS);
    host = document.createElement('div');
    document.body.appendChild(host);
    root = createRoot(host);
    (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
    dispatch = vi.fn((action: any) => action);
    markChatMessagesAsRead = vi
      .fn<HookApi['markChatMessagesAsRead']>()
      .mockResolvedValue(axiosResponse({ lastReadMessageId: '10', unreadCount: 2 }));
    markThreadAsRead = vi
      .fn<HookApi['markThreadAsRead']>()
      .mockResolvedValue(axiosResponse({ lastReadMessageId: '20', unreadCount: 1 }));
    syncBadgeCount = vi.fn<HookApi['syncBadgeCount']>().mockResolvedValue(undefined);
    props = {
      chatId: '1',
      storeChatId: '1',
      initialResumeMessageId: '5',
      lastReadMessageId: '4',
      lastFullyVisibleMessageId: '10',
      atBottom: false,
      dispatch,
      api: {
        markChatMessagesAsRead,
        markThreadAsRead,
        syncBadgeCount,
      },
    };
  });

  afterEach(() => {
    act(() => {
      root.unmount();
    });
    host.remove();
    vi.useRealTimers();
  });

  it('marks the visible main-chat target as read and syncs badge count', async () => {
    renderHook();
    await flushPromises();

    expect(markChatMessagesAsRead).toHaveBeenCalledWith('1', '10');
    expect(dispatch).toHaveBeenCalledWith({
      type: 'chats/setChatLastReadMessageId',
      payload: { chatId: '1', lastReadMessageId: '10' },
    });
    expect(dispatch).toHaveBeenCalledWith({
      type: 'chats/setChatUnreadCount',
      payload: { chatId: '1', unreadCount: 2 },
    });
    expect(syncBadgeCount).toHaveBeenCalledTimes(1);
  });

  it('throttles repeated main-chat read requests', async () => {
    renderHook();
    await flushPromises();
    markChatMessagesAsRead.mockResolvedValueOnce(axiosResponse({ lastReadMessageId: '11', unreadCount: 1 }));

    props = { ...props, lastFullyVisibleMessageId: '11' };
    renderHook();

    expect(markChatMessagesAsRead).toHaveBeenCalledTimes(1);

    await act(async () => {
      vi.advanceTimersByTime(READ_REQUEST_COOLDOWN_MS);
    });
    await flushPromises();

    expect(markChatMessagesAsRead).toHaveBeenCalledTimes(2);
    expect(markChatMessagesAsRead).toHaveBeenLastCalledWith('1', '11');
  });

  it('marks thread messages as read after the cooldown', async () => {
    props = {
      ...props,
      threadId: '20',
      storeChatId: '1_thread_20',
      lastFullyVisibleMessageId: '25',
    };

    renderHook();
    expect(markThreadAsRead).not.toHaveBeenCalled();

    await act(async () => {
      vi.advanceTimersByTime(READ_REQUEST_COOLDOWN_MS);
    });
    await flushPromises();

    expect(markThreadAsRead).toHaveBeenCalledWith('20', '25');
    expect(dispatch).toHaveBeenCalledWith({
      type: 'threads/setThreadReadState',
      payload: { threadRootId: '20', lastReadMessageId: '20', unreadCount: 1 },
    });
  });
});
