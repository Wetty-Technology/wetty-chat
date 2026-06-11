import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import type { AxiosResponse } from 'axios';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { MessageResponse } from '@/api/messages';
import { deleteReaction, putReaction } from '@/api/messages';
import { MAX_REACTIONS_PER_USER_PER_MESSAGE } from '@/constants/emojiAndStickers';
import { useMessageReactions } from './useMessageReactions';

function response<T>(data: T): AxiosResponse<T> {
  return { data } as AxiosResponse<T>;
}

vi.mock('@lingui/core/macro', () => ({
  t: (strings: TemplateStringsArray | string, ...values: unknown[]) => {
    if (typeof strings === 'string') return strings;
    return strings.reduce((result, part, index) => `${result}${part}${values[index] ?? ''}`, '');
  },
}));

vi.mock('@/api/messages', () => ({
  putReaction: vi.fn(),
  deleteReaction: vi.fn(),
}));

const dispatch = vi.fn();
const selectorState = {
  settings: {
    pinnedReactions: ['👍', '❤️'],
    recentReactions: ['❤️', '😂', '🎉'],
  },
};
vi.mock('react-redux', () => ({
  useDispatch: () => dispatch,
  useSelector: (selector: (state: typeof selectorState) => unknown) => selector(selectorState),
}));

interface HookState {
  quickReactionEmojis: string[];
  handleReactionToggle: (message: MessageResponse, emoji: string, currentlyReacted: boolean) => void;
}

function message(reactions: MessageResponse['reactions'] = []): MessageResponse {
  return {
    id: 'message-1',
    clientGeneratedId: 'client-message-1',
    chatId: 'chat-1',
    replyRootId: null,
    message: 'hello',
    messageType: 'text',
    sender: { uid: 2, name: 'User', gender: 0 },
    createdAt: new Date(0).toISOString(),
    isEdited: false,
    isDeleted: false,
    hasAttachments: false,
    reactions,
  };
}

function TestComponent({
  onRender,
  showToast,
}: {
  onRender: (state: HookState) => void;
  showToast: (message: string, duration?: number) => void;
}) {
  const state = useMessageReactions({ chatId: 'chat-1', showToast });
  onRender(state);
  return null;
}

describe('useMessageReactions', () => {
  let host: HTMLDivElement;
  let root: Root;
  let state: HookState;
  let showToast: (message: string, duration?: number) => void;

  function renderHook() {
    act(() => {
      root.render(<TestComponent showToast={showToast} onRender={(nextState) => (state = nextState)} />);
    });
  }

  beforeEach(() => {
    host = document.createElement('div');
    document.body.appendChild(host);
    root = createRoot(host);
    (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
    showToast = vi.fn();
    selectorState.settings.pinnedReactions = ['👍', '❤️'];
    selectorState.settings.recentReactions = ['❤️', '😂', '🎉'];
    vi.mocked(putReaction).mockResolvedValue(response(undefined));
    vi.mocked(deleteReaction).mockResolvedValue(response(undefined));
  });

  afterEach(() => {
    act(() => {
      root.unmount();
    });
    host.remove();
    vi.clearAllMocks();
  });

  it('dedupes pinned and recent quick reactions while preserving order', () => {
    renderHook();

    expect(state.quickReactionEmojis).toEqual(['👍', '❤️', '😂', '🎉']);
  });

  it('optimistically adds a new reaction and records it as recent', () => {
    renderHook();

    act(() => {
      state.handleReactionToggle(message([{ emoji: '👍', count: 1, reactedByMe: false }]), '😂', false);
    });

    expect(putReaction).toHaveBeenCalledWith('chat-1', 'message-1', '😂');
    expect(dispatch).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'settings/addRecentReaction',
        payload: '😂',
      }),
    );
    expect(dispatch).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'messages/reactionsUpdated',
        payload: {
          chatId: 'chat-1',
          messageId: 'message-1',
          reactions: [
            { emoji: '👍', count: 1, reactedByMe: false },
            { emoji: '😂', count: 1, reactedByMe: true },
          ],
        },
      }),
    );
  });

  it('optimistically increments an existing reaction', () => {
    renderHook();

    act(() => {
      state.handleReactionToggle(message([{ emoji: '👍', count: 2, reactedByMe: false }]), '👍', false);
    });

    expect(putReaction).toHaveBeenCalledWith('chat-1', 'message-1', '👍');
    expect(dispatch).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'messages/reactionsUpdated',
        payload: {
          chatId: 'chat-1',
          messageId: 'message-1',
          reactions: [{ emoji: '👍', count: 3, reactedByMe: true }],
        },
      }),
    );
  });

  it('optimistically removes a reaction and filters zero-count entries', () => {
    renderHook();

    act(() => {
      state.handleReactionToggle(message([{ emoji: '👍', count: 1, reactedByMe: true }]), '👍', true);
    });

    expect(deleteReaction).toHaveBeenCalledWith('chat-1', 'message-1', '👍');
    expect(dispatch).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'messages/reactionsUpdated',
        payload: { chatId: 'chat-1', messageId: 'message-1', reactions: [] },
      }),
    );
  });

  it('does not add a reaction when the per-user reaction limit is reached', () => {
    renderHook();

    act(() => {
      state.handleReactionToggle(
        message(
          Array.from({ length: MAX_REACTIONS_PER_USER_PER_MESSAGE }, (_, index) => ({
            emoji: String(index),
            count: 1,
            reactedByMe: true,
          })),
        ),
        '🚀',
        false,
      );
    });

    expect(showToast).toHaveBeenCalledWith(
      `You can only add up to ${MAX_REACTIONS_PER_USER_PER_MESSAGE} reactions`,
      2000,
    );
    expect(putReaction).not.toHaveBeenCalled();
    expect(dispatch).not.toHaveBeenCalledWith(expect.objectContaining({ type: 'messages/reactionsUpdated' }));
  });
});
