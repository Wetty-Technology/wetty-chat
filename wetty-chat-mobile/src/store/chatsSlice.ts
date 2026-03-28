import type { PayloadAction } from '@reduxjs/toolkit';
import { createSelector, createSlice } from '@reduxjs/toolkit';
import type { RootState } from './index';
import type { MessageResponse } from '@/api/messages';
import type { ChatListEntry } from '@/api/chats';
import type { GroupRole } from '@/api/group';
import { compareMessageOrder, isSameMessage } from './messageProjection';

export interface ChatMeta {
  name: string | null;
  description?: string | null;
  avatar?: string | null;
  avatar_image_id?: string | null;
  visibility?: string;
  created_at?: string;
  my_role?: GroupRole | null;
}

interface ChatListMeta {
  last_message_at?: string | null;
  unread_count?: number;
  last_read_message_id?: string | null;
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

function resolveMutedUntil(snapshot?: ChatListMeta, live?: ChatListMeta): string | null {
  if (live && Object.prototype.hasOwnProperty.call(live, 'muted_until')) {
    return live.muted_until ?? null;
  }

  return snapshot?.muted_until ?? null;
}

function getEffectiveListMeta(entry?: ChatStateEntry): ChatListMeta {
  const snapshot = entry?.listSnapshot;
  const live = entry?.liveProjection;
  const latest = chooseEffectiveLatest(snapshot, live);

  return {
    in_list: live?.in_list ?? snapshot?.in_list ?? false,
    unread_count: live?.unread_count ?? snapshot?.unread_count ?? 0,
    last_read_message_id: live?.last_read_message_id ?? snapshot?.last_read_message_id ?? null,
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
    setChatsList(state, action: PayloadAction<ChatListEntry[]>) {
      for (const chat of action.payload) {
        const entry = getChatEntry(state, chat.id);
        entry.details = {
          ...entry.details,
          name: chat.name ?? entry.details.name,
          avatar: chat.avatar ?? entry.details.avatar ?? null,
        };
        entry.listSnapshot = {
          last_message: chat.last_message,
          last_message_at: chat.last_message_at,
          unread_count: chat.unread_count,
          last_read_message_id: chat.last_read_message_id,
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
      action: PayloadAction<{ chatId: string; message: MessageResponse; incrementUnread: boolean }>,
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
      action: PayloadAction<{ chatId: string; clientGeneratedId: string; message: MessageResponse }>,
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
      action: PayloadAction<{
        chatId: string;
        messageId: string;
        message: MessageResponse;
        fallbackMessage: MessageResponse | null;
      }>,
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
        entry.liveProjection.last_message_at = fallbackMessage?.created_at ?? null;
        return;
      }

      entry.liveProjection.last_message = {
        ...currentLatest,
        ...message,
      };
      entry.liveProjection.last_message_at = message.created_at;
    },
    markChatAsRead(state, action: PayloadAction<{ chatId: string; lastReadMessageId?: string | null }>) {
      const entry = getChatEntry(state, action.payload.chatId);
      entry.liveProjection = {
        ...entry.liveProjection,
        unread_count: 0,
        last_read_message_id:
          action.payload.lastReadMessageId !== undefined
            ? action.payload.lastReadMessageId
            : (entry.liveProjection?.last_read_message_id ?? entry.listSnapshot?.last_read_message_id ?? null),
        in_list: true,
      };
    },
    setChatLastReadMessageId(state, action: PayloadAction<{ chatId: string; lastReadMessageId: string | null }>) {
      const entry = getChatEntry(state, action.payload.chatId);
      entry.liveProjection = {
        ...entry.liveProjection,
        last_read_message_id: action.payload.lastReadMessageId,
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
  setChatLastReadMessageId,
} = chatsSlice.actions;

export const selectChatMeta = (state: RootState, chatId: string): ChatMeta | undefined =>
  state.chats.byId[chatId]?.details;
export const selectChatName = (state: RootState, chatId: string): string | null =>
  state.chats.byId[chatId]?.details.name ?? null;

export function selectIsChatMuted(state: RootState, chatId: string): boolean {
  const entry = state.chats.byId[chatId];
  const mutedUntil = resolveMutedUntil(entry?.listSnapshot, entry?.liveProjection);
  if (!mutedUntil) return false;
  return new Date(mutedUntil) > new Date();
}

export function selectChatMutedUntil(state: RootState, chatId: string): string | null {
  const entry = state.chats.byId[chatId];
  return resolveMutedUntil(entry?.listSnapshot, entry?.liveProjection);
}

export function selectChatLastReadMessageId(state: RootState, chatId: string): string | null {
  const entry = state.chats.byId[chatId];
  return getEffectiveListMeta(entry).last_read_message_id ?? null;
}

const selectChatsById = (state: RootState) => state.chats.byId;

export const selectAllChats = createSelector([selectChatsById], (byId): ChatListEntry[] => {
  return Object.entries(byId)
    .filter(([, entry]) => getEffectiveListMeta(entry).in_list)
    .map(([id, entry]) => {
      const listMeta = getEffectiveListMeta(entry);
      return {
        id,
        name: entry.details.name ?? null,
        avatar: entry.details.avatar ?? null,
        last_message_at: listMeta.last_message_at ?? null,
        unread_count: listMeta.unread_count ?? 0,
        last_read_message_id: listMeta.last_read_message_id ?? null,
        last_message: listMeta.last_message ?? null,
        muted_until: resolveMutedUntil(entry?.listSnapshot, entry?.liveProjection),
      };
    })
    .sort((a, b) => {
      return compareMessageOrder(b.last_message, a.last_message);
    });
});

export default chatsSlice.reducer;
