import { createSlice } from '@reduxjs/toolkit';

export interface ConnectionState {
  wsConnected: boolean;
  activeConnections: number;
}

const initialState: ConnectionState = {
  wsConnected: false,
  activeConnections: 0,
};

const connectionSlice = createSlice({
  name: 'connection',
  initialState,
  reducers: {
    setWsConnected(state, action: { payload: boolean }) {
      state.wsConnected = action.payload;
    },
    setActiveConnections(state, action: { payload: number }) {
      state.activeConnections = action.payload;
    },
  },
});

export const { setWsConnected, setActiveConnections } = connectionSlice.actions;
export default connectionSlice.reducer;
