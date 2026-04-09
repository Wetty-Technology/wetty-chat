import { createSelector, createSlice } from '@reduxjs/toolkit';
import type { MessageResponse } from '@/api/messages';
import { messageAdded, messageConfirmed, messagePatched, messagesBulkDeleted, reactionsUpdated } from './messageEvents';
import { compareMessageOrder } from './messageProjection';

const MAX_WINDOWS = 5;

export interface MessageWindow {
  messages: MessageResponse[];
  nextCursor: string | null; // cursor to load older messages (top)
  prevCursor: string | null; // cursor to load newer messages (bottom)
}

export interface ChatMessageState {
  windows: MessageWindow[];
  activeWindowIndex: number;
  generation: number;
}

export interface MessagesState {
  chats: Record<string, ChatMessageState>;
}

const initialState: MessagesState = {
  chats: {},
};

function dedup(existing: MessageResponse[], incoming: MessageResponse[]): MessageResponse[] {
  return incoming.filter(
    (incomingMessage) => !existing.some((current) => isSameLogicalMessage(current, incomingMessage)),
  );
}

function isOptimisticMessage(message: MessageResponse): boolean {
  return message.id.startsWith('cg_');
}

function isSameLogicalMessage(
  left: MessageResponse,
  right: Pick<MessageResponse, 'id' | 'clientGeneratedId'>,
  fallbackClientGeneratedId?: string,
): boolean {
  if (left.id === right.id) return true;

  const rightClientGeneratedId = right.clientGeneratedId || fallbackClientGeneratedId;
  return !!left.clientGeneratedId && !!rightClientGeneratedId && left.clientGeneratedId === rightClientGeneratedId;
}

function insertMessageSorted(messages: MessageResponse[], message: MessageResponse): MessageResponse[] {
  const next = [...messages];
  const insertAt = next.findIndex((current) => compareMessageOrder(message, current) < 0);
  if (insertAt === -1) {
    next.push(message);
  } else {
    next.splice(insertAt, 0, message);
  }
  return next;
}

function hasLogicalMessage(
  chat: ChatMessageState,
  message: Pick<MessageResponse, 'id' | 'clientGeneratedId'>,
): boolean {
  return chat.windows.some((window) => window.messages.some((current) => isSameLogicalMessage(current, message)));
}

function getChat(state: MessagesState, chatId: string): ChatMessageState {
  if (!state.chats[chatId]) {
    state.chats[chatId] = { windows: [], activeWindowIndex: 0, generation: 0 };
  }
  return state.chats[chatId];
}

function getActiveWindow(chat: ChatMessageState): MessageWindow | undefined {
  return chat.windows[chat.activeWindowIndex];
}

function addMessageToWindow(state: MessagesState, chatId: string, message: MessageResponse): void {
  const chat = getChat(state, chatId);
  if (chat.windows.length === 0) {
    chat.windows.push({ messages: [], nextCursor: null, prevCursor: null });
    chat.activeWindowIndex = 0;
  }
  if (hasLogicalMessage(chat, message)) {
    console.debug('[msg-trace] addMessageToWindow:dedup', {
      chatId,
      msgId: message.id,
      cgId: message.clientGeneratedId ?? null,
    });
    return;
  }
  const lastWinIdx = chat.windows.length - 1;
  const lastWin = chat.windows[lastWinIdx];
  lastWin.messages = insertMessageSorted(lastWin.messages, message);
  console.debug('[msg-trace] addMessageToWindow', {
    chatId,
    msgId: message.id,
    cgId: message.clientGeneratedId ?? null,
    targetWin: lastWinIdx,
    activeWin: chat.activeWindowIndex,
    mismatch: lastWinIdx !== chat.activeWindowIndex,
    winCount: chat.windows.length,
    winMsgCounts: chat.windows.map((w) => w.messages.length),
  });
}

