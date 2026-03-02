import { createSlice } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from './index';

export interface SettingsState {
  locale: string | null;
}

function loadInitialState(): SettingsState {
  try {
    const raw = localStorage.getItem('settings');
    if (raw) {
      const parsed = JSON.parse(raw);
      return { locale: parsed.locale ?? null };
    }
  } catch {
    // ignore corrupt data
  }
  return { locale: null };
}

const settingsSlice = createSlice({
  name: 'settings',
  initialState: loadInitialState(),
  reducers: {
    setLocale(state, action: PayloadAction<string | null>) {
      state.locale = action.payload;
      localStorage.setItem('settings', JSON.stringify({ locale: action.payload }));
    },
  },
});

export const { setLocale } = settingsSlice.actions;
export const selectLocale = (state: RootState) => state.settings.locale;
export default settingsSlice.reducer;
