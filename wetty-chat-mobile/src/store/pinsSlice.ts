import type { PayloadAction } from '@reduxjs/toolkit';
import { createSlice } from '@reduxjs/toolkit';
import type { RootState } from './index';
import type { PinResponse } from '@/api/pins';

interface ChatPins {
  pins: PinResponse[];
  loaded: boolean;
}

interface PinsState {
  byChatId: Record<string, ChatPins>;
  /** Per-user banner dismissal: chatId -> dismissed pin ID */
  dismissedPinId: Record<string, string>;
}

const initialState: PinsState = {
  byChatId: {},
  dismissedPinId: {},
};

const pinsSlice = createSlice({
  name: 'pins',
  initialState,
  reducers: {
    setPins(state, action: PayloadAction<{ chatId: string; pins: PinResponse[] }>) {
      const sortedPins = [...action.payload.pins].sort(
        (a, b) => new Date(b.message.createdAt).getTime() - new Date(a.message.createdAt).getTime(),
      );
      state.byChatId[action.payload.chatId] = {
        pins: sortedPins,
        loaded: true,
      };
    },
    addPin(state, action: PayloadAction<PinResponse>) {
      const chatId = action.payload.chatId;
      const entry = state.byChatId[chatId];
      if (entry) {
        // Avoid duplicates
        if (!entry.pins.some((p) => p.id === action.payload.id)) {
          entry.pins.push(action.payload);
          entry.pins.sort((a, b) => new Date(b.message.createdAt).getTime() - new Date(a.message.createdAt).getTime());
        }
      } else {
        state.byChatId[chatId] = { pins: [action.payload], loaded: true };
      }
      // Clear dismissed state so new pin shows in banner
      delete state.dismissedPinId[chatId];
    },
    removePin(state, action: PayloadAction<{ chatId: string; pinId: string }>) {
      const entry = state.byChatId[action.payload.chatId];
      if (entry) {
        entry.pins = entry.pins.filter((p) => p.id !== action.payload.pinId);
      }
    },
    dismissBanner(state, action: PayloadAction<{ chatId: string; pinId: string }>) {
      state.dismissedPinId[action.payload.chatId] = action.payload.pinId;
    },
  },
});

export const { setPins, addPin, removePin, dismissBanner } = pinsSlice.actions;

export const selectPinsForChat = (state: RootState, chatId: string): PinResponse[] =>
  state.pins.byChatId[chatId]?.pins ?? [];

export const selectPinsLoaded = (state: RootState, chatId: string): boolean =>
  state.pins.byChatId[chatId]?.loaded ?? false;

export const selectLatestPin = (state: RootState, chatId: string): PinResponse | null =>
  state.pins.byChatId[chatId]?.pins[0] ?? null;

export const selectIsBannerDismissed = (state: RootState, chatId: string): boolean => {
  const latestPin = state.pins.byChatId[chatId]?.pins[0];
  if (!latestPin) return true;
  return state.pins.dismissedPinId[chatId] === latestPin.id;
};

export default pinsSlice.reducer;
