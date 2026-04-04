import { configureStore, createListenerMiddleware } from '@reduxjs/toolkit';
import connectionReducer from './connectionSlice';
import messagesReducer from './messagesSlice';
import settingsReducer, { type SettingsState } from './settingsSlice';
import threadsReducer, {
  incrementThreadUnread,
  removeThread,
  updateThreadCachedLastReply,
  patchThreadCachedLastReply,
  patchThreadRootMessage,
} from './threadsSlice';
import chatsReducer, {
  projectChatMessageAdded,
  projectChatMessageConfirmed,
  projectChatMessagePatched,
} from './chatsSlice';
import pinsReducer from './pinsSlice';
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
          !action.payload.message.isDeleted &&
          !isOptimisticMessageId(action.payload.message.id) &&
          action.payload.message.sender.uid !== (state.user.uid ?? 0),
      }),
    );

    if (
      action.payload.scope === 'thread' &&
      action.payload.origin === 'ws' &&
      action.payload.message.replyRootId != null
    ) {
      const { message } = action.payload;
      const threadRootId = message.replyRootId!;
      const isSubscribed = state.threads.items.some((t) => t.threadRootMessage.id === threadRootId);
      if (isSubscribed) {
        if (!message.isDeleted) {
          // Only update the cached preview if the thread window isn't loaded
          // (when loaded, the UI derives the preview from messagesSlice directly)
          const storeKey = `${message.chatId}_thread_${threadRootId}`;
          const hasWindow = (state.messages.chats[storeKey]?.windows?.length ?? 0) > 0;
          if (!hasWindow) {
            api.dispatch(
              updateThreadCachedLastReply({
                threadRootId,
                cachedLastReply: {
                  sender: { uid: message.sender.uid, name: message.sender.name, avatarUrl: message.sender.avatarUrl },
                  message: message.message,
                  messageType: message.messageType,
                  stickerEmoji: message.sticker?.emoji ?? null,
                  firstAttachmentKind: message.attachments?.[0]?.kind ?? null,
                  isDeleted: false,
                  mentions: message.mentions ?? null,
                },
              }),
            );
          }
        }
        if (!message.isDeleted && message.sender.uid !== (state.user.uid ?? 0)) {
          api.dispatch(incrementThreadUnread({ threadRootId }));
        }
      }
    }
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

    // Update thread list preview when the current user's own message is confirmed
    if (action.payload.scope === 'thread' && action.payload.message.replyRootId != null) {
      const { message } = action.payload;
      const threadRootId = message.replyRootId!;
      const state = api.getState() as RootState;
      const isSubscribed = state.threads.items.some((t) => t.threadRootMessage.id === threadRootId);
      if (isSubscribed && !message.isDeleted) {
        const storeKey = `${message.chatId}_thread_${threadRootId}`;
        const hasWindow = (state.messages.chats[storeKey]?.windows?.length ?? 0) > 0;
        if (!hasWindow) {
          api.dispatch(
            updateThreadCachedLastReply({
              threadRootId,
              cachedLastReply: {
                sender: { uid: message.sender.uid, name: message.sender.name, avatarUrl: message.sender.avatarUrl },
                message: message.message,
                messageType: message.messageType,
                stickerEmoji: message.sticker?.emoji ?? null,
                firstAttachmentKind: message.attachments?.[0]?.kind ?? null,
                isDeleted: false,
                mentions: message.mentions ?? null,
              },
            }),
          );
        }
      }
    }
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
        fallbackMessage: action.payload.message.isDeleted
          ? findLatestEligibleRootMessage(
              state.messages.chats[action.payload.chatId]?.windows,
              action.payload.messageId,
            )
          : null,
      }),
    );

    // Handle thread root deletion — remove the thread entirely
    if (action.payload.message.isDeleted && !action.payload.message.replyRootId) {
      const thread = state.threads.items.find((t) => t.threadRootMessage.id === action.payload.messageId);
      if (thread) {
        api.dispatch(removeThread({ threadRootId: action.payload.messageId }));
      }
    }

    // Handle thread root edit (not delete) — update the root message preview
    if (!action.payload.message.isDeleted && !action.payload.message.replyRootId) {
      const thread = state.threads.items.find((t) => t.threadRootMessage.id === action.payload.messageId);
      if (thread) {
        api.dispatch(
          patchThreadRootMessage({
            threadRootId: action.payload.messageId,
            message: {
              message: action.payload.message.message,
              isDeleted: action.payload.message.isDeleted,
            },
          }),
        );
      }
    }

    // Handle thread reply edit/delete — update cache only if window not loaded
    if (action.payload.message.replyRootId) {
      const threadRootId = action.payload.message.replyRootId;
      const storeKey = `${action.payload.chatId}_thread_${threadRootId}`;
      const hasWindow = (state.messages.chats[storeKey]?.windows?.length ?? 0) > 0;
      if (!hasWindow) {
        const thread = state.threads.items.find((t) => t.threadRootMessage.id === threadRootId);
        if (thread?.cachedLastReply) {
          api.dispatch(
            patchThreadCachedLastReply({
              threadRootId,
              patch: {
                message: action.payload.message.message,
                isDeleted: action.payload.message.isDeleted,
              },
            }),
          );
        }
      }
    }
  },
});

export function createStore(initialSettings?: SettingsState) {
  return configureStore({
    reducer: {
      connection: connectionReducer,
      messages: messagesReducer,
      settings: settingsReducer,
      chats: chatsReducer,
      threads: threadsReducer,
      pins: pinsReducer,
      user: userReducer,
    },
    preloadedState: initialSettings ? { settings: initialSettings } : undefined,
    middleware: (getDefaultMiddleware) => getDefaultMiddleware().prepend(listenerMiddleware.middleware),
  });
}

export type AppStore = ReturnType<typeof createStore>;
export type RootState = ReturnType<AppStore['getState']>;
export type AppDispatch = AppStore['dispatch'];

/**
 * Module-level store reference for non-React code (ws.ts, sync.ts, etc.).
 * Set once during bootstrap via `setStoreInstance()`.
 */
let storeInstance: AppStore | null = null;

export function setStoreInstance(s: AppStore) {
  storeInstance = s;
}

/** Prefer useSelector/useDispatch in React components.
 *  Use for imperative code only. */
const store = new Proxy({} as AppStore, {
  get(_target, prop: keyof AppStore) {
    if (!storeInstance) throw new Error('Store not initialized yet');
    return storeInstance[prop];
  },
});

export default store;
