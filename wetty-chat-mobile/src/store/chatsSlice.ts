import { createSlice, createSelector } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from './index';
import type { MessageResponse } from '@/api/messages';
import type { ChatListItem } from '@/api/chats';
import { compareMessageOrder, isSameMessage } from './messageProjection';

export interface ChatMeta {
  name: string | null;
  description?: string | null;
  avatar?: string | null;
  visibility?: string;
  created_at?: string;
}

interface ChatListMeta {
  last_message_at?: string | null;
  unread_count?: number;
  last_message?: MessageResponse | null;
  in_list?: boolean;
  muted_until?: string | null;
}

interface ChatStateEntry {
  details: ChatMeta;
  listSnapshot?: ChatListMeta;
  liveProjection?: ChatListMeta;
}

export interface ChatsState {
  byId: Record<string, ChatStateEntry>;
}

const initialState: ChatsState = {
  byId: {},
};

function getChatEntry(state: ChatsState, chatId: string): ChatStateEntry {
  const existing = state.byId[chatId];
  if (existing) return existing;

  const created: ChatStateEntry = {
    details: { name: null },
  };
  state.byId[chatId] = created;
  return created;
}

function chooseEffectiveLatest(snapshot?: ChatListMeta, live?: ChatListMeta): MessageResponse | null {
  const liveOverridesLatest = !!live && Object.prototype.hasOwnProperty.call(live, 'last_message');
  const snapshotMessage = snapshot?.last_message ?? null;
  const liveMessage = live?.last_message ?? null;

  if (liveOverridesLatest && liveMessage === null) return null;
  if (!liveMessage) return snapshotMessage;
  if (!snapshotMessage) return liveMessage;
  if (isSameMessage(liveMessage, snapshotMessage)) return liveMessage;

  return compareMessageOrder(liveMessage, snapshotMessage) >= 0 ? liveMessage : snapshotMessage;
}

function getEffectiveListMeta(entry?: ChatStateEntry): ChatListMeta {
  const snapshot = entry?.listSnapshot;
  const live = entry?.liveProjection;
  const latest = chooseEffectiveLatest(snapshot, live);

  return {
    in_list: live?.in_list ?? snapshot?.in_list ?? false,
    unread_count: live?.unread_count ?? snapshot?.unread_count ?? 0,
    last_message: latest,
    last_message_at: latest?.created_at ?? snapshot?.last_message_at ?? null,
  };
}

