import type { PayloadAction } from '@reduxjs/toolkit';
import { createSlice } from '@reduxjs/toolkit';
import type { RootState } from './index';
import type { ThreadListItem } from '@/api/threads';

export interface ThreadUpdatePayload {
  threadRootId: string;
  chatId: string;
  lastReplyAt: string;
  replyCount: number;
}

interface ThreadsState {
  items: ThreadListItem[];
  nextCursor: string | null;
  totalUnreadCount: number;
  isLoaded: boolean;
}

const initialState: ThreadsState = {
  items: [],
  nextCursor: null,
  totalUnreadCount: 0,
  isLoaded: false,
};

const threadsSlice = createSlice({
  name: 'threads',
  initialState,
  reducers: {
    setThreadsList(state, action: PayloadAction<{ threads: ThreadListItem[]; nextCursor: string | null }>) {
      state.items = action.payload.threads;
      state.nextCursor = action.payload.nextCursor;
      state.isLoaded = true;
    },
    appendThreads(state, action: PayloadAction<{ threads: ThreadListItem[]; nextCursor: string | null }>) {
      const existingIds = new Set(state.items.map((t) => t.threadRootMessage.id));
      const newThreads = action.payload.threads.filter((t) => !existingIds.has(t.threadRootMessage.id));
      state.items.push(...newThreads);
      state.nextCursor = action.payload.nextCursor;
    },
    setTotalUnreadCount(state, action: PayloadAction<number>) {
      state.totalUnreadCount = action.payload;
    },
    updateThreadFromWs(state, action: PayloadAction<ThreadUpdatePayload>) {
      const { threadRootId, lastReplyAt, replyCount } = action.payload;
      const idx = state.items.findIndex((t) => t.threadRootMessage.id === threadRootId);
      if (idx >= 0) {
        const thread = state.items[idx];
        thread.replyCount = replyCount;
        thread.lastReplyAt = lastReplyAt;
        thread.unreadCount = (thread.unreadCount ?? 0) + 1;
        // Move to top of list
        state.items.splice(idx, 1);
        state.items.unshift(thread);
      } else if (state.isLoaded) {
        // Thread not in list yet — will be fetched on next load
        // But we can still increment the badge
      }
      state.totalUnreadCount = state.items.filter((t) => t.unreadCount > 0).length;
    },
    markThreadRead(state, action: PayloadAction<{ threadRootId: string }>) {
      const thread = state.items.find((t) => t.threadRootMessage.id === action.payload.threadRootId);
      if (thread) {
        thread.unreadCount = 0;
      }
      state.totalUnreadCount = state.items.filter((t) => t.unreadCount > 0).length;
    },
    removeThread(state, action: PayloadAction<{ threadRootId: string }>) {
      state.items = state.items.filter((t) => t.threadRootMessage.id !== action.payload.threadRootId);
      state.totalUnreadCount = state.items.filter((t) => t.unreadCount > 0).length;
    },
    clearThreads(state) {
      state.items = [];
      state.nextCursor = null;
      state.isLoaded = false;
    },
  },
});

export const {
  setThreadsList,
  appendThreads,
  setTotalUnreadCount,
  updateThreadFromWs,
  markThreadRead,
  removeThread,
  clearThreads,
} = threadsSlice.actions;

export const selectThreads = (state: RootState) => state.threads.items;
export const selectThreadsLoaded = (state: RootState) => state.threads.isLoaded;
export const selectThreadsNextCursor = (state: RootState) => state.threads.nextCursor;
export const selectTotalUnreadThreadCount = (state: RootState) => state.threads.totalUnreadCount;

export default threadsSlice.reducer;
