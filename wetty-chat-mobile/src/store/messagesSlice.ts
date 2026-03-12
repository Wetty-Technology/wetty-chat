import { createSlice, createSelector } from '@reduxjs/toolkit';
import type { MessageResponse } from '@/api/messages';

const MAX_WINDOWS = 5;

export interface MessageWindow {
  messages: MessageResponse[];
  nextCursor: string | null;  // cursor to load older messages (top)
  prevCursor: string | null;  // cursor to load newer messages (bottom)
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
  const ids = new Set(existing.map(m => m.id));
  return incoming.filter(m => !ids.has(m.id));
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

const messagesSlice = createSlice({
  name: 'messages',
  initialState,
  reducers: {
    resetChat(state, action: { payload: { chatId: string; messages: MessageResponse[]; nextCursor: string | null; prevCursor: string | null } }) {
      const { chatId, messages, nextCursor, prevCursor } = action.payload;
      const prevGen = state.chats[chatId]?.generation ?? 0;
      state.chats[chatId] = {
        windows: [{ messages, nextCursor, prevCursor }],
        activeWindowIndex: 0,
        generation: prevGen + 1,
      };
    },

    pushWindow(state, action: { payload: { chatId: string; messages: MessageResponse[]; nextCursor: string | null; prevCursor: string | null } }) {
      const { chatId, messages, nextCursor, prevCursor } = action.payload;
      const chat = getChat(state, chatId);
      const newWin: MessageWindow = { messages, nextCursor, prevCursor };

      // Insert in chronological order so the last window is always the most recent
      const newTs = messages.length > 0 ? messages[0].created_at : '';
      let insertIdx = chat.windows.length;
      for (let i = 0; i < chat.windows.length; i++) {
        const winTs = chat.windows[i].messages[0]?.created_at ?? '';
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

    prependMessages(state, action: { payload: { chatId: string; messages: MessageResponse[]; nextCursor?: string | null } }) {
      const { chatId, messages } = action.payload;
      const chat = getChat(state, chatId);
      const win = getActiveWindow(chat);
      if (!win) return;
      const unique = dedup(win.messages, messages);
      win.messages = [...unique, ...win.messages];
      if (action.payload.nextCursor !== undefined) {
        win.nextCursor = action.payload.nextCursor;
      }
    },

    appendMessages(state, action: { payload: { chatId: string; messages: MessageResponse[]; prevCursor?: string | null } }) {
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
        win.prevCursor = nextWin.prevCursor;
        chat.windows.splice(chat.activeWindowIndex + 1, 1);
      }
    },

    addMessage(state, action: { payload: { chatId: string; message: MessageResponse } }) {
      const { chatId, message } = action.payload;
      const chat = getChat(state, chatId);
      if (chat.windows.length === 0) {
        chat.windows.push({ messages: [], nextCursor: null, prevCursor: null });
        chat.activeWindowIndex = 0;
      }
      const lastWin = chat.windows[chat.windows.length - 1];
      if (lastWin.messages.some(m => m.id === message.id)) return;
      lastWin.messages.push(message);
    },

    confirmPendingMessage(
      state,
      action: { payload: { chatId: string; clientGeneratedId: string; message: MessageResponse } }
    ) {
      const { chatId, clientGeneratedId, message } = action.payload;
      const chat = state.chats[chatId];
      if (!chat) return;
      for (const win of chat.windows) {
        const idx = win.messages.findIndex(m => m.client_generated_id === clientGeneratedId);
        if (idx !== -1) {
          win.messages[idx] = message;
          return;
        }
      }
    },

    updateMessageInStore(
      state,
      action: { payload: { chatId: string; messageId: string; message: MessageResponse } }
    ) {
      const { chatId, messageId, message } = action.payload;
      const chat = state.chats[chatId];
      if (!chat) return;
      for (const win of chat.windows) {
        if (message.is_deleted) {
          // If the message is deleted, remove it from the list of messages
          win.messages = win.messages.filter(m => m.id !== messageId);
        }

        for (let i = 0; i < win.messages.length; i++) {
          const m = win.messages[i];
          if (!message.is_deleted && m.id === messageId) {
            // Use existing reply_to_message if the incoming update doesn't have it but is for the same reply
            const preservedReplyTo = message.reply_to_message ?? (message.reply_to_message === undefined && m.reply_to_message !== undefined ? m.reply_to_message : undefined);
            win.messages[i] = { ...message, reply_to_message: preservedReplyTo };
          } else if (m.reply_to_message?.id === messageId) {
            m.reply_to_message.message = message.message;
            m.reply_to_message.is_deleted = message.is_deleted;
          }
        }
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
  },
});

export const {
  resetChat,
  pushWindow,
  setMessagesForChat,
  setNextCursorForChat,
  setPrevCursorForChat,
  addMessage,
  appendMessages,
  prependMessages,
  confirmPendingMessage,
  updateMessageInStore,
} = messagesSlice.actions;

/** Selectors */
const EMPTY_ARRAY: MessageResponse[] = [];

const selectMessagesChats = (state: { messages: MessagesState }) => state.messages.chats;

export const selectMessagesForChat = createSelector(
  [
    selectMessagesChats,
    (_state: { messages: MessagesState }, chatId: string) => chatId
  ],
  (chats, chatId): MessageResponse[] => {
    const chat = chats[chatId];
    if (!chat || chat.windows.length === 0) return EMPTY_ARRAY;
    return chat.windows[chat.activeWindowIndex]?.messages ?? EMPTY_ARRAY;
  }
);

export function selectNextCursorForChat(
  state: { messages: MessagesState },
  chatId: string
): string | null {
  const chat = state.messages.chats[chatId];
  if (!chat || chat.windows.length === 0) return null;
  return chat.windows[chat.activeWindowIndex]?.nextCursor ?? null;
}

export function selectChatGeneration(
  state: { messages: MessagesState },
  chatId: string
): number {
  return state.messages.chats[chatId]?.generation ?? 0;
}

export function selectPrevCursorForChat(
  state: { messages: MessagesState },
  chatId: string
): string | null {
  const chat = state.messages.chats[chatId];
  if (!chat || chat.windows.length === 0) return null;
  return chat.windows[chat.activeWindowIndex]?.prevCursor ?? null;
}

export default messagesSlice.reducer;
