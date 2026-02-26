import { createSlice } from '@reduxjs/toolkit';

export interface ConnectionState {
  wsConnected: boolean;
}

const initialState: ConnectionState = {
  wsConnected: true,
};

const connectionSlice = createSlice({
  name: 'connection',
  initialState,
  reducers: {
    setWsConnected(state, action: { payload: boolean }) {
      state.wsConnected = action.payload;
    },
  },
});

export const { setWsConnected } = connectionSlice.actions;
export default connectionSlice.reducer;