function confirmPendingInWindows(
  state: MessagesState,
  chatId: string,
  clientGeneratedId: string,
  message: MessageResponse,
): void {
  const chat = getChat(state, chatId);
  if (chat.windows.length === 0) {
    chat.windows.push({ messages: [], nextCursor: null, prevCursor: null });
    chat.activeWindowIndex = 0;
  }

  const resolvedMessage = {
    ...message,
    clientGeneratedId: message.clientGeneratedId || clientGeneratedId,
  };

  let targetWindowIndex = chat.windows.length - 1;
  for (let i = 0; i < chat.windows.length; i++) {
    if (chat.windows[i].messages.some((current) => isSameLogicalMessage(current, resolvedMessage, clientGeneratedId))) {
      targetWindowIndex = i;
      break;
    }
  }

  const removedCounts = chat.windows.map((win) => {
    const before = win.messages.length;
    win.messages = win.messages.filter((current) => !isSameLogicalMessage(current, resolvedMessage, clientGeneratedId));
    return before - win.messages.length;
  });

  chat.windows[targetWindowIndex].messages = insertMessageSorted(
    chat.windows[targetWindowIndex].messages,
    resolvedMessage,
  );

  console.debug('[msg-trace] confirmPendingInWindows', {
    chatId,
    cgId: clientGeneratedId,
    confirmedId: message.id,
    targetWin: targetWindowIndex,
    activeWin: chat.activeWindowIndex,
    mismatch: targetWindowIndex !== chat.activeWindowIndex,
    removedPerWin: removedCounts,
  });
}

function patchMessageInWindows(
  state: MessagesState,
  baseChatId: string,
  messageId: string,
  message: MessageResponse,
): void {
  for (const [chatId, chat] of Object.entries(state.chats)) {
    if (chatId !== baseChatId && !chatId.startsWith(`${baseChatId}_thread_`)) continue;

    for (const win of chat.windows) {
      if (message.isDeleted) {
        win.messages = win.messages.filter((m) => m.id !== messageId);
      }

      for (let i = 0; i < win.messages.length; i++) {
        const current = win.messages[i];
        if (!message.isDeleted && current.id === messageId) {
          const preservedReplyTo =
            message.replyToMessage ??
            (message.replyToMessage === undefined && current.replyToMessage !== undefined
              ? current.replyToMessage
              : undefined);
          win.messages[i] = {
            ...current,
            ...message,
            replyToMessage: preservedReplyTo,
            reactions: message.reactions ?? current.reactions,
            threadInfo: message.threadInfo ?? current.threadInfo,
          };
        } else if (current.replyToMessage?.id === messageId) {
          current.replyToMessage.message = message.message;
          current.replyToMessage.messageType = message.messageType;
          current.replyToMessage.sticker = message.sticker;
          current.replyToMessage.isDeleted = message.isDeleted;
          current.replyToMessage.attachments = message.attachments;
          current.replyToMessage.firstAttachmentKind = message.attachments?.[0]?.kind;
          current.replyToMessage.mentions = message.mentions;
        }
      }
    }
  }
}

