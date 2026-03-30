import type { PayloadAction } from '@reduxjs/toolkit';
import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import type { RootState } from './index';
import { usersApi } from '@/api/users';

export interface UserState {
  uid: number | null;
  username: string | null;
  avatarUrl: string | null;
  loading: boolean;
  error: string | null;
}

const initialState: UserState = {
  uid: null,
  username: null,
  avatarUrl: null,
  loading: true,
  error: null,
};

export const fetchCurrentUser = createAsyncThunk('user/fetchCurrentUser', async (_, { rejectWithValue }) => {
  try {
    const user = await usersApi.getCurrentUser();
    return user;
  } catch (err: any) {
    return rejectWithValue(err.response?.data || err.message);
  }
});

const userSlice = createSlice({
  name: 'user',
  initialState,
  reducers: {
    setUser(state, action: PayloadAction<{ uid: number; username: string; avatarUrl: string | null }>) {
      state.uid = action.payload.uid;
      state.username = action.payload.username;
      state.avatarUrl = action.payload.avatarUrl;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchCurrentUser.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchCurrentUser.fulfilled, (state, action) => {
        state.loading = false;
        state.uid = action.payload.uid;
        state.username = action.payload.username;
        state.avatarUrl = action.payload.avatarUrl ?? null;
      })
      .addCase(fetchCurrentUser.rejected, (state, action) => {
        state.loading = false;
        state.error = (action.payload as string) || 'Failed to fetch user';
      });
  },
});

export const { setUser } = userSlice.actions;

export const selectCurrentUser = (state: RootState) => state.user;

export default userSlice.reducer;
