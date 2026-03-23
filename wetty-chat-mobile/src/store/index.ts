import { configureStore, createListenerMiddleware } from '@reduxjs/toolkit';
import connectionReducer from './connectionSlice';
import messagesReducer from './messagesSlice';
import settingsReducer from './settingsSlice';
import chatsReducer, {
  projectChatMessageAdded,
  projectChatMessageConfirmed,
  projectChatMessagePatched,
} from './chatsSlice';
import userReducer from './userSlice';
import { messageAdded, messageConfirmed, messagePatched } from './messageEvents';
import { findLatestEligibleRootMessage, isOptimisticMessageId } from './messageProjection';

const listenerMiddleware = createListenerMiddleware();

listenerMiddleware.startListening({
  actionCreator: messageAdded,
  effect: async (action, api) => {
    const state = api.getState() as RootState;
    api.dispatch(
      projectChatMessageAdded({
        chatId: action.payload.chatId,
        message: action.payload.message,
        incrementUnread:
          action.payload.scope === 'main' &&
          !action.payload.message.is_deleted &&
          !isOptimisticMessageId(action.payload.message.id) &&
          action.payload.message.sender.uid !== (state.user.uid ?? 0),
      }),
    );
  },
});

listenerMiddleware.startListening({
  actionCreator: messageConfirmed,
  effect: async (action, api) => {
    api.dispatch(
      projectChatMessageConfirmed({
        chatId: action.payload.chatId,
        clientGeneratedId: action.payload.clientGeneratedId,
        message: action.payload.message,
      }),
    );
  },
});

listenerMiddleware.startListening({
  actionCreator: messagePatched,
  effect: async (action, api) => {
    const state = api.getState() as RootState;
    api.dispatch(
      projectChatMessagePatched({
        chatId: action.payload.chatId,
        messageId: action.payload.messageId,
        message: action.payload.message,
        fallbackMessage: action.payload.message.is_deleted
          ? findLatestEligibleRootMessage(
              state.messages.chats[action.payload.chatId]?.windows,
              action.payload.messageId,
            )
          : null,
      }),
    );
  },
});

export const store = configureStore({
  reducer: {
    connection: connectionReducer,
    messages: messagesReducer,
    settings: settingsReducer,
    chats: chatsReducer,
    user: userReducer,
  },
  middleware: (getDefaultMiddleware) => getDefaultMiddleware().prepend(listenerMiddleware.middleware),
});

export default store;
export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