const chatsSlice = createSlice({
  name: 'chats',
  initialState,
  reducers: {
    setChatMeta(state, action: PayloadAction<{ chatId: string; meta: Partial<ChatMeta> }>) {
      const entry = getChatEntry(state, action.payload.chatId);
      entry.details = { ...entry.details, ...action.payload.meta };
    },
    setChatsMeta(state, action: PayloadAction<Record<string, Partial<ChatMeta>>>) {
      for (const [chatId, meta] of Object.entries(action.payload)) {
        const entry = getChatEntry(state, chatId);
        entry.details = { ...entry.details, ...meta };
      }
    },
    setChatsList(state, action: PayloadAction<ChatListItem[]>) {
      for (const chat of action.payload) {
        const entry = getChatEntry(state, chat.id);
        entry.details = {
          ...entry.details,
          name: chat.name ?? entry.details.name,
        };
        entry.listSnapshot = {
          last_message: chat.last_message,
          last_message_at: chat.last_message_at,
          unread_count: chat.unread_count,
          in_list: true,
          muted_until: chat.muted_until,
        };
      }
    },
    setChatMutedUntil(state, action: PayloadAction<{ chatId: string; mutedUntil: string | null }>) {
      const entry = getChatEntry(state, action.payload.chatId);
      entry.liveProjection = {
        ...entry.liveProjection,
        muted_until: action.payload.mutedUntil,
      };
    },
    projectChatMessageAdded(
      state,
      action: PayloadAction<{ chatId: string; message: MessageResponse; incrementUnread: boolean }>
    ) {
      const { chatId, message, incrementUnread } = action.payload;
      const entry = getChatEntry(state, chatId);
      const current = getEffectiveListMeta(entry);
      entry.liveProjection = {
        ...entry.liveProjection,
        in_list: true,
        unread_count: (entry.liveProjection?.unread_count ?? current.unread_count ?? 0) + (incrementUnread ? 1 : 0),
      };

      if (message.reply_root_id || message.is_deleted) {
        return;
      }

      const currentLatest = current.last_message;
      if (!currentLatest || compareMessageOrder(message, currentLatest) >= 0) {
        entry.liveProjection.last_message = message;
        entry.liveProjection.last_message_at = message.created_at;
      }
    },
    projectChatMessageConfirmed(
      state,
      action: PayloadAction<{ chatId: string; clientGeneratedId: string; message: MessageResponse }>
    ) {
      const { chatId, clientGeneratedId, message } = action.payload;
      const entry = getChatEntry(state, chatId);
      const current = getEffectiveListMeta(entry);
      entry.liveProjection = {
        ...entry.liveProjection,
        in_list: true,
      };

      if (message.reply_root_id || message.is_deleted) {
        return;
      }

      const currentLatest = current.last_message;
      const isConfirmingCurrent =
        !!currentLatest &&
        (currentLatest.client_generated_id === clientGeneratedId || currentLatest.id === clientGeneratedId);

      if (isConfirmingCurrent || !currentLatest || compareMessageOrder(message, currentLatest) >= 0) {
        entry.liveProjection.last_message = message;
        entry.liveProjection.last_message_at = message.created_at;
      }
    },
    setChatUnreadCount(state, action: PayloadAction<{ chatId: string; unreadCount: number }>) {
      const entry = getChatEntry(state, action.payload.chatId);
      entry.liveProjection = {
        ...entry.liveProjection,
        unread_count: action.payload.unreadCount,
        in_list: true,
      };
    },
    projectChatMessagePatched(
      state,
      action: PayloadAction<{ chatId: string; messageId: string; message: MessageResponse; fallbackMessage: MessageResponse | null }>
    ) {
      const { chatId, messageId, message, fallbackMessage } = action.payload;
      const entry = state.byId[chatId];
      if (!entry) return;

      const current = getEffectiveListMeta(entry);
      const currentLatest = current.last_message;
      const isCurrentLatest =
        !!currentLatest &&
        (currentLatest.id === messageId || currentLatest.client_generated_id === message.client_generated_id);

      if (!isCurrentLatest) return;

      entry.liveProjection = {
        ...entry.liveProjection,
        in_list: true,
      };

      if (message.is_deleted) {
        entry.liveProjection.last_message = fallbackMessage;
        entry.liveProjection.last_message_at =
          fallbackMessage?.created_at ?? null;
        return;
      }

      entry.liveProjection.last_message = {
        ...currentLatest,
        ...message,
      };
      entry.liveProjection.last_message_at = message.created_at;
    },
    markChatAsRead(state, action: PayloadAction<{ chatId: string }>) {
      const entry = getChatEntry(state, action.payload.chatId);
      entry.liveProjection = {
        ...entry.liveProjection,
        unread_count: 0,
        in_list: true,
      };
    },
  },
});

export const {
  setChatMeta,
  setChatsMeta,
  setChatsList,
  setChatMutedUntil,
  projectChatMessageAdded,
  projectChatMessageConfirmed,
  setChatUnreadCount,
  projectChatMessagePatched,
  markChatAsRead,
} = chatsSlice.actions;

export const selectChatMeta = (state: RootState, chatId: string): ChatMeta | undefined =>
  state.chats.byId[chatId]?.details;
export const selectChatName = (state: RootState, chatId: string): string | null =>
  state.chats.byId[chatId]?.details.name ?? null;

export function selectIsChatMuted(state: RootState, chatId: string): boolean {
  const entry = state.chats.byId[chatId];
  const mutedUntil = entry?.liveProjection?.muted_until ?? entry?.listSnapshot?.muted_until;
  if (!mutedUntil) return false;
  return new Date(mutedUntil) > new Date();
}

export function selectChatMutedUntil(state: RootState, chatId: string): string | null {
  const entry = state.chats.byId[chatId];
  return entry?.liveProjection?.muted_until ?? entry?.listSnapshot?.muted_until ?? null;
}

const selectChatsById = (state: RootState) => state.chats.byId;

export const selectAllChats = createSelector(
  [selectChatsById],
  (byId): ChatListItem[] => {
    return Object.entries(byId)
      .filter(([, entry]) => getEffectiveListMeta(entry).in_list)
      .map(([id, entry]) => {
        const listMeta = getEffectiveListMeta(entry);
        return {
          id,
          name: entry.details.name ?? null,
          last_message_at: listMeta.last_message_at ?? null,
          unread_count: listMeta.unread_count ?? 0,
          last_message: listMeta.last_message ?? null,
          muted_until: entry?.liveProjection?.muted_until ?? entry?.listSnapshot?.muted_until ?? null,
        };
      })
      .sort((a, b) => {
        return compareMessageOrder(b.last_message, a.last_message);
      });
  }
);

export default chatsSlice.reducer;
