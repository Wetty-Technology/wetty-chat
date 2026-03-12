import { createSlice, createSelector } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from './index';
import type { MessageResponse } from '@/api/messages';
import type { ChatListItem } from '@/api/chats';

export interface ChatMeta {
  name: string | null;
  description?: string | null;
  avatar?: string | null;
  visibility?: string;
  created_at?: string;
  last_message_at?: string | null;
  unread_count?: number;
  last_message?: MessageResponse | null;
  in_list?: boolean;
}

export interface ChatsState {
  byId: Record<string, ChatMeta>;
}

const initialState: ChatsState = {
  byId: {},
};

const chatsSlice = createSlice({
  name: 'chats',
  initialState,
  reducers: {
    setChatMeta(state, action: PayloadAction<{ chatId: string; meta: Partial<ChatMeta> }>) {
      const existing = state.byId[action.payload.chatId];
      state.byId[action.payload.chatId] = existing
        ? { ...existing, ...action.payload.meta }
        : { name: null, ...action.payload.meta };
    },
    setChatsMeta(state, action: PayloadAction<Record<string, Partial<ChatMeta>>>) {
      for (const [chatId, meta] of Object.entries(action.payload)) {
        const existing = state.byId[chatId];
        state.byId[chatId] = existing ? { ...existing, ...meta } : { name: null, ...meta };
      }
    },
    setChatsList(state, action: PayloadAction<ChatListItem[]>) {
      for (const chat of action.payload) {
        const existing = state.byId[chat.id] || { name: null };
        state.byId[chat.id] = { ...existing, ...chat, in_list: true };
      }
    },
    updateChatFromMessage(state, action: PayloadAction<{ chatId: string; message: MessageResponse; currentUserId: number }>) {
      const { chatId, message, currentUserId } = action.payload;
      const chat = state.byId[chatId];
      if (chat) {
        chat.last_message = message;
        // Need to ensure last_message_at doesn't go backwards if an old message arrives out-of-order,
        // but typically ws messages are real-time, so we just overwrite it.
        chat.last_message_at = message.created_at;
        chat.in_list = true;

        if (!message.is_deleted && message.sender.uid !== currentUserId && !message.id.startsWith('cg_')) {
          chat.unread_count = (chat.unread_count || 0) + 1;
        }
      } else {
        // If chat didn't exist in store at all, create it
        state.byId[chatId] = {
          name: null,
          last_message: message,
          last_message_at: message.created_at,
          unread_count: (!message.is_deleted && message.sender.uid !== currentUserId && !message.id.startsWith('cg_')) ? 1 : 0,
          in_list: true,
        };
      }
    },
    markChatAsRead(state, action: PayloadAction<{ chatId: string }>) {
      const existing = state.byId[action.payload.chatId];
      if (existing) {
        existing.unread_count = 0;
      }
    },
  },
});

export const { setChatMeta, setChatsMeta, setChatsList, updateChatFromMessage, markChatAsRead } = chatsSlice.actions;

export const selectChatMeta = (state: RootState, chatId: string): ChatMeta | undefined =>
  state.chats.byId[chatId];
export const selectChatName = (state: RootState, chatId: string): string | null =>
  state.chats.byId[chatId]?.name ?? null;

const selectChatsById = (state: RootState) => state.chats.byId;

export const selectAllChats = createSelector(
  [selectChatsById],
  (byId): ChatListItem[] => {
    return Object.entries(byId)
      .filter(([_, meta]) => meta.in_list)
      .map(([id, meta]) => ({
        id,
        name: meta.name ?? null,
        last_message_at: meta.last_message_at ?? null,
        unread_count: meta.unread_count ?? 0,
        last_message: meta.last_message ?? null,
      }))
      .sort((a, b) => {
        const dateA = a.last_message_at ? new Date(a.last_message_at).getTime() : 0;
        const dateB = b.last_message_at ? new Date(b.last_message_at).getTime() : 0;
        return dateB - dateA; // Descending
      });
  }
);

export default chatsSlice.reducer;
