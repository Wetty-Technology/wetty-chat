import { createSlice } from '@reduxjs/toolkit';
import type { MessageResponse } from '@/api/messages';

export interface MessagesState {
  messagesByChat: Record<string, MessageResponse[]>;
  nextCursorByChat: Record<string, string | null>;
}

const initialState: MessagesState = {
  messagesByChat: {},
  nextCursorByChat: {},
};

const messagesSlice = createSlice({
  name: 'messages',
  initialState,
  reducers: {
    setMessagesForChat(state, action: { payload: { chatId: string; messages: MessageResponse[] } }) {
      const { chatId, messages } = action.payload;
      state.messagesByChat[chatId] = messages;
    },
    setNextCursorForChat(state, action: { payload: { chatId: string; cursor: string | null } }) {
      const { chatId, cursor } = action.payload;
      state.nextCursorByChat[chatId] = cursor;
    },
    addMessage(state, action: { payload: { chatId: string; message: MessageResponse } }) {
      const { chatId, message } = action.payload;
      const list = state.messagesByChat[chatId] ?? [];
      state.messagesByChat[chatId] = [...list, message];
    },
    prependMessages(state, action: { payload: { chatId: string; messages: MessageResponse[] } }) {
      const { chatId, messages } = action.payload;
      const list = state.messagesByChat[chatId] ?? [];
      state.messagesByChat[chatId] = [...messages, ...list];
    },
    confirmPendingMessage(
      state,
      action: {
        payload: { chatId: string; clientGeneratedId: string; message: MessageResponse };
      }
    ) {
      const { chatId, clientGeneratedId, message } = action.payload;
      const list = state.messagesByChat[chatId] ?? [];
      state.messagesByChat[chatId] = list.map((m) =>
        m.client_generated_id === clientGeneratedId ? message : m
      );
    },
  },
});

export const {
  setMessagesForChat,
  setNextCursorForChat,
  addMessage,
  prependMessages,
  confirmPendingMessage,
} = messagesSlice.actions;

/** Selectors: pass state.messages or full RootState. */
export function selectMessagesForChat(
  state: { messages: MessagesState },
  chatId: string
): MessageResponse[] {
  return state.messages.messagesByChat[chatId] ?? [];
}

export function selectNextCursorForChat(
  state: { messages: MessagesState },
  chatId: string
): string | null {
  return state.messages.nextCursorByChat[chatId] ?? null;
}

export default messagesSlice.reducer;
