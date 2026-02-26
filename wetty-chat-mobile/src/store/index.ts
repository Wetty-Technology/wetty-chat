import { configureStore } from '@reduxjs/toolkit';
import connectionReducer from './connectionSlice';
import messagesReducer from './messagesSlice';

export const store = configureStore({
  reducer: {
    connection: connectionReducer,
    messages: messagesReducer,
  },
});

export default store;
export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
