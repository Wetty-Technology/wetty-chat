import { configureStore } from '@reduxjs/toolkit';
import connectionReducer from './connectionSlice';
import messagesReducer from './messagesSlice';
import settingsReducer from './settingsSlice';
import chatsReducer from './chatsSlice';
import userReducer from './userSlice';

export const store = configureStore({
  reducer: {
    connection: connectionReducer,
    messages: messagesReducer,
    settings: settingsReducer,
    chats: chatsReducer,
    user: userReducer,
  },
});

export default store;
export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