const messagesSlice = createSlice({
  name: 'messages',
  initialState,
  reducers: {
    resetChat(
      state,
      action: {
        payload: { chatId: string; messages: MessageResponse[]; nextCursor: string | null; prevCursor: string | null };
      },
    ) {
      const { chatId, messages, nextCursor, prevCursor } = action.payload;
      const prevGen = state.chats[chatId]?.generation ?? 0;
      state.chats[chatId] = {
        windows: [{ messages, nextCursor, prevCursor }],
        activeWindowIndex: 0,
        generation: prevGen + 1,
      };
    },

    pushWindow(
      state,
      action: {
        payload: { chatId: string; messages: MessageResponse[]; nextCursor: string | null; prevCursor: string | null };
      },
    ) {
      const { chatId, messages, nextCursor, prevCursor } = action.payload;
      const chat = getChat(state, chatId);
      const newWin: MessageWindow = { messages, nextCursor, prevCursor };

      // Insert in chronological order so the last window is always the most recent
      const newTs = messages.length > 0 ? messages[0].createdAt : '';
      let insertIdx = chat.windows.length;
      for (let i = 0; i < chat.windows.length; i++) {
        const winTs = chat.windows[i].messages[0]?.createdAt ?? '';
        if (newTs < winTs) {
          insertIdx = i;
          break;
        }
      }
      chat.windows.splice(insertIdx, 0, newWin);
      chat.activeWindowIndex = insertIdx;
      chat.generation++;

      // Cap at MAX_WINDOWS: evict oldest non-active
      while (chat.windows.length > MAX_WINDOWS) {
        const evictIdx = chat.windows.findIndex((_, i) => i !== chat.activeWindowIndex);
        if (evictIdx === -1) break;
        chat.windows.splice(evictIdx, 1);
        if (chat.activeWindowIndex > evictIdx) chat.activeWindowIndex--;
      }
    },

    prependMessages(
      state,
      action: { payload: { chatId: string; messages: MessageResponse[]; nextCursor?: string | null } },
    ) {
      const { chatId, messages } = action.payload;
      const chat = getChat(state, chatId);
      const win = getActiveWindow(chat);
      if (!win) return;
      const unique = dedup(win.messages, messages);
      win.messages = [...unique, ...win.messages];
      win.messages.sort(compareMessageOrder);
      if (action.payload.nextCursor !== undefined) {
        win.nextCursor = action.payload.nextCursor;
      }
    },

    appendMessages(
      state,
      action: { payload: { chatId: string; messages: MessageResponse[]; prevCursor?: string | null } },
    ) {
      const { chatId, messages } = action.payload;
      const chat = getChat(state, chatId);
      const win = getActiveWindow(chat);
      if (!win) return;
      const unique = dedup(win.messages, messages);
      win.messages = [...win.messages, ...unique];
      if (action.payload.prevCursor !== undefined) {
        win.prevCursor = action.payload.prevCursor;
      }
      // Merge with next window if gap closed
      if (win.prevCursor === null && chat.activeWindowIndex < chat.windows.length - 1) {
        const nextWin = chat.windows[chat.activeWindowIndex + 1];
        const merged = dedup(win.messages, nextWin.messages);
        win.messages = [...win.messages, ...merged];
        win.messages.sort(compareMessageOrder);
        win.prevCursor = nextWin.prevCursor;
        chat.windows.splice(chat.activeWindowIndex + 1, 1);
      }
    },

    // Backwards compat aliases
    setMessagesForChat(state, action: { payload: { chatId: string; messages: MessageResponse[] } }) {
      const { chatId, messages } = action.payload;
      // Used for error recovery / removing messages - reset to single window preserving no cursors
      const chat = state.chats[chatId];
      if (chat && chat.windows.length > 0) {
        const win = getActiveWindow(chat);
        if (win) {
          win.messages = messages;
          return;
        }
      }
      state.chats[chatId] = {
        windows: [{ messages, nextCursor: null, prevCursor: null }],
        activeWindowIndex: 0,
        generation: 0,
      };
    },

    setNextCursorForChat(state, action: { payload: { chatId: string; cursor: string | null } }) {
      const { chatId, cursor } = action.payload;
      const chat = getChat(state, chatId);
      const win = getActiveWindow(chat);
      if (win) win.nextCursor = cursor;
    },

    setPrevCursorForChat(state, action: { payload: { chatId: string; cursor: string | null } }) {
      const { chatId, cursor } = action.payload;
      const chat = getChat(state, chatId);
      const win = getActiveWindow(chat);
      if (win) win.prevCursor = cursor;
    },

    activateLatestWindow(state, action: { payload: { chatId: string } }) {
      const chat = state.chats[action.payload.chatId];
      if (chat && chat.windows.length > 0 && chat.activeWindowIndex !== chat.windows.length - 1) {
        const from = chat.activeWindowIndex;
        chat.activeWindowIndex = chat.windows.length - 1;
        chat.generation++;
        console.debug('[msg-trace] activateLatestWindow', {
          chatId: action.payload.chatId,
          from,
          to: chat.activeWindowIndex,
          winCount: chat.windows.length,
          winMsgCounts: chat.windows.map((w) => w.messages.length),
        });
      }
    },

    refreshLatest(
      state,
      action: {
        payload: { chatId: string; messages: MessageResponse[]; nextCursor: string | null; prevCursor: string | null };
      },
    ) {
      const { chatId, messages, nextCursor, prevCursor } = action.payload;
      const chat = state.chats[chatId];

      if (!chat || chat.windows.length === 0) {
        // No existing data — full reset
        const prevGen = chat?.generation ?? 0;
        state.chats[chatId] = {
          windows: [{ messages, nextCursor, prevCursor }],
          activeWindowIndex: 0,
          generation: prevGen + 1,
        };
        return;
      }

      // Check the last window (most recent chronologically) for overlap
      const lastWinIdx = chat.windows.length - 1;
      const lastWin = chat.windows[lastWinIdx];
      const fetchedIds = new Set(messages.map((m) => m.id));
      const fetchedClientGeneratedIds = new Set(messages.map((m) => m.clientGeneratedId).filter(Boolean));
      const hasOverlap = lastWin.messages.some((m) => fetchedIds.has(m.id));
      const pendingOptimistic = lastWin.messages.filter((message) => isOptimisticMessage(message));

      if (hasOverlap || pendingOptimistic.length > 0) {
        // Preserve still-pending optimistic rows during latest-window refreshes so
        // API confirm / websocket echo can reconcile them later.
        const unmatchedExisting = lastWin.messages.filter((current) => {
          if (isOptimisticMessage(current)) return false;
          if (fetchedIds.has(current.id)) return false;
          return !current.clientGeneratedId || !fetchedClientGeneratedIds.has(current.clientGeneratedId);
        });

        let nextMessages = [...unmatchedExisting, ...messages];
        for (const optimistic of pendingOptimistic) {
          if (nextMessages.some((current) => isSameLogicalMessage(current, optimistic))) continue;
          nextMessages = insertMessageSorted(nextMessages, optimistic);
        }

        lastWin.messages = nextMessages;
        if (!hasOverlap) {
          lastWin.nextCursor = nextCursor;
        }
        // Preserve nextCursor from existing window (allows loading older),
        // use prevCursor from API response
        lastWin.prevCursor = prevCursor;
        chat.activeWindowIndex = lastWinIdx;
        console.debug('[msg-trace] refreshLatest:merge', {
          chatId,
          hasOverlap,
          optimisticCount: pendingOptimistic.length,
          optimisticIds: pendingOptimistic.map((m) => m.id),
          unmatchedCount: unmatchedExisting.length,
          fetchedCount: messages.length,
          finalCount: nextMessages.length,
          activeWin: lastWinIdx,
        });
      } else {
        // No overlap — stale data, full reset
        console.debug('[msg-trace] refreshLatest:reset', {
          chatId,
          existingMsgCount: lastWin.messages.length,
          existingIds: lastWin.messages.slice(-3).map((m) => m.id),
          fetchedCount: messages.length,
          fetchedIds: messages.slice(-3).map((m) => m.id),
        });
        chat.windows = [{ messages, nextCursor, prevCursor }];
        chat.activeWindowIndex = 0;
      }
      chat.generation++;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(messageAdded, (state, action) => {
        addMessageToWindow(state, action.payload.storeChatId, action.payload.message);
      })
      .addCase(messageConfirmed, (state, action) => {
        confirmPendingInWindows(
          state,
          action.payload.storeChatId,
          action.payload.clientGeneratedId,
          action.payload.message,
        );
      })
      .addCase(messagePatched, (state, action) => {
        patchMessageInWindows(state, action.payload.chatId, action.payload.messageId, action.payload.message);
      })
      .addCase(messagesBulkDeleted, (state, action) => {
        const { chatId, messageIds } = action.payload;
        const idSet = new Set(messageIds);

        for (const [storeKey, chat] of Object.entries(state.chats)) {
          if (storeKey !== chatId && !storeKey.startsWith(`${chatId}_thread_`)) continue;

          for (const win of chat.windows) {
            win.messages = win.messages.filter((m) => !idSet.has(m.id));

            // Mark replyToMessage references as deleted
            for (const msg of win.messages) {
              if (msg.replyToMessage && idSet.has(msg.replyToMessage.id)) {
                msg.replyToMessage.isDeleted = true;
                msg.replyToMessage.message = null;
                msg.replyToMessage.attachments = [];
              }
            }
          }

          chat.generation += 1;
        }
      })
      .addCase(reactionsUpdated, (state, action) => {
        const { chatId, messageId, reactions } = action.payload;
        for (const [storeKey, chat] of Object.entries(state.chats)) {
          if (storeKey !== chatId && !storeKey.startsWith(`${chatId}_thread_`)) continue;
          for (const win of chat.windows) {
            for (let i = 0; i < win.messages.length; i++) {
              if (win.messages[i].id === messageId) {
                const existing = win.messages[i].reactions ?? [];
                const merged = reactions.map((r) => {
                  const prev = existing.find((e) => e.emoji === r.emoji);
                  return { ...r, reactedByMe: r.reactedByMe ?? prev?.reactedByMe };
                });
                win.messages[i] = { ...win.messages[i], reactions: merged };
              }
            }
          }
        }
      });
  },
});

export const {
  resetChat,
  pushWindow,
  setMessagesForChat,
  setNextCursorForChat,
  setPrevCursorForChat,
  activateLatestWindow,
  appendMessages,
  prependMessages,
  refreshLatest,
} = messagesSlice.actions;

/** Selectors */
const EMPTY_ARRAY: MessageResponse[] = [];

const selectMessagesChats = (state: { messages: MessagesState }) => state.messages.chats;

export const selectMessagesForChat = createSelector(
  [selectMessagesChats, (_state: { messages: MessagesState }, chatId: string) => chatId],
  (chats, chatId): MessageResponse[] => {
    const chat = chats[chatId];
    if (!chat || chat.windows.length === 0) return EMPTY_ARRAY;
    return chat.windows[chat.activeWindowIndex]?.messages ?? EMPTY_ARRAY;
  },
);

export function selectNextCursorForChat(state: { messages: MessagesState }, chatId: string): string | null {
  const chat = state.messages.chats[chatId];
  if (!chat || chat.windows.length === 0) return null;
  return chat.windows[chat.activeWindowIndex]?.nextCursor ?? null;
}

export function selectChatGeneration(state: { messages: MessagesState }, chatId: string): number {
  return state.messages.chats[chatId]?.generation ?? 0;
}

export function selectPrevCursorForChat(state: { messages: MessagesState }, chatId: string): string | null {
  const chat = state.messages.chats[chatId];
  if (!chat || chat.windows.length === 0) return null;
  return chat.windows[chat.activeWindowIndex]?.prevCursor ?? null;
}

/**
 * Find the latest non-deleted message in a thread's windows.
 * Returns null if no window exists for this thread (caller should fall back to cached preview).
 */
export function selectLatestThreadReplyMessage(
  state: { messages: MessagesState },
  chatId: string,
  threadRootId: string,
): MessageResponse | null {
  const storeKey = `${chatId}_thread_${threadRootId}`;
  const chat = state.messages.chats[storeKey];
  if (!chat || chat.windows.length === 0) return null;

  let latest: MessageResponse | null = null;
  for (const win of chat.windows) {
    for (let i = win.messages.length - 1; i >= 0; i--) {
      const msg = win.messages[i];
      if (!msg.isDeleted) {
        if (!latest || compareMessageOrder(msg, latest) > 0) {
          latest = msg;
        }
        break; // sorted within window — first non-deleted from end is the latest in this window
      }
    }
  }
  return latest;
}

export default messagesSlice.reducer;
